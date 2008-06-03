/* 
     $Id: OPMultimediaContentCoder.m,v 1.6 2005/05/03 10:26:50 theisen Exp $

     Copyright (c) 2001 by Axel Katerbau. All rights reserved.

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

#import "OPMultimediaContentCoder.h"
#import "NSData+MessageUtils.h"
#import "OPInternetMessage.h"
#import "NSAttributedString+MessageUtils.h"
#import "NSString+MessageUtils.h"
#import "NSString+Extensions.h"
#import "EDTextFieldCoder.h"

@implementation OPMultimediaContentCoder

- (id) encodeDataWithClass: (Class) targetClass
{
    NSString *ctString, *cdString, *encodedFileName;
    NSDictionary* parameters = nil;
    
    EDMessagePart* result = [[[targetClass alloc] init] autorelease];
    
    if((filename != nil) && ((ctString = [self contentType]) != nil)) {
        encodedFileName = [(EDTextFieldCoder*) [EDTextFieldCoder encoderWithText: filename] fieldBody];
        parameters = [NSDictionary dictionaryWithObject: encodedFileName forKey: @"name"];
        [result setContentType: ctString withParameters:parameters];
    } else if(filename != nil) {
        encodedFileName = [(EDTextFieldCoder *)[EDTextFieldCoder encoderWithText:filename] fieldBody];
        parameters = [NSDictionary dictionaryWithObject: encodedFileName forKey: @"name"];
        [result setContentType: @"application/octet-stream" withParameters: parameters];
    } else {
        [result setContentType: @"application/octet-stream"];
    }
    
    if(shouldBeDisplayedInline != UNKNOWN) {
        cdString = (shouldBeDisplayedInline) ? MIMEInlineContentDisposition : MIMEAttachmentContentDisposition;
        if(filename != nil) {
            [result setContentDisposition: cdString 
						   withParameters: [NSDictionary dictionaryWithObject: filename forKey: @"filename"]];
		} else {
            [result setContentDisposition: cdString];
		}
    }
    
    [result setContentTransferEncoding: MIMEBase64ContentTransferEncoding];
    
    [result setContentData: data];
    
    return result;
}

- (id) _encodeDataWithClass: (Class) targetClass
{
    id messagePart = [self encodeDataWithClass: targetClass];
    
    if (xUnixMode) {
        NSMutableDictionary* contentTypeParameters = [[messagePart contentTypeParameters] mutableCopy];
        
        [contentTypeParameters setObject: xUnixMode forKey: @"x-unix-mode"];
        [messagePart setContentType: [messagePart contentType] withParameters: contentTypeParameters];
        
        [contentTypeParameters release];
    }
    
    return messagePart;
}

+ (BOOL) canDecodeMessagePart: (EDMessagePart*) mpart
{
    NSString *ct = [[[mpart contentType] componentsSeparatedByString: @"/"] objectAtIndex:0];
    if ([ct isEqualToString: @"image"] || [ct isEqualToString: @"audio"] || [ct isEqualToString: @"video"] || [ct isEqualToString: @"application"])
        return YES;
    if ([[mpart contentDisposition] caseInsensitiveCompare: @"attachment"] == NSOrderedSame)
        return YES;
    return NO;
}

+ (BOOL)canEncodeAttributedString: (NSAttributedString*) anAttributedString atIndex:(int)anIndex effectiveRange:(NSRangePointer)effectiveRange
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
        NSFileWrapper *fileWrapper;
        
        fileWrapper = [attachment fileWrapper];
        
//#warning axel->all: no symbolic links at this time
        if ([fileWrapper isRegularFile]) {
            return YES;
        }
    }
    
    return NO;
}

- (id) initWithFileWrapper: (NSFileWrapper*) aFileWrapper
{
    NSData* fileContents = nil;
    NSString* theFilename = [aFileWrapper filename];

    if (! theFilename) {
        theFilename = [aFileWrapper preferredFilename];
    }
    
    @try {
        fileContents = [aFileWrapper regularFileContents];
    } @catch (id localException) {
        [self dealloc];
        NSLog(@"OPMultimediaContentCoder can't encode attributedString. It's not a regular file.");
        return nil;
    }
    
    // get the permissions
    NSDictionary* attributes       = [aFileWrapper fileAttributes];
    NSNumber*     posixPermissions = [attributes objectForKey: NSFilePosixPermissions];
    
    if (posixPermissions) {
        xUnixMode = [[NSString xUnixModeString: [posixPermissions intValue]] retain];
    }
    
    // strip doublequotes from theFilename
	NSArray* components = [theFilename componentsSeparatedByString: @"\""];
	theFilename = [components componentsJoinedByString: @"'"];
    
    return [self initWithData: fileContents filename: theFilename];
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

//---------------------------------------------------------------------------------------
//	CONTENT ATTRIBUTES
//---------------------------------------------------------------------------------------

- (NSData*) data
{
    return data;
}


- (NSString*) filename
{
    return [[filename retain] autorelease];
}


- (BOOL)shouldBeDisplayedInline
{
    return (shouldBeDisplayedInline != NO);
}


- (EDMessagePart*) messagePart
{
    return [self _encodeDataWithClass: [EDMessagePart class]];
}


- (OPInternetMessage *)message
{
    return [self _encodeDataWithClass:[OPInternetMessage class]];
}

//---------------------------------------------------------------------------------------
//	INIT & DEALLOC
//---------------------------------------------------------------------------------------

- (id)initWithMessagePart:(EDMessagePart *)mpart
{
    if (self = [super init]) 
	{
		if ((filename = [[mpart contentDispositionParameters] objectForKey:@"filename"]) != nil)
		{
			filename = [[filename lastPathComponent] retain];
		}
		else if ((filename = [[mpart contentTypeParameters] objectForKey:@"name"]) != nil)
		{
			filename = [[filename lastPathComponent] retain];
		}
		else
		{
			filename = nil;
		}
		
		data = [[mpart contentData] retain];
		contentType = [[mpart contentType] retain];
		
		if ([mpart contentDisposition] == nil) 
		{
			NSString *ct = [[contentType componentsSeparatedByString:@"/"] objectAtIndex:0];
			
			if ([ct isEqualToString:@"image"] || [ct isEqualToString:@"video"])
			{
				shouldBeDisplayedInline = [data length] < (1024 * 1024);
			}
			else
			{
				shouldBeDisplayedInline = NO; 
			}
		} 
		else 
		{
			shouldBeDisplayedInline = [[mpart contentDisposition] isEqualToString:MIMEInlineContentDisposition];
		}
		
		xUnixMode = [[[mpart contentTypeParameters] objectForKey:@"x-unix-mode"] retain];
	}
	
    return self;
}

- (id)initWithData:(NSData *)someData filename:(NSString *)aFilename
{
    return [self initWithData:someData filename:aFilename inlineFlag:UNKNOWN];
}

- (id)initWithData:(NSData *)someData filename:(NSString *)aFilename inlineFlag:(BOOL)inlineFlag
{
    if (self = [super init]) 
	{
		data = [someData retain];
		filename = [aFilename retain];
		shouldBeDisplayedInline = inlineFlag;
	}
	
    return self;
}

- (void) dealloc
{
    [data release];
    [filename release];
    [xUnixMode release];
	[contentType release];
	
    [super dealloc];
}

- (NSString *)contentType
{
	if (!contentType && filename)
	{
		return [NSString contentTypeForPathExtension:[filename pathExtension]];
	}
	else
	{
		return contentType;
	}
}

- (void)setContentType:(NSString *)aContentType
{
	[aContentType retain];
	[contentType release];
	contentType = aContentType;
}

- (NSFileWrapper *)fileWrapper
{
	NSString *preferredFilename = [self filename];
    NSString *rawPreferredFilename = preferredFilename ? preferredFilename : @"unknown attachment";
    
    // use coder
    preferredFilename = [(EDTextFieldCoder *)[EDTextFieldCoder decoderWithFieldBody:rawPreferredFilename] text];
    
    NSFileWrapper *result = [[[NSFileWrapper alloc] initRegularFileWithContents:[self data]] autorelease];
    [result setPreferredFilename:preferredFilename]; // file name
    
    if (xUnixMode) 
	{
        NSMutableDictionary *attributes;
        // attributes
        attributes = [[result fileAttributes] mutableCopy];
        [attributes setObject: [NSNumber numberWithLong:[xUnixMode octalValue]] forKey:NSFilePosixPermissions];
        [result setFileAttributes:attributes]; 
        [attributes release];
    }
    
    return result;
}

- (NSAttributedString *)attributedString
{
    NSMutableAttributedString *result = [[[NSMutableAttributedString alloc] init] autorelease];

    [result appendAttachmentWithFileWrapper:[self fileWrapper]];
    
    return result;
}

- (NSString *)string
{
    return filename ? [[@"\n" stringByAppendingString:filename] stringByAppendingString:@"\n"] : @" ";
}

@end
