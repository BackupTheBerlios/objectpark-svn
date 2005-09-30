//
//  GIMessageGroup.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 02.08.05.
//  Copyright 2005 Objectpark Group. All rights reserved.
//

#import "GIMessageGroup.h"
#import "NSManagedObjectContext+Extensions.h"
#import "OPManagedObject.h"
#import "GIThread.h"
#import "GIProfile.h"
#import "GIApplication.h"
#import "NSApplication+OPExtensions.h"
#import "GIUserDefaultsKeys.h"
#import "OPPersistentObject+Extensions.h"


@implementation GIMessageGroup

// CREATE TABLE ZMESSAGEGROUP ( Z_ENT INTEGER, Z_PK INTEGER PRIMARY KEY, Z_OPT INTEGER, ZNAME VARCHAR );

+ (NSString*) databaseTableName
{
	return @"ZMESSAGEGROUP";
}

+ (NSString*) persistentAttributesPlist
{
	return 
	@"{"
	@"name = {ColumnName = ZNAME; AttributeClass = NSString;};"
    @"threadsByDate = {AttributeClass = GIThread; QueryString = \"select ZTHREAD.ROWID, ZTHREAD.ZDATE from Z_4THREADS, ZTHREAD where ZTHREAD.ROWID = Z_4THREADS.Z_6THREADS and Z_4THREADS.Z_4GROUPS=? order by ZTHREAD.ZDATE;\"; SortAttribute = date;};"
	// @"threadsByDate = {AttributeClass = GIThread; JoinTableName = Z_4THREADS; SourceKeyColumnName = Z_4GROUPS targetKeyColumnName = Z_6THREADS; SortAttributeName = date};"
	@"}";
}




NSString *GIMessageGroupWasAddedNotification = @"GIMessageGroupWasAddedNotification";

/*" GIMessageGroup is a collection of G3Thread objects (which in turn are a collection of GIMessage objects). GIMessageGroup is an entity in the datamodel (see %{Ginko3_DataModel.xcdatamodel} file).

GIMessageGroups are ordered hierarchically. The hierarchy is build by nested NSMutableArrays (e.g. #{+rootHierarchyNode} returns the NSMutableArray that is the root node). The first entry in such a hierarchy node is information of the node itself (it is a NSMutableDictionary whose keys are described lateron). All other entries are either NSStrings with URLs that reference GIMessageGroup objects (see #{-[NSManagedObject objectID]}) or other hierarchy nodes (NSMutableArrays). "*/

+ (void) ensureDefaultGroups
/*" Makes sure that all default groups are in place. "*/
{
    [self defaultMessageGroup];
    [self sentMessageGroup];
    [self queuedMessageGroup];
    [self draftMessageGroup];
    [self spamMessageGroup];
    [self trashMessageGroup];
}

- (NSString*) URIReferenceString
/*" Returns a string for referencing the receiver persistently. "*/ 
{
    return [[self objectURL] absoluteString];
}

+ (GIMessageGroup *)newMessageGroupWithName:(NSString *)aName atHierarchyNode:(NSMutableArray *)aNode atIndex:(int)anIndex
/*" Returns a new message group with name aName at the hierarchy node aNode on position anIndex. If aName is nil, the default name for new groups is being used. If aNode is nil, the group is being put on the root node at last position (anIndex is ignored in this case). "*/ 
{
    GIMessageGroup *result = nil;
    NSString *resultURLString = nil;
    
    if (!aName) {
        aName = NSLocalizedString(@"New Group", @"Default name for new group");
    }
    
    if (!aNode) {
        aNode = [self hierarchyRootNode];
        anIndex = [aNode count];
    }
    
    // creating new group and setting name:
    result = [[[self alloc] initWithManagedObjectContext:[NSManagedObjectContext threadContext]] autorelease];
    [result setValue: aName forKey: @"name"];

    // placing new group in hierarchy:
    NSParameterAssert((anIndex >= 0) && (anIndex <= [aNode count]));
    anIndex += 1; // first position is node info
    resultURLString = [result URIReferenceString];
    
    if (anIndex = [aNode count]) {
        [aNode addObject: resultURLString];
    } else {
        [aNode insertObject: resultURLString atIndex: anIndex];
    }
    
    [self commitChanges];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:GIMessageGroupWasAddedNotification object:result];
    
    return result;
}

