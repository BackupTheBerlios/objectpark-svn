/* 
     OPInternetMessage+GinkoExtensions.h created by axel on Sat 09-Dec-2000
     $Id: OPInternetMessage+GinkoExtensions.h,v 1.3 2004/12/26 11:19:23 mikesch Exp $

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

     Further information can be found on the project's web pages
     at http://www.objectpark.org/Ginko.html
*/

#import <Foundation/Foundation.h>
#import "OPInternetMessage.h"

@class OPMessageAccount;
@class OPObjectPair;

@interface OPInternetMessage (GinkoExtensions)

- (NSMutableAttributedString *)bodyContent;
- (NSAttributedString *)editableBodyContent;

//- (BOOL) isUsenetMessage;
//- (BOOL) isEMailMessage;
//- (BOOL) isListMessage;
//- (BOOL) isPublicMessage;
//- (BOOL) isFromMe;

//- (void) generateMessageIdWithAccount: (OPMessageAccount*) anAccount;

//- (BOOL) isGinkoMessage;

- (BOOL)isMultiHeader:(NSArray *)headerField;

@end
