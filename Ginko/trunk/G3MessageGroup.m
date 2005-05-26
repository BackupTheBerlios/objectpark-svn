//
//  G3MessageGroup.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 03.12.04.
//  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "G3MessageGroup.h"
#import "NSManagedObjectContext+Extensions.h"
#import "G3Thread.h"
#import "G3Profile.h"
#import "GIApplication.h"
#import "NSApplication+OPExtensions.h"
#import "GIUserDefaultsKeys.h"

NSString *GIMessageGroupWasAddedNotification = @"GIMessageGroupWasAddedNotification";

@implementation G3MessageGroup
/*" G3MessageGroup is a collection of G3Thread objects (which in turn are a collection of G3Message objects). G3MessageGroup is an entity in the datamodel (see %{Ginko3_DataModel.xcdatamodel} file).

G3MessageGroups are ordered hierarchically. The hierarchy is build by nested NSMutableArrays (e.g. #{+rootHierarchyNode} returns the NSMutableArray that is the root node). The first entry in such a hierarchy node is information of the node itself (it is a NSMutableDictionary whose keys are described lateron). All other entries are either NSStrings with URLs that reference G3MessageGroup objects (see #{-[NSManagedObject objectID]}) or other hierarchy nodes (NSMutableArrays). "*/

- (NSString *)name
/*" Returns the name of the receiver. "*/
{
    [self willAccessValueForKey:@"name"];
    id result = [self primitiveValueForKey:@"name"];
    [self didAccessValueForKey:@"name"];
    return result;
}

- (void)setName:(NSString *)value 
/*" Sets the name of the receiver. "*/
{
    [self willChangeValueForKey:@"name"];
    [self setPrimitiveValue:value forKey:@"name"];
    [self didChangeValueForKey:@"name"];
}

- (NSString *)URIReferenceString
/*" Returns a string for referencing the receiver persistently. "*/ 
{
    [NSApp saveAction:self];
    return [[[self objectID] URIRepresentation] absoluteString];
}

+ (G3MessageGroup *)newMessageGroupWithName:(NSString *)aName atHierarchyNode:(NSMutableArray *)aNode atIndex:(int)anIndex
/*" Returns a new message group with name aName at the hierarchy node aNode on position anIndex. If aName is nil, the default name for new groups is being used. If aNode is nil, the group is being put on the root node at last position (anIndex is ignored in this case). "*/ 
{
    G3MessageGroup *result = nil;
    NSString *resultURLString = nil;
    
    if (!aName)
    {
        aName = NSLocalizedString(@"New Group", @"Default name for new group");
    }
    
    if (!aNode)
    {
        aNode = [self hierarchyRootNode];
        anIndex = [aNode count];
    }
    
    // creating new group and setting name:
    result = [[[self alloc] initWithManagedObjectContext:[NSManagedObjectContext defaultContext]] autorelease];
    [result setName:aName];

    // placing new group in hierarchy:
    NSParameterAssert((anIndex >= 0) && (anIndex <= [aNode count]));
    anIndex += 1; // first position is node info
    resultURLString = [result URIReferenceString];
    
    if (anIndex = [aNode count])
    {
        [aNode addObject:resultURLString];
    }
    else
    {
        [aNode insertObject:resultURLString atIndex:anIndex];
    }
    
    [self commitChanges];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:GIMessageGroupWasAddedNotification object:result];
    
    return result;
}

+ (id)messageGroupWithURIReferenceString:(NSString *)anUrl
/*" Returns the message group object referenced by the given reference string anUrl. See also: #{-URIReferenceString}. "*/
{
    id referencedGroup = nil;
    
    @try {
        referencedGroup = [[NSManagedObjectContext defaultContext] objectWithURI:[NSURL URLWithString:anUrl]];
    }
    @catch (NSException *e)
    {
        NSLog(@"Could not find group for URI ''", anUrl);
    }
        
    return referencedGroup;
    /*
    id result = nil;
    NSEnumerator *e = [[self allObjects] objectEnumerator];
    id group;
    
    while (group = [e nextObject]) 
    {
        if ([[group URIReferenceString] isEqualToString:anUrl]) 
        {
            result = group;
            break;
        }
    }
    
    return result;
     */
}

