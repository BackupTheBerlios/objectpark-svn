//
//  G3MessageGroup.h
//  GinkoVoyager
//
//  Created by Dirk Theisen on 03.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OPManagedObject.h"

/*" Sent when a new message group was added. %{object} holds the added G3MessageGroup object. "*/
extern NSString *GIMessageGroupWasAddedNotification;

@class G3Profile;

@interface G3MessageGroup : OPManagedObject 
{
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
+ (G3MessageGroup *)outgoingMessageGroup;
+ (G3MessageGroup *)draftMessageGroup;
+ (G3MessageGroup *)spamMessageGroup;

/*" Simple Accessors "*/
- (NSString *)URIReferenceString;

- (NSString *)name;
- (void)setName:(NSString *)value;

/*" Complex Accessors "*/
- (NSArray *)threadsByDate;

- (unsigned)messageCount;
- (unsigned)unreadMessageCount;

/*" Profile handling "*/
- (G3Profile *)defaultProfile;
- (void)setDefaultProfile:(G3Profile *)aProfile;

/*" Persistency handling "*/
+ (void)commitChanges;

@end