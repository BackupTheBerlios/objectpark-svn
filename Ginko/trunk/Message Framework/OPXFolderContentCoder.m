/* 
     Copyright (c) 2001, 2005 by Axel Katerbau. All rights reserved.

     Permission to use, copy, modify and distribute this software and its documentation
     is hereby granted, provided that both the copyright notice and this permission
     notice appear in all copies of the software, derivative works or modified versions,
     and any portions thereof, and that both notices appear in supporting documentation,
     and that credit is given to Axel Katerbau in all documents and publicity
     pertaining to direct or indirect use of this code or its derivatives.

     THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
     SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
     "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
     DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
     OR OF ANY DERIVATIVE WORK.
*/

#import "OPXFolderContentCoder.h"
#import "OPMultimediaContentCoder.h"
#import "EDMessagePart+OPExtensions.h"
#import "NSAttributedString+MessageUtils.h"
#import "NSString+MessageUtils.h"
#import "OPObjectPair.h"
#import "EDTextFieldCoder.h"

@interface EDCompositeContentCoder (PrivateAPI)
- (id)_encodeSubpartsWithClass:(Class)targetClass subtype:(NSString *)subtype;
@end

@implementation OPXFolderContentCoder

+ (BOOL)canDecodeMessagePart:(EDMessagePart *)mpart
{
    return [[mpart contentType] isEqualToString: @"multipart/x-folder"];
}

+ (BOOL)canEncodeAttributedString:(NSAttributedString *)anAttributedString atIndex:(int)anIndex effectiveRange:(NSRangePointer)effectiveRange
/*"
   Decides if anAttributedString can be encoded starting at anIndex. If YES is returned effectiveRange 
   designates the range which can be encoded by this class. If NO is returned effectiveRange indicates
   the range which can not be encoded by this class.
"*/
{
    NSRange limitRange;
    NSTextAttachment *attachment;
    
    limitRange = NSMakeRange(anIndex, 1);
    
    attachment = [anAttributedString attribute:NSAttachmentAttributeName atIndex:anIndex longestEffectiveRange:effectiveRange inRange:limitRange];
    
    if (attachment)
    {
        NSFileWrapper *fileWrapper = [attachment fileWrapper];
        if ([fileWrapper isDirectory]) return YES;
    }
    
    return NO;
}

- (id)initWithFileWrapper: (NSFileWrapper*) aFileWrapper
{
    NSFileWrapper* fileWrapper;
    NSDictionary* attributes;
    NSNumber* posixPermissions;
    NSMutableArray* someParts;
    NSEnumerator* enumerator;
    
    if (! (filename = [[aFileWrapper filename] retain])) {
        filename = [[aFileWrapper preferredFilename] retain];
    }
    
    if (! filename) filename = @"";
    
    // strip doublequotes from theFilename
	NSArray* components = [filename componentsSeparatedByString: @"\""];
	filename = [components componentsJoinedByString: @"'"];
    
    
    // get the permissions
    attributes = [aFileWrapper fileAttributes];
    posixPermissions = [attributes objectForKey: NSFilePosixPermissions];
    
    if (posixPermissions) {
        xUnixMode = [[NSString xUnixModeString: [posixPermissions intValue]] retain];
    }
    
    // collect subparts
    someParts = [NSMutableArray array];
    
    enumerator = [[aFileWrapper fileWrappers] objectEnumerator];
    while (fileWrapper = [enumerator nextObject]) {
        if ([fileWrapper isDirectory]) {
            OPXFolderContentCoder* coder = [[OPXFolderContentCoder alloc] initWithFileWrapper: fileWrapper];
            
            [someParts addObject:[coder messagePart]];
            
            [coder release];
        } else if ([fileWrapper isRegularFile]) {
            OPMultimediaContentCoder *coder = [[OPMultimediaContentCoder alloc] initWithFileWrapper: fileWrapper];
            
            [someParts addObject: [coder messagePart]];
            
            [coder release];
        }
        else
        {
            NSLog(@"A symbolic link? Ouch. that shouldn't be the case");
        }
//#warning axel->all: symbolic links are not supported yet
    }
    
    return [super initWithSubparts: someParts];
}

- (void) _ensureAttachmentDispositionForMessagePart: (EDMessagePart*) messagePart
/*"Ensures "attachment" content-disposition for message part. Preserves the parameters."*/
{    
    if ([[messagePart contentDisposition] caseInsensitiveCompare: MIMEAttachmentContentDisposition] != NSOrderedSame)
    {
        //if (NSDebugEnabled) NSLog(@"set to attachment");
        
        if ([[messagePart contentDispositionParameters] count] > 0)
        {
            [messagePart setContentDisposition:MIMEAttachmentContentDisposition 
                withParameters:[messagePart contentDispositionParameters]];
        }
        else
        {
            [messagePart setContentDisposition:MIMEAttachmentContentDisposition]; 
        }
    }
}