- (NSArray *)threadsByDate
/*" Returns an ordered list of all message threads of the receiver, ordered by date. "*/
{
    static NSArray *dateDescriptor = nil;
    NSArray *result = nil;
    
    if (! dateDescriptor) dateDescriptor = [[NSArray alloc] initWithObjects:[[[NSSortDescriptor alloc] initWithKey:@"date" ascending:NO] autorelease], nil];
    
#warning ugly hackaround, Dude!
    result = [[self valueForKey:@"threads"] allObjects];
    
    return result;
//    return [[(NSSet *)[self valueForKey:@"threads"] allObjects] sortedArrayUsingDescriptors:dateDescriptor];

    /*
    //	return [[self valueForKey:@"threads"] allObjects];
    
    [NSApp saveAction:self];
    
    NSArray* result = nil;
    NSError* error = nil;
    NSFetchRequest* request = [[[NSFetchRequest alloc] init] autorelease];
    [request setEntity: [G3Thread entity]];
    
    //NSLog(@"All messages for %@: %@", self, [self valueForKey: @"threads"]);
    
    NSPredicate* p = [NSPredicate predicateWithFormat: @"ANY groups.name like %@", [self name]];
    
    [request setPredicate: p];
    
    [request setSortDescriptors: [NSArray arrayWithObject: [[[NSSortDescriptor alloc] initWithKey: @"date" ascending: NO] autorelease]]];
    
    result = [[self managedObjectContext] executeFetchRequest: request error: &error];
    if (error) NSLog(@"Error fetching threads: %@", error);
    
    //#warning for debugging only as it is inefficient
    //NSAssert([result count] == [[self valueForKey:@"threads"] count], @"result != threadsCount");
    
    return result;
    */
}

- (NSString *)description
/*" Custom description of the receiver. "*/
{
    return [NSString stringWithFormat:@"%@ with %d threads", [super description], [[self valueForKey:@"threads"] count]];
}

- (unsigned)messageCount
/*" Returns the count of messages that are present 'in' the receiver (contained in threads that are contained in the receiver). 

    The current implementation is very inefficent, please use seldom. "*/
{
    unsigned result = 0;
    NSEnumerator *enumerator;
    G3Thread *thread;
    
    enumerator = [[self threadsByDate] objectEnumerator];
    while (thread = [enumerator nextObject])
    {
        result += [thread messageCount];
    }
    
    return result;
}

- (unsigned)unreadMessageCount
/*" Not yet implemented. Returns always 0. "*/
{
    return 0;
}

- (G3Profile *)defaultProfile
/*" Returns the default profile to use for replies on messages on this group. 
    Returns nil, if no default profile was specified. "*/
{
#warning implement defaultProfile
    return [[G3Profile allObjects] lastObject];
}

- (void)setDefaultProfile:(G3Profile *)aProfile
/*" Sets the default profile for the receiver. The default profile is used for replies on messages in this group. May set to nil. Then a more global default will be used. "*/
{
#warning implement setDefaultProfile
    
    //[self setPrimitiveValue:[aProfile objectID] forKey:@"defaultProfileId"];
}

static NSMutableArray *root = nil;

+ (void)commitChanges
/*" Saves the hierarchy information to disk. "*/
{
    NSString *plistPath;
    NSData *plistData;
    NSString *error;
    
    plistPath = [[NSApp applicationSupportPath] stringByAppendingPathComponent:@"Hierarchy.plist"];
    
    plistData = [NSPropertyListSerialization dataFromPropertyList:[self hierarchyRootNode] format:NSPropertyListXMLFormat_v1_0 errorDescription:&error];
    if(plistData)
    {
        [plistData writeToFile:plistPath atomically:YES];
    }
    else
    {
        NSLog(error);
        [error release];
    }
    
//    [NSApp saveAction:self];
}

+ (void)checkHierarchy:(NSMutableArray *)hierarchy withGroups:(NSMutableArray *)groupUrlsToCheck
/*" Checks the given hierarchy if all groups (referenced by groupUrlsToCheck) and no more are contained in the hierarchy. Adjusts the hierarchy accordingly. "*/
{
    int i, count;
    
    count = [hierarchy count];
    
    for(i = 1; i < count; i++)
    {
        id object;
        
        object = [hierarchy objectAtIndex:i];
        
        if ([object isKindOfClass:[NSString class]])
        {
            if (! [groupUrlsToCheck containsObject:object])
            {
                // nonexistent group -> remove
                [hierarchy removeObjectAtIndex:i];
                i--;
                count--;
            }
            else
            {
                [groupUrlsToCheck removeObject:object];
            }
        }
        else
        {
            [self checkHierarchy:object withGroups:groupUrlsToCheck];
        }
    }
}

