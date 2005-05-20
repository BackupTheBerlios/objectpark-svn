 /*
 $Id: G3Message+Rendering.h,v 1.2 2004/12/23 16:57:06 theisen Exp $
 
 Copyright (c) 2002 by Axel Katerbau. All rights reserved.
 
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
 
 Further information can be found on the project's web pages
 at http://www.objectpark.org/Ginko.html
 */

#import <Cocoa/Cocoa.h>
#import "G3Message.h"
#import "EDHeaderFieldCoder.h"

@interface G3Message (Rendering) 

/*
{
    @private
    OPInternetMessage*  theMessage;
    int                 _headerLength; //" length of the header area in characters. Used to change headers displayed. "
    NSMutableAttributedString* messageContent;
    BOOL                _includeAllHeaders;
    NSImage*            cachedImage;
}
*/

/*" Class methods "*/
+ (NSMutableAttributedString*) renderedHeaders:(NSArray *)headers forMessage: (OPInternetMessage*) aMessage showOthers:(BOOL)showOthers;
//+ (NSAttributedString*) renderedMessage: (OPInternetMessage*) aMessage;
+ (NSMutableAttributedString*) renderedBodyForMessage: (OPInternetMessage*) aMessage;

    /*" Font settings "*/
+ (NSFont *)font;
+ (void)setFont:(NSFont *)aFont;

    /*" Inline display settings "*/
+ (BOOL)shouldRenderAttachmentsInlineIfPossible;
+ (void)setShouldRenderAttachmentsInlineIfPossible:(BOOL)aBool;

    /*" Instance methods "*/
- (NSAttributedString*) renderedMessageIncludingAllHeaders: (BOOL) allHeaders;
- (NSImage*) personImage;


@end
