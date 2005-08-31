/*
 $Id: GIMessageFilterAction.m,v 1.9 2005/05/17 18:34:19 mikesch Exp $

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

#import "GIMessageFilterAction.h"
#import "GIMessageFilter.h"
#import "G3Message.h"
#import "G3MessageGroup.h"
#import "GIMessageBase.h"

@implementation GIMessageFilterAction
/*" Model for an action of a messge filter. "*/

- (id)initWithActionDefinitionDictionary:(NSDictionary *)aDictionary
/*" Initializes the action with a defining dictionary "*/
{
    [super init];

    _actionDefinition = [aDictionary mutableCopy];

    return self;
}

- (void)dealloc
/*" Releases ivars. "*/
{
    [_actionDefinition release];

    [super dealloc];
}

- (NSDictionary *)actionDefinitionDictionary
/*" Returns the dictionary that defines the receiver. "*/
{
    return _actionDefinition;
}

- (int)state
{
    return [(NSNumber *)[_actionDefinition objectForKey:@"state"] intValue];
}

- (void)setState:(int)aState
{
    [_actionDefinition setObject:[NSNumber numberWithInt:aState] forKey:@"state"];

    // model changed
    [[NSNotificationCenter defaultCenter] postNotificationName:GIMessageFiltersDidChangeNotification object:self];
}

- (int)type
{
    return [(NSNumber *)[_actionDefinition objectForKey:@"type"] intValue];
}

- (void)setType:(int)aType
{
    [_actionDefinition setObject:[NSNumber numberWithInt:aType] forKey:@"type"];

    // model changed
    [[NSNotificationCenter defaultCenter] postNotificationName:GIMessageFiltersDidChangeNotification object:self];
}

- (NSString *)parameter
{
    return [_actionDefinition objectForKey:@"parameter"];
}

- (void)setParameter:(NSString *)aString
{
    [_actionDefinition setObject:aString forKey:@"parameter"];

    // model changed
    [[NSNotificationCenter defaultCenter] postNotificationName:GIMessageFiltersDidChangeNotification object:self];
}

@end

@implementation GIMessageFilterAction (Performer)

+ (BOOL)performAction:(GIMessageFilterAction *)action withMessage:(G3Message *)message flags:(int)flags putIntoMessagebox:(BOOL *)putInBox
{
    BOOL allowFurtherFiltering = YES;
    
    if (putInBox) *putInBox = NO;
    
    switch ([action type]) 
    {
        case kGIMFActionTypePutInMessagebox: 
        {
            G3MessageGroup *destinationGroup;
            
            // get destination box
            destinationGroup = [G3MessageGroup messageGroupWithURIReferenceString:[action parameter]];
            
            // if destination box can not be found fallback to default box
            if (! destinationGroup) 
            {
                destinationGroup = [G3MessageGroup defaultMessageGroup];
                
                if (! destinationGroup) // fatal -> Exception
                {
                    [NSException raise:NSGenericException format:@"Default message group could neither be found nor created. FATAL ERROR! Aborting filtering."];
                }
            }
            
            // now that a destination box is present put message in
            [GIMessageBase addMessage:message toMessageGroup:destinationGroup suppressThreading:NO];
            if (putInBox) *putInBox = YES;
            break;
        }
            
        case kGIMFActionTypePreventFurtherFiltering:
            allowFurtherFiltering = NO;
            break;
            // ## missing code for other types
        default:
            //OPDebugLog1(FILTERDEBUG, OPINFO, @"filter action %d not yet supported, sorry.", [action type]);
            break;
    }
    
    return allowFurtherFiltering;
}

@end
