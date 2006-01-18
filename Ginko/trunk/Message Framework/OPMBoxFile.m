//
//  OPMBoxFile.m
//  OPMessageServices
//
//  Created by Dirk Theisen on Wed Jul 28 2004.
//  Copyright (c) 2004 Objectpark Development Group. All rights reserved.
//

#import "OPMBoxFile.h"
#include <unistd.h>

@interface OPMessageDataEnumerator : NSEnumerator {
    OPMBoxFile* mbox;
    unsigned offset;
    unsigned length;
}

+ (id) enumeratorWithMBox: (OPMBoxFile*) theMbox;

- (id) initWithMBox: (OPMBoxFile*) theMbox;
- (unsigned) offsetOfNextObject;

@end

NSString *OPMBoxException = @"OPMBoxException";

@implementation OPMBoxFile

- (id)initWithPath: (NSString*) aPath andFileDescriptor:(int)aFileDescriptor
{
    self = [super init];
    
    [self setPath:aPath];
    _mboxFile = fdopen(aFileDescriptor, "ab+");
    NSAssert(_mboxFile != NULL, @"Cannot open mbox file.");    
    
    return self;
}

+ (id)createMboxFileWithPathTemplate: (NSString*) aTemplate
/*" Creates an unique mbox file with the template given in aTemplate. The template has to have the form '/foo/barXXXX'. The suffix '.mboxfile is appended. "*/
{
    id result = nil;
    char *template;
    const char *filesystemRep = [aTemplate fileSystemRepresentation];
    template = malloc(sizeof(char) * (strlen(filesystemRep) + 9 + 1));
    strcpy(template, filesystemRep);
    strcat(template, ".mboxfile");
    
    @try
    {
        int fd = mkstemps(template, 9);
        NSAssert(fd != -1, @"invalid filehandle");
        result = [[[self alloc] initWithPath:[NSString stringWithUTF8String:template] andFileDescriptor:fd] autorelease];
    }
    @catch (NSException* localException)
    {
        @throw;
    }
    @finally
    {
        free(template);
    }
    
    return result;
}

+ (id)mboxWithPath: (NSString*) aPath
/*" Returns an autoreleased instance. The mbox file at path will be used. Standard index providers are used. If no mbox file exists at aPath an exception is raised. "*/
{
    return [[[self alloc] initWithPath:aPath] autorelease];
}

+ (id)mboxWithPath: (NSString*) aPath createIfNotPresent:(BOOL)shouldCreateIfNotPresent
{
    return [[[self alloc] initWithPath:aPath createIfNotPresent:shouldCreateIfNotPresent] autorelease];
}

- (id) initWithPath: (NSString*) aPath
/*" Initialized the instance for use with the mbox file aPath. Standard index providers are used. If no mbox file exists at aPath an exception is raised. "*/
{
    return [self initWithPath: aPath createIfNotPresent: NO];
}

- (id) initWithPath: (NSString*) aPath createIfNotPresent: (BOOL) shouldCreateIfNotPresent 
{
    NSParameterAssert([aPath length]);
    
    if (self = [super init]) {
        NSFileManager* fileManager = [NSFileManager defaultManager];
        
        if (! [fileManager isReadableFileAtPath: aPath]) {
            if (shouldCreateIfNotPresent) {
                if (! [fileManager createFileAtPath: aPath contents: nil attributes: nil]) {
                    [self release];
                    [NSException raise: OPMBoxException format: @"Cannot create mbox file at path '%@'.", aPath];
                }
            } else {
                [self release];
                [NSException raise: OPMBoxException format: @"No mbox file present at path '%@'.", aPath];
            }
        }
        
        _isReadOnly = ![fileManager isWritableFileAtPath: aPath];
        
        // initialization of ivars
        [self setPath: aPath];
    }
    return self;
}

- (NSEnumerator*) messageDataEnumerator;
/*" This enumerator might not be thread-safe "*/
{
    return [OPMessageDataEnumerator enumeratorWithMBox: self];
}

