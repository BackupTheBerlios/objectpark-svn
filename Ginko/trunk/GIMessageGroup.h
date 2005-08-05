//
//  GIMessageGroup.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 02.08.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OPPersistentObject.h"

@class GIProfile;
@class GIThread;

@interface GIMessageGroup : OPPersistentObject {

}

/*" Sent when a new message group was added. %{object} holds the added GIMessageGroup object. "*/
extern NSString *GIMessageGroupWasAddedNotification;


/*" Handling message groups. Class methods. "*/
+ (NSMutableArray *)hierarchyRootNode;
+ (GIMessageGroup *)newMessageGroupWithName:(NSString *)aName
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
+ (GIMessageGroup*) defaultMessageGroup;
+ (GIMessageGroup*) sentMessageGroup;
+ (GIMessageGroup*) queuedMessageGroup;
+ (GIMessageGroup*) draftMessageGroup;
+ (GIMessageGroup*) spamMessageGroup;
+ (GIMessageGroup*) trashMessageGroup;

+ (void) ensureDefaultGroups;

	/*" Simple Accessors "*/
- (NSString*) URIReferenceString;


	/*" Complex Accessors "*/

	//- (NSArray *)threadsByDate;

-  (void) fetchThreadURIs: (NSMutableArray**) uris
           trivialThreads: (NSMutableSet**) trivialThreads
                newerThan: (NSTimeInterval) sinceRefDate
              withSubject: (NSString*) subject
                   author: (NSString*) author
    sortedByDateAscending: (BOOL) ascending;

- (void) addThread: (GIThread*) value;
- (void) removeThread: (GIThread*) value;


	/*" Profile handling "*/
- (GIProfile*) defaultProfile;
- (void) setDefaultProfile:(GIProfile *)aProfile;

	/*" Persistency handling "*/
+ (void) commitChanges;


@end
