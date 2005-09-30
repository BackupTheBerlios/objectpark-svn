/*
 $Id: GIMessageFilterAction.h,v 1.4 2005/05/11 08:52:23 mikesch Exp $

 Copyright (c) 2002, 2003 by Axel Katerbau. All rights reserved.

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

@class GIMessage;

typedef enum GIMessageFilterActionType GIMessageFilterActionType;
enum GIMessageFilterActionType
{
    kGIMFActionTypeColorChange = 1,
    kGIMFActionTypePlaySound,
    kGIMFActionTypePutInMessagebox,
    kGIMFActionTypeForwardTo,
    kGIMFActionTypeDelete,
    kGIMFActionTypePreventFurtherFiltering
};

@interface GIMessageFilterAction : NSObject
{
    @private NSMutableDictionary *_actionDefinition;	/*" a dictionary that defines the action "*/
}

/*" Initializers "*/
- (id)initWithActionDefinitionDictionary:(NSDictionary *)aDictionary;

/*" Accessors "*/
- (NSDictionary *)actionDefinitionDictionary;

- (int)state;
- (void)setState:(int)aState;

- (int)type;
- (void)setType:(int)aType;

- (NSString *)parameter;
- (void)setParameter:(NSString *)aString;

@end

@protocol GIMessageFilterActionPerformer

+ (BOOL)performAction:(GIMessageFilterAction *)action withMessage:(GIMessage *)message flags:(int)flags putIntoMessagebox:(BOOL *)putInBox;
/*" Performs the given action if capable. Returns NO if this action wants to prevent further filtering. YES otherwise.

    If putInBox is given (may be NULL) it is set to YES when the given
    message was put into a box. NO otherwise
    (This is for getting to know if a message is put into at least one box).

    Throws exception if a fatal error occurs that may lead to data loss if unappropriate
    action is taken (e.g. deleting messages from server is not a good idea if this happens)."*/

@end

@interface GIMessageFilterAction (Performer) <GIMessageFilterActionPerformer>
@end