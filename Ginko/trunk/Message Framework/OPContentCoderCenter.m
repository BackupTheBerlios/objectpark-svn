/* 
     $Id: OPContentCoderCenter.m,v 1.2 2004/12/24 01:13:55 mikesch Exp $

     Copyright (c) 2001 by Bjoern Bubbat. All rights reserved.

     Permission to use, copy, modify and distribute this software and its documentation
     is hereby granted, provided that both the copyright notice and this permission
     notice appear in all copies of the software, derivative works or modified versions,
     and any portions thereof, and that both notices appear in supporting documentation,
     and that credit is given to Bjoern Bubbat in all documents and publicity
     pertaining to direct or indirect use of this code or its derivatives.

     THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
     SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
     "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
     DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
     OR OF ANY DERIVATIVE WORK.
*/

#import "OPContentCoderCenter.h"
#import "EDContentCoder.h"
#import "EDTextContentCoder.h"
#import "OPMultimediaContentCoder.h"
#import "OPApplefileContentCoder.h"
#import "OPAppleDoubleContentCoder.h"
#import "EDPlainTextContentCoder.h"

#import "OPMultipartContentCoder.h"
#import "OPXFolderContentCoder.h"
#import <Foundation/NSDebug.h>


@interface OPContentCoderCenter(PrivateAPI)

-(void)registerContentCoder:(Class)coderClass;
- (Class)contentDecoderClass: (EDMessagePart*) mpart;

@end


@implementation OPContentCoderCenter
/*"
OPContentCoderCenter is responsible for encoding and decoding email messages. Every coder has to be registered here. It must be either a sub class of EDContentCoder or has to implement the OPContentCoderProtocol.
"*/


+(void)initialize
/*"
Register all default content coder in reverse order. The content coder will be used in reverse order.
"*/
{
    static BOOL hasBeenInitialized = NO;
    
    if (!hasBeenInitialized) {
        // register in reverse order because the most recent registered decoder
        // will be called first
        [OPContentCoderCenter registerContentCoder:[EDTextContentCoder class]];
        [OPContentCoderCenter registerContentCoder:[EDPlainTextContentCoder class]];
        [OPContentCoderCenter registerContentCoder:[OPMultimediaContentCoder class]];
        [OPContentCoderCenter registerContentCoder:[OPApplefileContentCoder class]];
        [OPContentCoderCenter registerContentCoder:[OPMultipartContentCoder class]];
        [OPContentCoderCenter registerContentCoder:[OPAppleDoubleContentCoder class]];
        [OPContentCoderCenter registerContentCoder:[OPXFolderContentCoder class]];
        hasBeenInitialized = YES;
    }
}

+(OPContentCoderCenter *)contentCoderCenter
/*"
This class returns a OPContentCoderCenter. If no one exists, it will also create one.
"*/
{
    static OPContentCoderCenter* _contentCoderCenter = nil;
    
    if (!_contentCoderCenter) {
        _contentCoderCenter = [[OPContentCoderCenter alloc] init];
    }
    return _contentCoderCenter;
}


+(Class)contentDecoderClass: (EDMessagePart*) mpart
/*"
Returns the class of the message part or nil of none is available. Convenient method for [[OPContentCoderCenter contentCoderCenter] contentDecoderClass:mpart].
"*/
{
    return [[OPContentCoderCenter contentCoderCenter] contentDecoderClass:mpart];
}


+(Class)contentEncoderClassForAttributedString: (NSAttributedString*) anAttributedString atIndex:(int)anIndex effectiveRange:(NSRangePointer)effectiveRange {
    return [[OPContentCoderCenter contentCoderCenter] contentEncoderClassForAttributedString:anAttributedString atIndex:anIndex effectiveRange:effectiveRange];    
}


+ (void) registerContentCoder: (Class) coderClass 
{
     [[OPContentCoderCenter contentCoderCenter] registerContentCoder:coderClass];
}

-(id) init {
    self = [super init];
    if (self) {
        _contentCoder = [[NSMutableArray array] retain];
    }
    return self;
}


-(void)dealloc {
    [_contentCoder release];
    [super dealloc];
}

-(void)registerContentCoder:(Class)coderClass 
{
    NSString *coderClassName = NSStringFromClass(coderClass);
    //if ([coderClass isKindOfClass:[EDContentCoder class]] || [coderClass conformsToProtocol:@protocol(OPContentCoder)]) {
        if (![_contentCoder containsObject:coderClassName]) {
            //if (NSDebugEnabled) NSLog(@"adding class: %@", coderClass);
            [_contentCoder addObject:coderClassName];
        }
    //} else {
    //    [NSException raise: @"OPContentCoderCenter" format: @"Class %@ does not implement OPContentCoderInterface protocol.", coderClassName];
    //}
}


-(Class)contentDecoderClass: (EDMessagePart*) mpart {
    NSEnumerator *enumerator = [_contentCoder reverseObjectEnumerator];
    NSString *contentCoderName;
    Class contentCoder;
    
    // deciding which content coder to use
    while (contentCoderName = [enumerator nextObject]) {
        contentCoder = NSClassFromString(contentCoderName);
        if ([contentCoder canDecodeMessagePart:mpart]) {
            return contentCoder;
        }
    }
    return nil;
}

-(Class)contentEncoderClassForAttributedString: (NSAttributedString*) anAttributedString atIndex:(int)anIndex effectiveRange:(NSRangePointer)effectiveRange {
    NSEnumerator *enumerator = [_contentCoder reverseObjectEnumerator];
    NSString *contentCoderName;
    Class contentCoder;
    Class result = nil;
    
    // deciding which content coder to use
    while ((contentCoderName = [enumerator nextObject]) && (result == nil)) {
        contentCoder = NSClassFromString(contentCoderName);
        if (NSDebugEnabled) NSLog(@"Trying content encoder %@", NSStringFromClass(contentCoder));
        NS_DURING
            if ([contentCoder canEncodeAttributedString:anAttributedString atIndex:anIndex effectiveRange:effectiveRange]) {
                result = contentCoder;
            }
        NS_HANDLER
            NSLog(@"exception %@", [localException reason]);
        NS_ENDHANDLER
    }
   
    return result;
}

@end
