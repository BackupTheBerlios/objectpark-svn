//
//  G3MessageGroup.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 03.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "OPManagedObject.h"

/*" Sent when a new message group was added. %{object} holds the added G3MessageGroup object. "*/
extern NSString *GIMessageGroupWasAddedNotification;

@class G3Profile;
@class G3Thread;

@interface G3MessageGroup : NSManagedObject 
{
    NSString *pk;
}

/*" Handling message groups. Class methods. "*/
+ (NSMutableArray *)hierarchyRootNode;
+ (G3MessageGroup *)newMessageGroupWithName:(NSString *)aName
                            atHierarchyNode:(NSMutableArray *)aNode
                                    atIndex:(int)anIndex;
+ (id)messageGroupWithURIReferenceString:(NSString *)anUrl;
+ (void)addNewHierarchyNodeAfterEntry:(id)anEntry;
+ (NSMutableArray *)hierarchyNodeForUid:(NSNumber *)anUid;
+ (BOOL)moveEntry:(id)entry 
  toHierarchyNode:(NSMutableArray *)aHierarchy 
          atIndex:(int)anIndex 
         testOnly:(BOOL)testOnly;
+ (NSMutableArray *)findHierarchyNodeForEntry:(id)entry
                    startingWithHierarchyNode:(NSMutableArray *)aHierarchy;

/*" Standard message groups "*/
+ (G3MessageGroup *)defaultMessageGroup;
+ (G3MessageGroup *)sentMessageGroup;
+ (G3MessageGroup *)queuedMessageGroup;
+ (G3MessageGroup *)draftMessageGroup;
+ (G3MessageGroup *)spamMessageGroup;
+ (G3MessageGroup *)trashMessageGroup;

+ (void) ensureDefaultGroups;

/*" Simple Accessors "*/
- (NSString *)URIReferenceString;

- (NSString *)name;
- (void)setName:(NSString *)value;

/*" Complex Accessors "*/
//- (NSArray *)threadsByDate;

-  (void) fetchThreadURIs: (NSMutableArray**) uris
           trivialThreads: (NSMutableSet**) trivialThreads
                newerThan: (NSTimeInterval) sinceRefDate
              withSubject: (NSString*) subject
                   author: (NSString*) author
    sortedByDateAscending: (BOOL) ascending;

- (void) addThread: (G3Thread*) value;
- (void) removeThread: (G3Thread*) value;


/*" Profile handling "*/
- (G3Profile *)defaultProfile;
- (void)setDefaultProfile:(G3Profile *)aProfile;

/*" Persistency handling "*/
+ (void)commitChanges;

@end