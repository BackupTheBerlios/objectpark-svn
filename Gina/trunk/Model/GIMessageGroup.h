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
#import "OPPersistentSet.h"

@class GIProfile;
@class GIThread;

/*" MessageGroup types "*/
#define GIRegularMessageGroup 1
#define GIDefaultMessageGroup 2
#define GIQueuedMessageGroup 3
#define GIDraftMessageGroup 4
#define GISentMessageGroup 5
#define GISpamMessageGroup 6
#define GITrashMessageGroup 7

@interface GIMessageGroup : GIHierarchyNode 
{
	OPPersistentSet *threads;
	OID defaultProfileOID;
	
    // transient stats:
    int unreadMessageCount;
	int type;
}

@property (readonly) NSSet *threads;
@property (readonly) int unreadMessageCount;
@property (readonly) int type;

///*" Sent when a new message group was added. %{object} holds the added GIMessageGroup object. "*/
//extern NSString *GIMessageGroupWasAddedNotification;
//extern NSString *GIMessageGroupsChangedNotification;

- (GIProfile *)defaultProfile;
- (void)setDefaultProfile:(GIProfile *)newProfile;

+ (NSImage *)imageForMessageGroup:(GIMessageGroup *)aMessageGroup;

+ (void)copyThreadsWithURLs:(NSArray *)threadURLs fromGroup:(GIMessageGroup *)sourceGroup toGroup:(GIMessageGroup *)destinationGroup move:(BOOL)move;

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

- (NSString *)imageName;
- (BOOL)isDeletable;
- (BOOL)isValidUserCopyOrMoveSourceOrDestination;

+ (void)ensureDefaultGroups;

//- (void)exportAsMboxFileWithPath:(NSString *)path;

- (int)unreadMessageCount;

/*" Inverse relationship handling "*/
- (void) addPrimitiveThreadsObject: (GIThread*) newThread;
- (void) removePrimitiveThreadsObject: (GIThread*) oldThread;

@end