+ (void)enforceIntegrity
/*" Checks if all groups are in the hierarchy and that the hierarchy has no nonexistent groups in it. "*/
{
    NSMutableArray *groupUrlsToCheck;
    NSArray *allGroups;
    NSEnumerator *enumerator;
    G3MessageGroup *group;
    
    allGroups = [self allObjects];
    groupUrlsToCheck = [NSMutableArray arrayWithCapacity:[allGroups count]];
    enumerator = [allGroups objectEnumerator];
    
    // building array of Object ID URLs:
    while ((group = [enumerator nextObject]))
    {
        [groupUrlsToCheck addObject:[group URIReferenceString]];
    }
    
    [self checkHierarchy:[self hierarchyRootNode] withGroups:groupUrlsToCheck];
    
    [[self hierarchyRootNode] addObjectsFromArray:groupUrlsToCheck];
    
    [self commitChanges];
}

+ (NSMutableArray *)hierarchyRootNode
/*" Returns the root node of the message group hierarchy. The first entry in every node describes the hierarchy. It is a #{NSDictionary} with keys 'name' for the name of the hierarchy and 'uid' for an unique id of the hierarchy. "*/
{
    if (! root)
    {
        NSData *plistData;
        NSString *plistPath;
        NSString *error;
        NSPropertyListFormat format;
                
        // read from application support folder:
        plistPath = [[NSApp applicationSupportPath] stringByAppendingPathComponent:@"Hierarchy.plist"];
        
        plistData = [NSData dataWithContentsOfFile:plistPath];
        root = [[NSPropertyListSerialization propertyListFromData:plistData
                                                 mutabilityOption:NSPropertyListMutableContainers
                                                           format:&format
                                                 errorDescription:&error] retain];
        if(!root)
        {
            root = [[NSMutableArray arrayWithObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                @"Root", @"name",
                [NSNumber numberWithFloat:0.0], @"uid",
                nil, nil
                ]] retain];
            
            //NSLog(error);
            [error release];
        }
        
        [self enforceIntegrity];
    }
    
    return root;
}

+ (NSMutableArray *)findHierarchyNodeForEntry:(id)entry startingWithHierarchyNode:(NSMutableArray *)aHierarchy
/*" Returns the hierarchy node in which entry is contained. Starts the search at the hierarchy node aHierarchy. Returns nil if entry couldn't be found in the hierarchy. "*/
{
    NSMutableArray *result = nil;
    NSEnumerator *enumerator;
    id object;
    
    if ([aHierarchy containsObject:entry])
    {
        return aHierarchy;
    }
    
    enumerator = [aHierarchy objectEnumerator];
    while ((! result) && ((object = [enumerator nextObject])))
    {
        if ([object isKindOfClass:[NSMutableArray class]])
        {
            result = [self findHierarchyNodeForEntry:entry startingWithHierarchyNode:object];
        }
    }
    
    return result;
}

+ (BOOL)moveEntry:(id)entry toHierarchyNode:(NSMutableArray *)aHierarchy atIndex:(int)anIndex testOnly:(BOOL)testOnly
/*" Moves entry (either a hierarchy node or a group reference to another hierarchy node aHierarchy at the given index anIndex. If testOnly is YES, it only checks if the move was legal. Returns YES if the move was successful, NO otherwise. "*/
{
    NSMutableArray *entrysHierarchy;
    int entrysIndex;
    
    // find entry's hierarchy and index
    entrysHierarchy = [self findHierarchyNodeForEntry:entry startingWithHierarchyNode:[self hierarchyRootNode]];
    entrysIndex = [entrysHierarchy indexOfObject:entry];
    
    // don't allow folders being moved to subfolders of themselves
    if ([entry isKindOfClass:[NSMutableArray class]])
    {
        if ([entry isEqual:aHierarchy]) return NO;
        if ([entry containsObject:aHierarchy]) return NO;
        if ([self findHierarchyNodeForEntry:aHierarchy startingWithHierarchyNode:entry])
        {
            return NO;
        }
    }
    
    if (! testOnly)
    {
        anIndex += 1; // first entry is the folder name
        
        // is entry's hierarchy equal target hierarchy?
        if (entrysHierarchy == aHierarchy)
        {
            // take care of indexes:
            if (entrysIndex < anIndex) anIndex--;
        }
        
        [entry retain];
        
        [entrysHierarchy removeObject:entry];
        
        if (anIndex < [aHierarchy count])
        {
            [aHierarchy insertObject:entry atIndex:anIndex];
        }
        else
        {
            [aHierarchy addObject:entry];
        }
        
        [entry release];
        
        [self commitChanges];
    }
    
    return YES;
}