//#warning axel->axel: submit to Erik when stable
- (id)_encodeSubpartsWithClass:(Class)targetClass subtype: (NSString*) subtype
/*" overwritten by this category. beware. "*/
{
    id messagePart;
    NSMutableDictionary *contentTypeParameters;
    NSEnumerator *enumerator;
    NSString *encodedFileName;
    
    // ensure "attachment" content disposition for subparts
    enumerator = [[self subparts] objectEnumerator];
    while (messagePart = [enumerator nextObject])
    {
        [self _ensureAttachmentDispositionForMessagePart:messagePart];
    }
    
    messagePart = [super _encodeSubpartsWithClass:targetClass subtype: @"mixed"];
    
    contentTypeParameters = [[messagePart contentTypeParameters] mutableCopy];
    
    if (xUnixMode)
    {
        [contentTypeParameters setObject: xUnixMode forKey: @"x-unix-mode"];
    }
    
    encodedFileName = [(EDTextFieldCoder *)[EDTextFieldCoder encoderWithText:filename] fieldBody];
    [contentTypeParameters setObject: encodedFileName forKey: @"name"];
    [messagePart setContentType: @"multipart/x-folder"
                 withParameters: contentTypeParameters];
    
    [contentTypeParameters release];

    [self _ensureAttachmentDispositionForMessagePart:messagePart];
    
    return messagePart;
}

- (id)initWithAttributedString: (NSAttributedString*) anAttributedString
{
    NSRange effectiveRange;
    NSTextAttachment *attachment;
    
    if (! (attachment = [anAttributedString attribute:NSAttachmentAttributeName atIndex:0 longestEffectiveRange:&effectiveRange inRange:NSMakeRange(0, 1)]))
    {
        [self dealloc];
        NSLog(@"OPMultimediaContentCoder can't encode attributedString '%@'.", anAttributedString);
        return nil;
    }

    return [self initWithFileWrapper:[attachment fileWrapper]];
}

- (id)initWithMessagePart: (EDMessagePart*) mpart
{
    [super initWithMessagePart:mpart];

    if((filename = [[mpart contentDispositionParameters] objectForKey: @"filename"]) != nil)
        filename = [filename lastPathComponent];
    else if((filename = [[mpart contentTypeParameters] objectForKey: @"name"]) != nil)
        filename = [filename lastPathComponent];
    else
        filename = nil;
        
    // decode filename
    if (filename)
        filename = [[(EDTextFieldCoder *)[EDTextFieldCoder decoderWithFieldBody:filename] text] retain];

    xUnixMode = [[[mpart contentTypeParameters] objectForKey: @"x-unix-mode"] retain];
        
    return self;
}

- (void) dealloc
{
    [filename release];
    [xUnixMode release];
    [super dealloc];
}

- (NSFileWrapper *)fileWrapper
{
    NSString *rawPreferredFilename, *preferredFilename;
    NSFileWrapper *result;
    NSEnumerator *enumerator;
    EDMessagePart *subpart;
        
    rawPreferredFilename = (preferredFilename = filename) ? preferredFilename : @"unknown attachment";
    
    // use coder
    preferredFilename = [(EDTextFieldCoder *)[EDTextFieldCoder decoderWithFieldBody:rawPreferredFilename] text];
    
    result = [[[NSFileWrapper alloc] initDirectoryWithFileWrappers: nil] autorelease];
    [result setPreferredFilename: preferredFilename]; // file name
    
    
    if (xUnixMode) // unix permissions
    {
        NSMutableDictionary *attributes;
        // attributes
        attributes = [[result fileAttributes] mutableCopy];
        [attributes setObject: [NSNumber numberWithLong:[xUnixMode octalValue]] forKey:NSFilePosixPermissions];
        [result setFileAttributes:attributes]; 
        [attributes release];
    }

    // collect sub file wrappers
        
    enumerator = [[self subparts] objectEnumerator];
    while (subpart = [enumerator nextObject])
    {        
        Class coderClass;

        [self _ensureAttachmentDispositionForMessagePart:subpart];
        
        if ((coderClass = [subpart contentDecoderClass]) != nil)
        {
            NSFileWrapper *fileWrapper;
            EDContentCoder *coder = nil;
        
            NS_DURING
                coder = [[coderClass alloc] initWithMessagePart:subpart];
                
                if ([coder respondsToSelector:@selector(fileWrapper)])
                {
                    fileWrapper = [(id)coder fileWrapper];
                    [result addFileWrapper:fileWrapper];
                }
                else
                {
                    NSLog(@"X-Folder contains invalid or not decodable subpart (coder = %@).", coder);
                }
                [coder release];
            NS_HANDLER
                [coder release]; // avoid memory leak
                NSLog(@"Error in X-Folder subpart decoding. (%@)", [localException reason]);
            NS_ENDHANDLER
        }
        else
        {
            NSLog(@"X-Folder contains not subpart that is not decodable.");
        }
    }
            
    return result;
}

- (NSAttributedString *)attributedString
{
    NSMutableAttributedString *result;
    
    result = [[[NSMutableAttributedString alloc] init] autorelease];

    [result appendAttachmentWithFileWrapper:[self fileWrapper]];
    
    return result;
}

- (NSString *)string
{
    return [[@"\n" stringByAppendingString:filename] stringByAppendingString:@"\n"];
}

@end

