//---------------------------------------------------------------------------------------
//  EDContentCoder.m created by erik on Fri 12-Nov-1999
//  @(#)$Id: EDContentCoder.m,v 1.3 2005/01/25 19:09:46 mikesch Exp $
//
//  Copyright (c) 1999 by Erik Doernenburg. All rights reserved.
//
//  Permission to use, copy, modify and distribute this software and its documentation
//  is hereby granted, provided that both the copyright notice and this permission
//  notice appear in all copies of the software, derivative works or modified versions,
//  and any portions thereof, and that both notices appear in supporting documentation,
//  and that credit is given to Erik Doernenburg in all documents and publicity
//  pertaining to direct or indirect use of this code or its derivatives.
//
//  THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
//  SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
//  "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
//  DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
//  OR OF ANY DERIVATIVE WORK.
//---------------------------------------------------------------------------------------

#import <Foundation/Foundation.h>
#import "EDContentCoder.h"
#import "OPInternetMessage.h"
#import "NSObject+Extensions.h"

//---------------------------------------------------------------------------------------
    @implementation EDContentCoder
//---------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------
//	CAPABILITIES
//---------------------------------------------------------------------------------------

+ (BOOL)canDecodeMessagePart:(EDMessagePart *)mpart
{
    return NO;
}

+ (BOOL)canEncodeAttributedString:(NSAttributedString *)anAttributedString atIndex:(int)anIndex effectiveRange:(NSRangePointer)effectiveRange
{
    return NO;
}

//---------------------------------------------------------------------------------------
//	INIT & DEALLOC
//---------------------------------------------------------------------------------------

- (id)initWithMessagePart:(EDMessagePart *)mpart
{
    [self methodIsAbstract:_cmd];
    return self;
}

- (id)initWithAttributedString:(NSAttributedString *)anAttributedString
{
    [self methodIsAbstract:_cmd];
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

//---------------------------------------------------------------------------------------
//	CODING
//---------------------------------------------------------------------------------------

- (EDMessagePart *)messagePart
{
    [self methodIsAbstract:_cmd];
    return nil; // keep compiler happy...
}

- (OPInternetMessage *)message
{
    [self methodIsAbstract:_cmd];
    return nil; // keep compiler happy...
}

- (NSAttributedString *)attributedString
{
    [self methodIsAbstract:_cmd];
    return nil; // keep compiler happy...
}

- (NSString *)string
{
    [self methodIsAbstract:_cmd];
    return nil; // keep compiler happy...
}


// Registering coders:

static NSMutableArray* contentCoders = nil; /*" private variable "*/

/*" OPContentCoderCenter is responsible for encoding and decoding email messages. Every coder has to be registered here. It must be either a sub class of EDContentCoder or has to implement the OPContentCoderProtocol. "*/


+ (void) initialize
	/*"
	Register all default content coder in reverse order. The content coder will be used in reverse order.
	 "*/
{
    if (! contentCoders) {
		
		contentCoders = [[NSMutableArray alloc] initWithCapacity: 10];
        // register in reverse order because the most recent registered decoder
        // will be called first
        [self registerContentCoderNamed: @"EDTextContentCoder"];
        [self registerContentCoderNamed: @"EDPlainTextContentCoder"];
        [self registerContentCoderNamed: @"OPMultimediaContentCoder"];
        [self registerContentCoderNamed: @"OPApplefileContentCoder"];
        [self registerContentCoderNamed: @"OPMultipartContentCoder"];
        [self registerContentCoderNamed: @"OPAppleDoubleContentCoder"];
        [self registerContentCoderNamed: @"OPXFolderContentCoder"];
    }
}


+ (void) registerContentCoderNamed: (NSString*) coderClassName
{	
	if (![contentCoders containsObject: coderClassName]) {
		[contentCoders addObject: coderClassName];
	}
}

+ (Class) contentDecoderClass: (EDMessagePart*) mpart 
	/* Returns the class of the message part or nil of none is available. Convenient method for [[OPContentCoderCenter contentCoderCenter] contentDecoderClass:mpart]. */
{
    NSEnumerator* enumerator = [contentCoders reverseObjectEnumerator];
    NSString* contentCoderName;
    Class contentCoder;
    
    // deciding which content coder to use
    while (contentCoderName = [enumerator nextObject]) {
        contentCoder = NSClassFromString(contentCoderName);
        if ([contentCoder canDecodeMessagePart: mpart]) {
            return contentCoder;
        }
    }
    return nil;
}

+ (Class) contentEncoderClassForAttributedString: (NSAttributedString*) anAttributedString 
										 atIndex: (int) anIndex 
								  effectiveRange: (NSRangePointer) effectiveRange 
{
    NSEnumerator *enumerator = [contentCoders reverseObjectEnumerator];
    NSString *contentCoderName;
    Class contentCoder;
    Class result = nil;
    
    // deciding which content coder to use
    while ((contentCoderName = [enumerator nextObject]) && (result == nil)) {
        contentCoder = NSClassFromString(contentCoderName);
        if (NSDebugEnabled) NSLog(@"Trying content encoder %@", NSStringFromClass(contentCoder));
        @try {
            if ([contentCoder canEncodeAttributedString: anAttributedString 
												atIndex: anIndex 
										 effectiveRange: effectiveRange]) {
                result = contentCoder;
            }
        } @catch (id localException) {
            NSLog(@"exception %@", [localException reason]);
		}
    }
    return result;
}


//---------------------------------------------------------------------------------------
    @end
//---------------------------------------------------------------------------------------