+ (void)addNewHierarchyNodeAfterEntry:(id)anEntry
/*" Adds a new hierarchy node below (as visually indicated in the groups list) the given entry anEntry. "*/ 
{
    NSMutableArray *hierarchy = [self findHierarchyNodeForEntry:anEntry startingWithHierarchyNode:[self hierarchyRootNode]];
    NSMutableArray *newHierarchy = [NSMutableArray arrayWithObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
        NSLocalizedString(@"New Folder", @"new messagegroup folder"), @"name",
        [NSNumber numberWithFloat:[NSCalendarDate timeIntervalSinceReferenceDate]], @"uid",
        nil, nil
        ]];
    int index = [hierarchy indexOfObject:anEntry] + 1;
    
    if (index < [hierarchy count])
    {
        [hierarchy insertObject:newHierarchy atIndex:index];
    }
    else
    {
        [hierarchy addObject:newHierarchy];
    }
    
    [self commitChanges];
}

+ (NSMutableArray *)hierarchyNodeForUid:(NSNumber *)anUid startHierarchyNode:(NSMutableArray *)aNode
{
    NSMutableArray *result = nil;
    NSEnumerator *enumerator;
    id object;
    
    if ([[[aNode objectAtIndex:0] valueForKey:@"uid"] isEqual:anUid])
    {
        return aNode;
    }
    
    enumerator = [aNode objectEnumerator];
    [enumerator nextObject]; // skip position 0
    
    while ((! result) && ((object = [enumerator nextObject])))
    {
        if ([object isKindOfClass:[NSMutableArray class]])
        {
            result = [self hierarchyNodeForUid:anUid startHierarchyNode:object];
        }
    }
    
    return result;
}

+ (NSMutableArray *)hierarchyNodeForUid:(NSNumber *)anUid
{
    return [self hierarchyNodeForUid:anUid startHierarchyNode:[self hierarchyRootNode]];
}

+ (G3MessageGroup *)standardMessageGroupWithUserDefaultsKey:(NSString *)defaultsKey defaultName:(NSString *)defaultName
/*" Returns the standard message group (e.g. outgoing group) defined by defaultsKey. If not present, a group is created with the name defaultName and set as this standard group. "*/
{
    NSString *URLString = [[NSUserDefaults standardUserDefaults] stringForKey:defaultsKey];
    G3MessageGroup *result = nil;
        
    if (URLString)
    {
        result = [G3MessageGroup messageGroupWithURIReferenceString:URLString];
    }
    
    if (!result)
    {
        // not found creating new:
        result = [G3MessageGroup newMessageGroupWithName:defaultName atHierarchyNode:nil atIndex:0];
                
        [[NSUserDefaults standardUserDefaults] setObject:[result URIReferenceString] forKey:defaultsKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    return result;
}

+ (G3MessageGroup *)defaultMessageGroup
{
    return [self standardMessageGroupWithUserDefaultsKey:DefaultMessageGroupURLString defaultName:NSLocalizedString(@"Default Inbox", @"default group name for default inbox")];
}

+ (G3MessageGroup *)outgoingMessageGroup
{
    return [self standardMessageGroupWithUserDefaultsKey:OutgoingMessageGroupURLString defaultName:NSLocalizedString(@"Outgoing Messages", @"default group name for outgoing messages")];
}

+ (G3MessageGroup *)draftMessageGroup
{
    return [self standardMessageGroupWithUserDefaultsKey:DraftsMessageGroupURLString defaultName:NSLocalizedString(@"Drafts", @"default group name for drafts")];
}

+ (G3MessageGroup *)spamMessageGroup
{
    return [self standardMessageGroupWithUserDefaultsKey:DraftsMessageGroupURLString defaultName:NSLocalizedString(@"Spam", @"default group name for spam")];
}

@end
