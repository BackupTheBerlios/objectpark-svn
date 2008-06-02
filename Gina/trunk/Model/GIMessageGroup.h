//
//  GIMessageGroup.h
//  Gina
//
//  Created by Dirk Theisen on 02.08.05.
//  Copyright 2005 The Objectpark Group. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "OPPersistentObject.h"
#import "GIHierarchyNode.h"
#import "OPLargePersistentSet.h"

@class GIProfile;
@class GIThread;

/*" MessageGroup types "*/
#define GIRegularMessageGroup 0
#define GIDefaultMessageGroup 1
#define GIQueuedMessageGroup 2
#define GIDraftMessageGroup 3
#define GISentMessageGroup 4
#define GISpamMessageGroup 5
#define GITrashMessageGroup 6

@interface GIMessageGroup : GIHierarchyNode 
{
	OPLargePersistentSet *threads;
	OID defaultProfileOID;
	
    // transient stats:
    int unreadMessageCount;
	int type;
}

@property (readonly) NSSet *threads;
@property (readonly) int unreadMessageCount;
@property (readonly) int type;
@property (retain) GIProfile *defaultProfile;

+ (id) newWithName: (NSString*) aName type: (int) groupType atHierarchyNode: (GIHierarchyNode*) aNode atIndex: (int) anIndex;

+ (NSImage*) imageForMessageGroup: (GIMessageGroup*) aMessageGroup;

+ (void)copyThreadsWithURLs:(NSArray *)threadURLs fromGroup:(GIMessageGroup *)sourceGroup toGroup:(GIMessageGroup *)destinationGroup move:(BOOL)move;

/*" Standard message groups "*/
+ (GIMessageGroup *)defaultMessageGroup;
//+ (void)setDefaultMessageGroup:(GIMessageGroup *)aMessageGroup;
+ (GIMessageGroup *)sentMessageGroup;
//+ (void)setSentMessageGroup:(GIMessageGroup *)aMessageGroup;
+ (GIMessageGroup *)queuedMessageGroup;
//+ (void)setQueuedMessageGroup:(GIMessageGroup *)aMessageGroup;
+ (GIMessageGroup *)draftMessageGroup;
//+ (void)setDraftMessageGroup:(GIMessageGroup *)aMessageGroup;
+ (GIMessageGroup *)spamMessageGroup;
//+ (void)setSpamMessageGroup:(GIMessageGroup *)aMessageGroup;
+ (GIMessageGroup *)trashMessageGroup;
//+ (void)setTrashMessageGroup:(GIMessageGroup *)aMessageGroup;

- (NSString *)imageName;
- (BOOL)isDeletable;
- (BOOL)isValidUserCopyOrMoveSourceOrDestination;

+ (void)ensureDefaultGroups;

//- (void)exportAsMboxFileWithPath:(NSString *)path;

- (int)unreadMessageCount;

/*" Inverse relationship handling "*/
- (void) addPrimitiveThreadsObject: (GIThread*) newThread;
- (void) removePrimitiveThreadsObject: (GIThread*) oldThread;

- (NSUInteger) messageCount;
- (NSUInteger) calculatedUnreadMessageCount;

@end