- (NSData*) mboxSubdataFromOffset:(unsigned)offset endOffset: (unsigned*) endOffset
    /*" Returns the mbox data for the message starting at offset in the mbox file.
    Returns nil, if no valid mbox data could be found. This method is not thread-safe. "*/
{
    NSMutableData *result = nil;
    FILE *file;
    unsigned length, pos;
    static char buffer[8192];
    static const char *from =  "From ";
    
    @synchronized(self)
    {
        file = [self mboxFile];
        
        length = [self mboxFileSize];
        
        if (fseek(file, offset, SEEK_SET) != 0)
        {
            [NSException raise: NSRangeException format: @"The range's location is behind end of the file."];
        }
        
        pos = offset;
        *endOffset = 0;
        
        // read 5 characters
        if (fread(buffer, 1, 5, file) < 5)
        {
            return nil;
        }
        
        // check if From_ is in the beginning
        if (memcmp(buffer, from, 5))
        {
            return nil;
        }
        
        result = [NSMutableData dataWithCapacity:4096];
        [result appendBytes:buffer length:5];
        
        pos += 5;
        
        while (*endOffset == 0)
        {
            char *line;
            
            // read next line
            line = fgets(buffer, 8192, file);
            
            if (line == NULL)
            {
                *endOffset = length - 1;
            }
            else if (memcmp(from, line, 5))
            {
                [result appendBytes:line length:strlen(line)];
                pos = ftell(file);
            }
            else
            {
                *endOffset = pos - 1;
            }
        }
        
        if (*endOffset == 0)
        {
            result = nil;
        }
    }
    return result;
}


- (BOOL) isReadOnly
{
    return _isReadOnly;
}

- (NSString*) path
{
    NSString *result;
    
    @synchronized(self)
    {
        result = [_path retain];
    }
    
    NSAssert(result, @"No 'path' set up.");
    
    return [result autorelease];
}


- (void) setPath: (NSString*) aPath
{
    @synchronized(self)
    {
        if (aPath!=_path) 
        {
            [_path release];
            _path = [aPath copy];
            
            if (_mboxFile) 
            {
                fclose(_mboxFile);
                _mboxFile = NULL;
            }
        }
    }
}

- (FILE*) mboxFile
/*" Returns the underlying, open unix file. "*/
{
    @synchronized(self) {
        if (! _mboxFile) {
            NSAssert(_path != nil, @"_path == nil");
            
            _mboxFile = fopen([[self path] fileSystemRepresentation], "ab+");
            NSAssert(_mboxFile != NULL, @"Cannot open mbox file.");
        }
    }
    return _mboxFile;
}

- (unsigned int) mboxFileSize
{
    FILE *file;
    unsigned int result = 0;
    
    @synchronized(self)
    {
        file = [self mboxFile];
        
        if (fseek(file, 0, SEEK_END) != 0)
        {
            [NSException raise:NSRangeException format: @"The range's location is behind end of the file."];
        }
        
        result = ftell(file);
    }
    
    return result;
}


- (NSString*) description
{
    NSString *result;
    
    @synchronized(self)
    {
        result = [NSString stringWithFormat: @"%@ at %@", [super description], [self path]];
    }
    
    return result;
}

- (void) appendMBoxData: (NSData*) mboxData
{
    @synchronized(self)
    {
        FILE *file = [self mboxFile];
        
        NSAssert(mboxData, @"Error: Objects not in place.");
        
        if (fwrite([mboxData bytes], 1, [mboxData length], file) < [mboxData length])
        {
            [NSException raise:NSObjectInaccessibleException format: @"Exception raised in -appendMBoxData: ! Could not write message to mbox file."];
        }
        
        fflush(file);
    }
}

- (void) dealloc
{
    if (_mboxFile) fclose(_mboxFile);    
    [_path release];
    [_dateOfMostRecentChange release];
    
    [super dealloc];
} 

@end

@implementation OPMessageDataEnumerator

+ (id)enumeratorWithMBox: (OPMBoxFile*) theMbox
{
    return [[[self alloc] initWithMBox:theMbox] autorelease];
}

- (id)initWithMBox: (OPMBoxFile*) theMbox
{
    if (self = [super init]) 
    {
        mbox = [theMbox retain];
        offset = 0;
        length = (unsigned) [theMbox mboxFileSize];
    }
    return self;
}

- (unsigned)offsetOfNextObject 
{
    return offset;
}

- (id)nextObject
{
    unsigned endOffset;
    NSData *mboxData;
    NSRange range;
    
    if (offset >= length) return nil;
	
    mboxData = [mbox mboxSubdataFromOffset:offset endOffset:&endOffset];
	
    if (mboxData == nil)
    {
        NSLog(@"Warning: No data for making message... (%u %u) trying at next position (leaving out garbage)", offset, endOffset);
        offset += 1; // trying at next position (leaving out garbage)
        return [NSData data];
    }
	
    range = NSMakeRange(offset, endOffset - offset + 1);
	
    offset = endOffset + 1;
	
    return mboxData;
}

- (void) dealloc 
{
    [mbox release];
    [super dealloc];
}

@end

