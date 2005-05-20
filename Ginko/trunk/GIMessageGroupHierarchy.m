//
//  GIMessageGroupHierarchy.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 12.05.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "GIMessageGroupHierarchy.h"
#import "G3MessageGroup.h"
#import "NSApplication+OPExtensions.h"

@implementation GIMessageGroupHierarchy

+ (GIMessageGroupHierarchy *)hierarchy
{
    static GIMessageGroupHierarchy *hierarchy;
    
    if (! hierarchy)
    {
        hierarchy = [[GIMessageGroupHierarchy alloc] init];
    }
    
    return hierarchy;
}

- (void)checkHierarchy:(NSMutableArray *)hierarchy withGroups:(NSMutableArray *)groupUrlsToCheck
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

- (void)enforceIntegrity
/*" Checks if all groups are in the hierarchy and that the hierarchy has no nonexistent groups in it. "*/
{
    NSMutableArray *groupUrlsToCheck;
    NSArray *allGroups;
    NSEnumerator *enumerator;
    G3MessageGroup *group;
    
    allGroups = [G3MessageGroup allObjects];
    groupUrlsToCheck = [NSMutableArray arrayWithCapacity:[allGroups count]];
    enumerator = [allGroups objectEnumerator];
    
    // building array of Object ID URLs:
    while ((group = [enumerator nextObject]))
    {
        [groupUrlsToCheck addObject:[[[group objectID] URIRepresentation] absoluteString]];
    }
            
    [self checkHierarchy:root withGroups:groupUrlsToCheck];
    
    [root addObjectsFromArray:groupUrlsToCheck];
    
    [self commitChanges];
}

- (id)init
/*" Never called by client code. Use +hierarchy to get the hierarchy. "*/
{
    NSData *plistData;
    NSString *plistPath;
    NSString *error;
    NSPropertyListFormat format;
    
    self = [super init];
    
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
    
    return self;
}

- (NSMutableArray *)root
{
    return root;
}

- (void)commitChanges
{
    NSString *plistPath;
    NSData *plistData;
    NSString *error;
    
    plistPath = [[NSApp applicationSupportPath] stringByAppendingPathComponent:@"Hierarchy.plist"];

    plistData = [NSPropertyListSerialization dataFromPropertyList:root
                                                           format:NSPropertyListXMLFormat_v1_0
                                                 errorDescription:&error];
    if(plistData)
    {
        [plistData writeToFile:plistPath atomically:YES];
    }
    else
    {
        NSLog(error);
        [error release];
    }
}

- (NSMutableArray *)findNodeForEntry:(id)entry inHierarchy:(NSMutableArray *)aHierarchy
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
            result = [self findNodeForEntry:entry inHierarchy:object];
        }
    }
    
    return result;
}

- (BOOL)moveEntry:(id)entry toHierarchy:(NSMutableArray *)aHierarchy atIndex:(int)anIndex testOnly:(BOOL)testOnly
{
    NSMutableArray *entrysHierarchy;
    int entrysIndex;
    
    // find entry's hierarchy and index
    entrysHierarchy = [self findNodeForEntry:entry inHierarchy:root];
    entrysIndex = [entrysHierarchy indexOfObject:entry];
    
    // don't allow folders being moved to subfolders of themselves
    if ([entry isKindOfClass:[NSMutableArray class]])
    {
        if ([entry isEqual:aHierarchy]) return NO;
        if ([entry containsObject:aHierarchy]) return NO;
        if ([self findNodeForEntry:aHierarchy inHierarchy:entry])
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

- (void)addNewNodeAfterItem:(id)item
{
    NSMutableArray *hierarchy = [self findNodeForEntry:item inHierarchy:root];
    NSMutableArray *newHierarchy = [NSMutableArray arrayWithObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
        NSLocalizedString(@"New Folder", @"new messagegroup folder"), @"name",
        [NSNumber numberWithFloat:[NSCalendarDate timeIntervalSinceReferenceDate]], @"uid",
        nil, nil
        ]];
    int index = [hierarchy indexOfObject:item] + 1;
    
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

- (NSMutableArray *)nodeForUid:(NSNumber *)anUid startNode:(NSMutableArray *)aNode
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
            result = [self nodeForUid:anUid startNode:object];
        }
    }
    
    return result;
}

- (NSMutableArray *)nodeForUid:(NSNumber *)anUid
{
    return [self nodeForUid:anUid startNode:root];
}

@end
