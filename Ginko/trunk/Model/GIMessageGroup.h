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
}

/*" Sent when a new message group was added. %{object} holds the added GIMessageGroup object. "*/
extern NSString* GIMessageGroupWasAddedNotification;

/*" Dealing with the group hierarchie: "*/
+ (NSMutableArray*) hierarchyRootNode;
+ (GIMessageGroup *)newMessageGroupWithName:(NSString *)aName atHierarchyNode:(NSMutableArray *)aNode atIndex:(int)anIndex;
+ (void)addNewHierarchyNodeAfterEntry:(id)anEntry;
+ (NSMutableArray *)hierarchyNodeForUid:(NSNumber *)aUid;
+ (BOOL)moveEntry:(id)entry toHierarchyNode:(NSMutableArray *)aHierarchy atIndex:(int)anIndex testOnly:(BOOL)testOnly;
+ (NSMutableArray *)findHierarchyNodeForEntry:(id)entry startingWithHierarchyNode:(NSMutableArray *)aHierarchy;
+ (void) removeHierarchyNode: (id) entry;

/*" Standard message groups "*/
+ (GIMessageGroup*) defaultMessageGroup;
+ (GIMessageGroup*) sentMessageGroup;
+ (GIMessageGroup*) queuedMessageGroup;
+ (GIMessageGroup*) draftMessageGroup;
+ (GIMessageGroup*) spamMessageGroup;
+ (GIMessageGroup*) trashMessageGroup;
+ (NSImage*) imageForMessageGroup: (GIMessageGroup*) aMessageGroup;
+ (void) ensureDefaultGroups;

/*" Thread handling "*/
+ (void) moveThreadsWithOids: (NSArray*) threadOids 
				   fromGroup: (GIMessageGroup*) sourceGroup 
					 toGroup: (GIMessageGroup*) destinationGroup;

-  (void) fetchThreads: (NSMutableArray**) allThreads
			 newerThan: (NSTimeInterval) sinceRefDate
		   withSubject: (NSString*) subject
				author: (NSString*) author
 sortedByDateAscending: (BOOL) ascending;

/*" Profile handling "*/
- (GIProfile*) defaultProfile;
- (void) setDefaultProfile: (GIProfile*) aProfile;

/*" Persistency handling "*/
+ (void) saveHierarchy;

- (NSEnumerator*) allMessagesEnumerator;
- (void) exportAsMboxFile;

@end
