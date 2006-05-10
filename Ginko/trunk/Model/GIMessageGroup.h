//
//  GIMessageGroup.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 02.08.05.
//  Copyright 2005 The Objectpark Group. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "OPPersistentObject.h"
#import "OPPersistentObject+Extensions.h"

@class GIProfile;
@class GIThread;

@interface GIMessageGroup : OPPersistentObject 
{
    // transient stats:
    NSNumber *unreadMessageCount; 
}

/*" MessageGroup types "*/
#define GIRegularMessageGroup 1
#define GIDefaultMessageGroup 2
#define GIQueuedMessageGroup 3
#define GIDraftMessageGroup 4
#define GISentMessageGroup 5
#define GISpamMessageGroup 6
#define GITrashMessageGroup 7

/*" Sent when a new message group was added. %{object} holds the added GIMessageGroup object. "*/
extern NSString *GIMessageGroupWasAddedNotification;
extern NSString *GIMessageGroupsChangedNotification;

/*" Dealing with the group hierarchie: "*/
+ (NSMutableArray *)hierarchyRootNode;
+ (GIMessageGroup *)newMessageGroupWithName:(NSString* )aName atHierarchyNode:(NSMutableArray *)aNode atIndex:(int)anIndex;
+ (void)addNewHierarchyNodeAfterEntry:(id)anEntry;
+ (NSMutableArray *)hierarchyNodeForUid:(NSNumber *)aUid;
+ (BOOL)moveEntry:(id)entry toHierarchyNode:(NSMutableArray *)aHierarchy atIndex:(int)anIndex testOnly:(BOOL)testOnly;
+ (NSMutableArray *)findHierarchyNodeForEntry:(id)entry startingWithHierarchyNode:(NSMutableArray *)aHierarchy;
+ (void) removeHierarchyNode: (id) entry;

/*" Standard message groups "*/
+ (GIMessageGroup *)defaultMessageGroup;
+ (void)setDefaultMessageGroup:(GIMessageGroup *)aMessageGroup;
+ (GIMessageGroup *)sentMessageGroup;
+ (void)setSentMessageGroup:(GIMessageGroup *)aMessageGroup;
+ (GIMessageGroup *)queuedMessageGroup;
+ (void)setQueuedMessageGroup:(GIMessageGroup *)aMessageGroup;
+ (GIMessageGroup *)draftMessageGroup;
+ (void)setDraftMessageGroup:(GIMessageGroup *)aMessageGroup;
+ (GIMessageGroup *)spamMessageGroup;
+ (void)setSpamMessageGroup:(GIMessageGroup *)aMessageGroup;
+ (GIMessageGroup *)trashMessageGroup;
+ (void)setTrashMessageGroup:(GIMessageGroup *)aMessageGroup;

- (NSString*) imageName;
- (int) type;


+ (void)ensureDefaultGroups;

/*" Thread handling "*/
+ (void) moveThreadsWithOids: (NSArray*) threadOids 
				   fromGroup: (GIMessageGroup*) sourceGroup 
					 toGroup: (GIMessageGroup*) destinationGroup;

-  (NSArray*) fetchThreadsNewerThan: (NSTimeInterval) sinceRefDate
						withSubject: (NSString*) subject
							 author: (NSString*) author
			  sortedByDateAscending: (BOOL) ascending;

/*" Profile handling "*/
- (GIProfile*) defaultProfile;
- (void) setDefaultProfile: (GIProfile*) aProfile;

/*" Persistency handling "*/
+ (void) saveHierarchy;

- (NSArray *)allMessages;
- (void)exportAsMboxFileWithPath:(NSString *)path;


@end