+ (id)messageGroupWithURIReferenceString:(NSString *)anUrl
/*" Returns the message group object referenced by the given reference string anUrl. See also: #{-URIReferenceString}. "*/
{
    id referencedGroup = nil;
    
    NSParameterAssert([anUrl isKindOfClass:[NSString class]]);
    
    if ([anUrl length])
    {
        @try {
            referencedGroup = [[NSManagedObjectContext threadContext] objectWithURI:[NSURL URLWithString:anUrl]];
        }
        @catch (NSException *e) {
            NSLog(@"Could not find group for URI ''", anUrl);
        }
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

- (void) addThread: (GIThread*) thread 
{    
    [thread addToGroups: self];
}

- (void) removeThread: (GIThread*) thread 
{
    [thread removeFromGroups: self];
}

/*
- (NSArray*) threadsByDate
//" Returns an ordered list of all message threads of the receiver, ordered by date. "
{
    static NSArray *dateDescriptor = nil;
    NSArray *result = nil;
    
    NSLog(@"entered threadsByDate");
    if (! dateDescriptor) dateDescriptor = [[NSArray alloc] initWithObjects:[[[NSSortDescriptor alloc] initWithKey:@"date" ascending:NO] autorelease], nil];

    //return [[(NSSet *)[self valueForKey:@"threads"] allObjects] sortedArrayUsingDescriptors:dateDescriptor];

    
    //	return [[self valueForKey:@"threads"] allObjects];
    
//f    [NSApp saveAction:self];
    
//    NSArray* result = nil;
    
    NSError* error = nil;
    NSFetchRequest* request = [[[NSFetchRequest alloc] init] autorelease];
    [request setEntity: [GIThread entity]];
    
    //NSLog(@"All messages for %@: %@", self, [self valueForKey: @"threads"]);
    
   // NSPredicate* p = [NSPredicate predicateWithFormat: @"ANY groups.name like %@", [self name]];
   NSPredicate* p = [NSPredicate predicateWithFormat: @"ANY groups = %@", self];
   //NSPredicate* p = [NSPredicate predicateWithFormat: @"%@ IN groups", self];
    
    [request setPredicate: p];
    
    [request setSortDescriptors: [NSArray arrayWithObject: [[[NSSortDescriptor alloc] initWithKey: @"date" ascending: NO] autorelease]]];
    
    result = [[self context] executeFetchRequest: request error: &error];
    if (error) NSLog(@"Error fetching threads: %@", error);
    
    //#warning for debugging only as it is inefficient
    //NSAssert([result count] == [[self valueForKey:@"threads"] count], @"result != threadsCount");
    NSLog(@"exited threadsByDate");

    return result;
}
*/

/*
- (NSString *)primaryKey
{    
    if (!pk)
    { 
        NSString *URLString = [[[self objectID] URIRepresentation] absoluteString];
        pk = [[[URLString lastPathComponent] substringFromIndex:1] retain];
    }
    
    //NSLog(@"primary key = %@", pk);
    return pk;
}
*/

/*
struct ResultSet {
    NSMutableArray* uris;
    NSMutableSet*   trivialThreads;
};

static int collectThreadURIStringsCallback(void *this, int columns, char **values, char **colnames)
{
    struct ResultSet* result = (struct ResultSet*)this;
    //NSLog(@"%s", values[0]);
    static NSString *prefix = nil; if (!prefix) prefix = [G3Thread URIStringPrefix];
    
    int threadCount = atoi(values[1]);
    NSString* uri = [prefix stringByAppendingString: [NSString stringWithUTF8String:values[0]]];
    
    if (result->uris) {
        // Collect all result uris in order:
        [result->uris addObject: uri];
    }
    if (result->trivialThreads) {
        // build a set of non trivial threads (with messageCount > 1):
        if (threadCount<=1) [result->trivialThreads addObject: uri];
    }
    
    return 0;
}

-  (void) fetchThreadURIs: (NSMutableArray**) uris
           trivialThreads: (NSMutableSet**) trivialThreads
                newerThan: (NSTimeInterval) sinceRefDate
              withSubject: (NSString*) subject
                   author: (NSString*) author
    sortedByDateAscending: (BOOL) ascending
{
    struct ResultSet result;
    result.uris           = uris == NULL           ? NULL : *uris;
    result.trivialThreads = trivialThreads == NULL ? NULL : *trivialThreads;
    
    NSLog(@"entered fetchThreadURIs query");
    [NSManagedObject lockStore];
    
    // open db:
    sqlite3 *db = NULL;
    sqlite3_open([[NSApp databasePath] UTF8String],   // Database filename (UTF-8) 
        &db);                // OUT: SQLite db handle 
    if (db) {
        int errorCode;
        char *error;
        //NSLog(@"DB opened. Fetching thread objects...");        
        
        NSMutableArray* clauses = [NSMutableArray arrayWithObject: @"ZTHREAD.Z_PK = Z_4THREADS.Z_6THREADS"];
        
        // Find only threads belonging to self:
        [clauses addObject: [NSString stringWithFormat: @"%@ = Z_4THREADS.Z_4GROUPS", [self primaryKey]]];
        
        if ([subject length]) {
            [clauses addObject: [NSString stringWithFormat: @"ZTHREAD.ZSUBJECT like '%@'", subject]];
        }
        if ([author length]) {
            [clauses addObject: [NSString stringWithFormat: @"ZTHREAD.ZAUTHOR like '%@'", author]];
        }
        if (sinceRefDate>0.0) {
            [clauses addObject: [NSString stringWithFormat: @"ZTHREAD.ZDATE >= %f", sinceRefDate]];
        }
        
        NSString *queryString = [NSString stringWithFormat: @"select Z_PK, ZNUMBEROFMESSAGES from Z_4THREADS, ZTHREAD where %@ order by ZTHREAD.ZDATE %@;", [clauses componentsJoinedByString: @" and "], ascending ? @"ASC" : @"DESC"];
        
        if (errorCode = sqlite3_exec(db, 
                                     [queryString UTF8String], // SQL to be executed 
                                     collectThreadURIStringsCallback, // Callback function 
                                     &result, // 1st argument to callback function 
                                     &error)) { 
            if (error) 
            {
                NSLog(@"Error creating index: %s", error);
                sqlite3_free(error);
            }
        }
    }
    
    sqlite3_close(db);
    
    [NSManagedObject unlockStore];
    
    NSLog(@"exited fetchThreadURIs query");
}
*/

- (void) dealloc
{
    //[pk release];
    [super dealloc];
}

- (GIProfile*) defaultProfile
/*" Returns the default profile to use for replies on messages on this group. 
    Returns nil, if no default profile was specified. "*/
{
#warning implement defaultProfile
    return [[GIProfile allObjects] lastObject];
}

- (void)setDefaultProfile:(GIProfile *)aProfile
/*" Sets the default profile for the receiver. The default profile is used for replies on messages in this group. May set to nil. Then a more global default will be used. "*/
{
#warning implement setDefaultProfile
    
    //[self setPrimitiveValue:[aProfile objectID] forKey:@"defaultProfileId"];
}

static NSMutableArray *root = nil;

+ (void) commitChanges
/*" Saves the hierarchy information to disk. "*/
{
    NSString *plistPath;
    NSData *plistData;
    NSString *error;
    
    plistPath = [[NSApp applicationSupportPath] stringByAppendingPathComponent:@"Hierarchy.plist"];
    
    plistData = [NSPropertyListSerialization dataFromPropertyList:[self hierarchyRootNode] format:NSPropertyListXMLFormat_v1_0 errorDescription:&error];
    if(plistData) {
        [plistData writeToFile:plistPath atomically:YES];
    } else {
        NSLog(error);
        [error release];
    }
    
//    [NSApp saveAction:self];
}

+ (void) checkHierarchy: (NSMutableArray*) hierarchy withGroups: (NSMutableArray*) groupUrlsToCheck
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
    NSMutableArray* groupUrlsToCheck = [NSMutableArray array];
    NSEnumerator* enumerator = [[self allObjects] objectEnumerator];
	GIMessageGroup *group;

    // building array of Object ID URLs:
    while ((group = [enumerator nextObject])) {
        [groupUrlsToCheck addObject: [group URIReferenceString]];
    }
    
    [self checkHierarchy:[self hierarchyRootNode] withGroups:groupUrlsToCheck];
    
    [[self hierarchyRootNode] addObjectsFromArray: groupUrlsToCheck];
    
    [self commitChanges];
}

+ (NSMutableArray*) hierarchyRootNode
/*" Returns the root node of the message group hierarchy. The first entry in every node describes the hierarchy. It is a #{NSDictionary} with keys 'name' for the name of the hierarchy and 'uid' for an unique id of the hierarchy. "*/
{
    if (! root) {
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

+ (GIMessageGroup *)standardMessageGroupWithUserDefaultsKey:(NSString *)defaultsKey defaultName:(NSString *)defaultName
/*" Returns the standard message group (e.g. outgoing group) defined by defaultsKey. If not present, a group is created with the name defaultName and set as this standard group. "*/
{
    NSParameterAssert(defaultName != nil);
    
    NSString *URLString = [[NSUserDefaults standardUserDefaults] stringForKey:defaultsKey];
    GIMessageGroup *result = nil;
        
    if (URLString)
    {
        result = [GIMessageGroup messageGroupWithURIReferenceString:URLString];
        if (!result) NSLog(@"Couldn't find standard box '%@'", defaultName);
    }
    
    if (!result)
    {
        // not found creating new:
        result = [GIMessageGroup newMessageGroupWithName:defaultName atHierarchyNode:nil atIndex:0];
                
        NSAssert1([result valueForKey: @"name"] != nil, @"group should have a name: %@", defaultName);
        
        [[NSUserDefaults standardUserDefaults] setObject:[result URIReferenceString] forKey:defaultsKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        NSAssert([[[NSUserDefaults standardUserDefaults] stringForKey:defaultsKey] isEqualToString:[result URIReferenceString]], @"Fatal error. User defaults are wrong.");
    }
    
    NSAssert1(result != nil, @"Could not create default message group named '%@'", defaultName);
    
    return result;
}

+ (GIMessageGroup *)defaultMessageGroup
{
    return [self standardMessageGroupWithUserDefaultsKey:DefaultMessageGroupURLString defaultName:NSLocalizedString(@"Default Inbox", @"default group name for default inbox")];
}

+ (GIMessageGroup *)sentMessageGroup
{
    return [self standardMessageGroupWithUserDefaultsKey:SentMessageGroupURLString defaultName:NSLocalizedString(@"Sent Messages", @"default group name for outgoing messages")];
}

+ (GIMessageGroup *)draftMessageGroup
{
    return [self standardMessageGroupWithUserDefaultsKey:DraftsMessageGroupURLString defaultName:NSLocalizedString(@"Draft Messages", @"default group name for drafts")];
}

+ (GIMessageGroup *)queuedMessageGroup
{
    return [self standardMessageGroupWithUserDefaultsKey:QueuedMessageGroupURLString defaultName:NSLocalizedString(@"Queued Messages", @"default group name for queued")];
}

+ (GIMessageGroup *)spamMessageGroup
{
    return [self standardMessageGroupWithUserDefaultsKey:SpamMessageGroupURLString defaultName:NSLocalizedString(@"Spam Messages", @"default group name for spam")];
}

+ (GIMessageGroup *)trashMessageGroup
{
    return [self standardMessageGroupWithUserDefaultsKey:TrashMessageGroupURLString defaultName:NSLocalizedString(@"Trash", @"default group name for trash")];
}



@end
