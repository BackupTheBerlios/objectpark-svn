//
//  GIMessageGroup.m
//  Gina
//
//  Created by Dirk Theisen on 02.08.05.
//  Copyright 2005 Objectpark Group. All rights reserved.
//

#import "GIMessageGroup.h"
#import "GIThread.h"
#import "GIProfile.h"
#import "NSApplication+OPExtensions.h"
#import "GIUserDefaultsKeys.h"
#import "OPFaultingArray.h"
#import "GIMessage.h"
#import "OPInternetMessage.h"
#import "OPMBoxFile.h"
#import "OPFaultingArray.h"
#import "OPPersistence.h"
#import <Foundation/NSDebug.h>

#define MESSAGEGROUP     OPL_DOMAIN  @"MessageGroup"

#define EXPORT_FILE      OPL_ASPECT  0x01
#define EXPORT_PROGRESS  OPL_ASPECT  0x02
#define EXPORT           OPL_ASPECT  (EXPORT_FILE | EXPORT_PROGRESS)
#define STANDARDBOXES    OPL_ASPECT  0x04
#define FINDGROUP        OPL_ASPECT  0x08


@implementation GIMessageGroup

- (GIProfile*) defaultProfile
{
	return [[self context] objectForOID: defaultProfileOID];
}

- (void) setDefaultProfile: (GIProfile*) newProfile
{
	defaultProfileOID = [newProfile oid];
}

+ (BOOL) cachesAllObjects
{
	return YES;
}



NSString *GIMessageGroupWasAddedNotification = @"GIMessageGroupWasAddedNotification";
NSString *GIMessageGroupsChangedNotification = @"GIMessageGroupsChangedNotification";

/*" GIMessageGroup is a collection of GIThread objects (which in turn are a collection of GIMessage objects). GIMessageGroup is an entity in the datamodel (see %{Ginko3_DataModel.xcdatamodel} file).

GIMessageGroups are ordered hierarchically. The hierarchy is build by nested NSMutableArrays (e.g. #{+rootHierarchyNode} returns the NSMutableArray that is the root node). The first entry in such a hierarchy node is information of the node itself (it is a NSMutableDictionary whose keys are described lateron). All other entries are either NSStrings with URLs that reference GIMessageGroup objects (see #{-[NSManagedObject objectID]}) or other hierarchy nodes (NSMutableArrays). "*/

+ (void)ensureDefaultGroups
/*" Makes sure that all default groups are in place. "*/
{
    [self defaultMessageGroup];
    [self sentMessageGroup];
    [self queuedMessageGroup];
    [self draftMessageGroup];
    [self spamMessageGroup];
    [self trashMessageGroup];
}

/*" Returns a new message group with name aName at the hierarchy node aNode on position anIndex. If aName is nil, the default name for new groups is being used. If aNode is nil, the group is being put on the root node at last position (anIndex is ignored in this case). "*/ 
+ (GIMessageGroup*) newMessageGroupWithName: (NSString*) aName atHierarchyNode: (GIHierarchyNode*) aNode atIndex: (int) anIndex
{
    if (!aName) {
        aName = NSLocalizedString(@"New Group", @"Default name for new group");
    }
    
    if (!aNode) {
        aNode = [GIHierarchyNode messageGroupHierarchyRootNode];
    }
	if (anIndex == NSNotFound) anIndex = [[aNode children] count];

    // creating new group and setting name:
    GIMessageGroup* result = [[[self alloc] init] autorelease];
    [result setName: aName];

    // placing new group in hierarchy:
    NSParameterAssert((anIndex >= 0) && (anIndex <= [[aNode children] count]));
    
	NSMutableArray *children = [aNode mutableArrayValueForKey: @"children"];
	
    if (anIndex >= [children count]) {
        [children addObject: result];
    } else {
        [children insertObject: result atIndex: anIndex];
    }

	NSAssert([[aNode children] objectAtIndex: anIndex] == result, @"Message group not inserted.");
	NSAssert([aNode hasUnsavedChanges], @"parent hierarchy node not dirty.");
    
	return result;
}

/*" Returns the message group object referenced by the given reference string anUrl. See also: #{-URIReferenceString}. "*/
//+ (id)messageGroupWithURLString:(NSString *)anUrl
//{
//    id result = nil;
//    
//    NSParameterAssert([anUrl isKindOfClass:[NSString class]]);
//    
//    if ([anUrl length]) 
//	{
//        @try 
//		{
//            result = [[OPPersistentObjectContext defaultContext] objectWithURLString:anUrl];
//			result = [result resolveFault];
//        }
//        @catch (id e) 
//		{
//            if (NSDebugEnabled) NSLog(@"Could not find group for URI ''", anUrl);
//        }
//    }
//    
//    return result;
//}


/*
- (NSArray*) threadsByDate
//" Returns an ordered list of all message threads of the receiver, ordered by date. "
{
    static NSArray*dateDescriptor = nil;
    NSArray*result = nil;
    
    NSLog(@"entered threadsByDate");
    if (! dateDescriptor) dateDescriptor = [[NSArray alloc] initWithObjects:[[[NSSortDescriptor alloc] initWithKey: @"date" ascending: NO] autorelease], nil];

    //return [[(NSSet *)[self valueForKey: @"threads"] allObjects] sortedArrayUsingDescriptors:dateDescriptor];

    
    //	return [[self valueForKey: @"threads"] allObjects];
    
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
    //NSAssert([result count] == [[self valueForKey: @"threads"] count], @"result != threadsCount");
    NSLog(@"exited threadsByDate");

    return result;
}
*/

/*
- (NSString*) primaryKey
{    
    if (!pk)
    { 
        NSString* URLString = [[[self objectID] URIRepresentation] absoluteString];
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
    static NSString* prefix = nil; if (!prefix) prefix = [G3Thread URIStringPrefix];
    
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
        
        NSString* queryString = [NSString stringWithFormat: @"select Z_PK, ZNUMBEROFMESSAGES from Z_4THREADS, ZTHREAD where %@ order by ZTHREAD.ZDATE %@;", [clauses componentsJoinedByString: @" and "], ascending ? @"ASC" : @"DESC"];
        
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
	[threads release];
    [super dealloc];
}



//static NSMutableArray* root = nil;


//+ (void) checkHierarchy: (NSMutableArray*) hierarchy withGroups: (NSMutableArray*) groupUrlsToCheck
///*" Checks the given hierarchy if all groups (referenced by groupUrlsToCheck) and no more are contained in the hierarchy. Adjusts the hierarchy accordingly. "*/
//{
//    int i;
//    int count = [hierarchy count];
//    
//    for(i = 1; i < count; i++) {
//        id object;
//        
//        object = [hierarchy objectAtIndex:i];
//        
//        if ([object isKindOfClass:[NSString class]]) {
//            if (! [groupUrlsToCheck containsObject:object]) {
//                // nonexistent group -> remove
//                [hierarchy removeObjectAtIndex:i];
//                i--;
//                count--;
//            } else {
//                [groupUrlsToCheck removeObject:object];
//            }
//        } else {
//            [self checkHierarchy:object withGroups:groupUrlsToCheck];
//        }
//    }
//}

//+ (void) enforceIntegrity
///*" Checks if all groups are in the hierarchy and that the hierarchy has no nonexistent groups in it. "*/
//{    
//    NSMutableArray* groupUrlsToCheck = [NSMutableArray array];
//    NSEnumerator* enumerator = [[self allObjects] objectEnumerator];
//	GIMessageGroup* group;
//
//    // building array of Object ID URLs:
//    while ((group = [enumerator nextObject])) {
//        [groupUrlsToCheck addObject:[group objectURLString]];
//    }
//    
//    [self checkHierarchy:[self hierarchyRootNode] withGroups: groupUrlsToCheck];
//    
//    [[self hierarchyRootNode] addObjectsFromArray: groupUrlsToCheck];
//    
//    [self saveHierarchy];
//}

//+ (NSMutableArray*) hierarchyRootNode
///*" Returns the root node of the message group hierarchy. The first entry in every node describes the hierarchy. It is a #{NSDictionary} with keys 'name' for the name of the hierarchy and 'uid' for an unique id of the hierarchy. "*/
//{
//    if (! root) 
//    {
//        NSString* error;
//        NSPropertyListFormat format;
//                
//        // Read from application support folder:
//        NSString* plistPath = [[NSApp applicationSupportPath] stringByAppendingPathComponent:@"GroupHierarchy.plist"];
//        
//        NSData *plistData = [NSData dataWithContentsOfFile:plistPath];
//        root = [[NSPropertyListSerialization propertyListFromData:plistData
//                                                 mutabilityOption:NSPropertyListMutableContainers
//                                                           format:&format
//                                                 errorDescription:&error] retain];
//        if (! root) 
//        {
//            root = [[NSMutableArray arrayWithObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
//                @"Root", @"name",
//                [NSNumber numberWithFloat: 0.0], @"uid",
//                nil, nil
//                ]] retain];
//            
//            //NSLog(error);
//            [error release];
//        }
//        
//        [self enforceIntegrity];
//		
//		[[self allObjects] makeObjectsPerformSelector: @selector(retain)]; // Groups are retained to prevent them from being re-fetched every time.
//    }
//    
//    return root;
//}

+ (NSMutableArray*) findHierarchyNodeForEntry: (id) entry startingWithHierarchyNode: (NSMutableArray*) aHierarchy
/*" Returns the hierarchy node in which entry is contained. Starts the search at the hierarchy node aHierarchy. Returns nil if entry couldn't be found in the hierarchy. "*/
{
    NSMutableArray* result = nil;
    
    if ([aHierarchy containsObject: entry]) {
        return aHierarchy;
    }
    
    NSEnumerator* enumerator = [aHierarchy objectEnumerator];
	id object;
    while ((! result) && ((object = [enumerator nextObject]))) {
        if ([object isKindOfClass:[NSMutableArray class]]) {
            result = [self findHierarchyNodeForEntry:entry startingWithHierarchyNode:object];
        }
    }
    return result;
}



//+ (void)removeHierarchyNode:(id)entry
///*" Moves entry (either a hierarchy node or a group reference to another hierarchy node aHierarchy at the given index anIndex. If testOnly is YES, it only checks if the move was legal. Returns YES if the move was successful, NO otherwise. "*/
//{
//    // Find entry's hierarchy and index:
//    NSMutableArray *entrysHierarchy = [self findHierarchyNodeForEntry:entry startingWithHierarchyNode:[self hierarchyRootNode]];    
//	
//	[entrysHierarchy removeObject:entry];
//	
//	if (![entry isKindOfClass:[NSMutableArray class]]) 
//	{
//		[entry release]; // Groups are retained to prevent them from being re-fetched every time.
//	}
//	
//	[self saveHierarchy];
//	
//	[[NSNotificationCenter defaultCenter] postNotificationName:GIMessageGroupsChangedNotification object:self];
//}


//+ (BOOL)moveEntry:(id)entry toHierarchyNode:(NSMutableArray *)aHierarchy atIndex:(int)anIndex testOnly:(BOOL)testOnly
///*" Moves entry (either a hierarchy node or a group reference to another hierarchy node aHierarchy at the given index anIndex. If testOnly is YES, it only checks if the move was legal. Returns YES if the move was successful, NO otherwise. "*/
//{
//    NSMutableArray *entrysHierarchy;
//    int entrysIndex;
//    
//    // find entry's hierarchy and index
//    entrysHierarchy = [self findHierarchyNodeForEntry:entry startingWithHierarchyNode:[self hierarchyRootNode]];
//    entrysIndex = [entrysHierarchy indexOfObject:entry];
//    
//    // don't allow folders being moved to subfolders of themselves
//    if ([entry isKindOfClass:[NSMutableArray class]]) 
//	{
//        if ([entry isEqual:aHierarchy]) return NO;
//        if ([entry containsObject:aHierarchy]) return NO;
//        if ([self findHierarchyNodeForEntry:aHierarchy startingWithHierarchyNode: entry]) {
//            return NO;
//        }
//    }
//    
//    if (! testOnly) 
//	{
//        anIndex += 1; // first entry is the folder name
//        
//        // is entry's hierarchy equal target hierarchy?
//        if (entrysHierarchy == aHierarchy) 
//		{
//            // take care of indexes:
//            if (entrysIndex < anIndex) anIndex--;
//        }
//        
//        [entry retain];
//        
//        [entrysHierarchy removeObject:entry];
//        
//        if (anIndex < [aHierarchy count]) 
//		{
//            [aHierarchy insertObject:entry atIndex:anIndex];
//        } 
//		else 
//		{
//            [aHierarchy addObject:entry];
//        }
//        
//        [entry release];
//        
//        [self saveHierarchy];
//    }
//    
//	[[NSNotificationCenter defaultCenter] postNotificationName:GIMessageGroupsChangedNotification object:self];
//
//    return YES;
//}

- (NSArray *)children
{
	return nil;
}

+ (NSSet *)keyPathsForValuesAffectingThreadChildren
{
	return [NSSet setWithObject:@"threads"];
}


- (NSArray *)threadChildren
{
	return [(OPPersistentSet*)[self threads] sortedArray];
}

- (unsigned) threadChildrenCount
{
	return self.threads.count;
}

- (void) willDelete
{
	// delete dependent objects
	[super willDelete];
}

/*
- (void) willChangeValueForKey: (NSString*) key
{
	//NSLog(@"MessageGroup changes value for key %@", key);
	[super willChangeValueForKey: key];
}
*/



//- (void)exportAsMboxFileWithPath:(NSString *)path
//{
//    if (NSDebugEnabled) NSLo(@"Exporting mbox '%@' to file at %@", [self valueForKey: @"name"], path);
//    OPJob *job = [OPJob job];
//    OPMBoxFile *mbox = [OPMBoxFile mboxWithPath: path createIfNotPresent: YES];
//    
//    [job setProgressInfo:[job indeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"determining messages in group '%@'", @"mbox export, determining messages"), [self valueForKey: @"name"]]]];
//	NSArray *allMessages = [self allMessages];
//    unsigned int messagesToExport = [allMessages count];
//    NSEnumerator *messages = [allMessages objectEnumerator];
//    GIMessage *msg;
//    int exportedMessages = 0;
//    
//    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
//	
//    [job setProgressInfo:[job progressInfoWithMinValue:0 maxValue: messagesToExport currentValue:exportedMessages description:[NSString stringWithFormat:NSLocalizedString(@"exporting '%@'", @"mbox export, exporting"), [self valueForKey:@"name"]]]];
//    while (msg = [messages nextObject]) 
//	{
//        NSData *transferData = [[msg transferData] fromQuote];
//		if (transferData) {
//			NSString* head;
//			head = [NSString stringWithFormat: @"From %@\r\nX-Gina-Flags: %@\r\n",
//				nil, [msg flagsString]];
//#warning Improve From_ line
//			
//			[mbox appendMBoxData: [head dataUsingEncoding: NSISOLatin1StringEncoding]];
//			[mbox appendMBoxData: transferData];
//			[mbox appendMBoxData: [@"\r\n" dataUsingEncoding: NSASCIIStringEncoding]];
//			
//			[msg refault];
//			
//			if (++exportedMessages % 100 == 0) {
//				[job setProgressInfo: [job progressInfoWithMinValue:0 maxValue:messagesToExport currentValue: exportedMessages description: [NSString stringWithFormat: NSLocalizedString(@"exporting '%@'", @"mbox export, exporting"), [self valueForKey: @"name"]]]];
//				if (NSDebugEnabled) NSLog(@"%d messages exported", exportedMessages);
//				
//				if ([job shouldTerminate])
//					break;
//				
//				[pool release]; pool = [[NSAutoreleasePool alloc] init];
//			}
//		}
//    }
//    
//    [pool release];
//    
//    [job setProgressInfo:[job progressInfoWithMinValue:0 maxValue:messagesToExport currentValue:exportedMessages description:[NSString stringWithFormat:NSLocalizedString(@"exporting '%@'", @"mbox export, exporting"), [self valueForKey: @"name"]]]];
//    if (NSDebugEnabled) NSLog(@"%d messages exported", exportedMessages);
//    
//	// [OPJobs setResult:@"ready"];
//}
//

//+ (void) addNewHierarchyNodeAfterEntry:(id)anEntry
///*" Adds a new hierarchy node below (as visually indicated in the groups list) the given entry anEntry. "*/ 
//{
//    NSMutableArray *hierarchy = [self findHierarchyNodeForEntry:anEntry startingWithHierarchyNode:[self hierarchyRootNode]];
//    NSMutableArray *newHierarchy = [NSMutableArray arrayWithObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
//        NSLocalizedString(@"New Folder", @"new messagegroup folder"), @"name",
//        [NSNumber numberWithFloat:[NSCalendarDate timeIntervalSinceReferenceDate]], @"uid",
//        nil, nil
//        ]];
//    int index = [hierarchy indexOfObject:anEntry] + 1;
//    
//    if (index < [hierarchy count]) {
//        [hierarchy insertObject: newHierarchy atIndex: index];
//    } else {
//        [hierarchy addObject: newHierarchy];
//    }
//    
//    [self saveHierarchy];
//}

+ (NSMutableArray*) hierarchyNodeForUid: (NSNumber*) anUid startHierarchyNode: (NSMutableArray*) aNode
{
    NSMutableArray* result = nil;
    NSEnumerator* enumerator;
    id object;
    
    if ([[[aNode objectAtIndex: 0] valueForKey: @"uid"] isEqual: anUid]) {
        return aNode;
    }
    
    enumerator = [aNode objectEnumerator];
    [enumerator nextObject]; // skip position 0
    
    while ((! result) && ((object = [enumerator nextObject]))) {
        if ([object isKindOfClass: [NSMutableArray class]]) {
            result = [self hierarchyNodeForUid: anUid startHierarchyNode: object];
        }
    }
    
    return result;
}

//+ (NSMutableArray *)hierarchyNodeForUid:(NSNumber *)anUid
//{
//    return [self hierarchyNodeForUid:anUid startHierarchyNode:[self hierarchyRootNode]];
//}

+ (void)setStandardMessageGroup:(GIMessageGroup *)aGroup forDefaultsKey:(NSString *)aKey
{
	@synchronized(self)
	{
		[[NSUserDefaults standardUserDefaults] setObject:[aGroup objectURLString] forKey:aKey];
	}
}

/*" Returns the standard message group (e.g. outgoing group) defined by defaultsKey. If not present, a group is created with the name defaultName and set as this standard group. "*/
+ (GIMessageGroup *)standardMessageGroupWithUserDefaultsKey:(NSString *)defaultsKey defaultName:(NSString *)defaultName
{
    NSParameterAssert(defaultName != nil);
	GIMessageGroup *result = nil;
	OPPersistentObjectContext *context = [OPPersistentObjectContext defaultContext];

	@synchronized(self)
	{
		NSString *URLString = [[NSUserDefaults standardUserDefaults] stringForKey:defaultsKey];
        
		if (URLString) 
		{
			result = [context rootObjectForKey:defaultsKey];
			if (!result) if (NSDebugEnabled) NSLog(@"Couldn't find standard box '%@'", defaultName);
		}
		
		if (!result) 
		{
			// not found creating new:
			result = [GIMessageGroup newMessageGroupWithName:defaultName atHierarchyNode:nil atIndex:NSNotFound];
			
			NSAssert1([result name] != nil, @"group should have a name: %@", defaultName);
			
			[context setRootObject:result forKey:defaultsKey];
//			[[NSUserDefaults standardUserDefaults] setObject:[result objectURLString] forKey:defaultsKey];
//			[[NSUserDefaults standardUserDefaults] synchronize];
			
			NSAssert([[[NSUserDefaults standardUserDefaults] stringForKey:defaultsKey] isEqualToString:[result objectURLString]], @"Fatal error. User defaults are wrong.");
			
			if ([defaultsKey isEqualToString:DefaultMessageGroupURLString])
			{
				// generate greeting e-mail in default group:
				NSString *transferDataPath = [[NSBundle mainBundle] pathForResource:@"GreetingMail" ofType:@"transferData"];				
				NSData *transferData = [NSData dataWithContentsOfFile:transferDataPath];				
				OPInternetMessage *internetMessage = [[[OPInternetMessage alloc] initWithTransferData:transferData] autorelease];
				GIMessage *message = [GIMessage messageWithInternetMessage:internetMessage];
				NSAssert(message != nil, @"couldn't create greeting message");
				
				GIThread *thread = [GIThread threadForMessage:message];				
				[[result mutableSetValueForKey:@"threads"] addObject:thread];
			}
			
			[context saveChanges];
		}
		
		NSAssert1(result != nil, @"Could not create default message group named '%@'", defaultName);
    }
	
    return result;
}

+ (GIMessageGroup *)defaultMessageGroup
{
    return [self standardMessageGroupWithUserDefaultsKey:DefaultMessageGroupURLString defaultName:NSLocalizedString(@"Default Inbox", @"default group name for default inbox")];
}

+ (void)setDefaultMessageGroup:(GIMessageGroup *)aMessageGroup
{
	[self setStandardMessageGroup:aMessageGroup forDefaultsKey:DefaultMessageGroupURLString];
}

+ (GIMessageGroup *)sentMessageGroup
{
    return [self standardMessageGroupWithUserDefaultsKey:SentMessageGroupURLString defaultName:NSLocalizedString(@"My Threads", @"default group name for outgoing messages")];
}

+ (void)setSentMessageGroup:(GIMessageGroup *)aMessageGroup
{
	[self setStandardMessageGroup:aMessageGroup forDefaultsKey:SentMessageGroupURLString];
}

+ (GIMessageGroup *)draftMessageGroup
{
    return [self standardMessageGroupWithUserDefaultsKey:DraftsMessageGroupURLString defaultName:NSLocalizedString(@"Draft Messages", @"default group name for drafts")];
}

+ (void)setDraftMessageGroup:(GIMessageGroup *)aMessageGroup
{
	[self setStandardMessageGroup:aMessageGroup forDefaultsKey:DraftsMessageGroupURLString];
}

+ (GIMessageGroup *)queuedMessageGroup
{
    return [self standardMessageGroupWithUserDefaultsKey:QueuedMessageGroupURLString defaultName:NSLocalizedString(@"Queued Messages", @"default group name for queued")];
}

+ (void)setQueuedMessageGroup:(GIMessageGroup *)aMessageGroup
{
	[self setStandardMessageGroup:aMessageGroup forDefaultsKey:QueuedMessageGroupURLString];
}

+ (GIMessageGroup *)spamMessageGroup
{
    return [self standardMessageGroupWithUserDefaultsKey:SpamMessageGroupURLString defaultName:NSLocalizedString(@"Spam", @"default group name for spam")];
}

+ (void)setSpamMessageGroup:(GIMessageGroup *)aMessageGroup
{
	[self setStandardMessageGroup:aMessageGroup forDefaultsKey:SpamMessageGroupURLString];
}

+ (GIMessageGroup *)trashMessageGroup
{
    return [self standardMessageGroupWithUserDefaultsKey:TrashMessageGroupURLString defaultName:NSLocalizedString(@"Trash", @"default group name for trash")];
}

+ (void)setTrashMessageGroup:(GIMessageGroup *)aMessageGroup
{
	[self setStandardMessageGroup:aMessageGroup forDefaultsKey:TrashMessageGroupURLString];
}


- (int) type
/*" Returns the special type of messageGroup (e.g. GIQueuedMessageGroup) or 0 for a regular messageGroup. "*/
{
	int type = [[self valueForKey: @"type"] intValue];
	if (!type) {
		type = GIRegularMessageGroup;
		Class c = [self class];
		if (self == [c defaultMessageGroup]) type = GIDefaultMessageGroup;
		else if (self == [c sentMessageGroup]) type = GISentMessageGroup;
		else if (self == [c queuedMessageGroup]) type = GIQueuedMessageGroup;
		else if (self == [c draftMessageGroup]) type = GIDraftMessageGroup;
		else if (self == [c spamMessageGroup]) type = GISpamMessageGroup;
		else if (self == [c trashMessageGroup]) type = GITrashMessageGroup;
		[self setValue: [NSNumber numberWithInt: type] forKey: @"type"];
	}
	return type;
}

- (NSString *)imageName
{
	static NSString *imageNames[] = {@"OtherMailbox", @"InMailbox", @"ToBeDeliveredMailbox", @"DraftsMailbox", @"OutMailbox", @"JunkMailbox", @"TrashMailbox"};
	return imageNames[MAX(0, [self type] - 1)];
}
 
+ (NSImage*) imageForMessageGroup:(GIMessageGroup *)aMessageGroup
{
    NSString *imageName = [aMessageGroup imageName];    
    return [NSImage imageNamed:imageName];
}



- (BOOL) canHaveChildren
{
	return NO;
}

- (void) willSave
{
	[super willSave];
	if ([[self valueForKey:@"name"] length] == 0) {
		NSLog(@"Pleased supply a name for %@.", self);
	}
}

- (NSSet *)threads
{
	if (!threads) {
		threads = [[OPPersistentSet alloc] init];
		threads.sortKeyPath = @"date";
	}
	return threads;
}

- (int)unreadMessageCount
{
	return unreadMessageCount;
}

- (id) init
{
	if (self = [super init]) {
		
	}
	return self;
}

- (id) initWithCoder: (NSCoder*) coder
{
	if (self = [super initWithCoder: coder]) {
		threads = [coder decodeObjectForKey: @"threads"];
		defaultProfileOID = [coder decodeOIDForKey: @"defaultProfile"];
		unreadMessageCount = [coder decodeIntForKey: @"unreadMessageCount"];
	}
	return self;
}


- (void) adjustUnreadMessageCountBy: (int) changeCount
{
	if (changeCount) {
		NSParameterAssert((int)unreadMessageCount+changeCount >=0);
		[self willChangeValueForKey: @"unreadMessageCount"];
		unreadMessageCount += changeCount;
		[self didChangeValueForKey: @"unreadMessageCount"];
		[self willChangeValueForKey:@"self"];
		[self didChangeValueForKey:@"self"];
	}
}

- (void) addPrimitiveThreadsObject: (GIThread*) newThread
{
	[(OPPersistentSet*)self.threads addObject: newThread];
	[self adjustUnreadMessageCountBy: newThread.unreadMessageCount];
}

- (void) addThreadsObject: (GIThread*) newThread
/*" Sent by the mutableSet proxy. "*/
{
	NSIndexSet* insertSet = [NSIndexSet indexSetWithIndex: newThread.messages.count];
	[self addPrimitiveThreadsObject: newThread];
	// Update the inverse relation:
	[newThread willChange: NSKeyValueChangeInsertion valuesAtIndexes: insertSet forKey: @"messageGroups"];
	[(OPFaultingArray*)newThread.messageGroups addObject: self]; 
	[newThread didChange: NSKeyValueChangeInsertion valuesAtIndexes: insertSet forKey: @"messageGroups"];
}


- (void) removePrimitiveThreadsObject: (GIThread*) oldThread
{
	[(OPPersistentSet*)self.threads removeObject: oldThread];
	[self adjustUnreadMessageCountBy: -oldThread.unreadMessageCount];
}

- (void) removeThreadsObject: (GIThread*) oldThread
/*" Sent by the mutableSet proxy. "*/
{
	NSIndexSet* removeSet = [NSIndexSet indexSetWithIndex: [oldThread.messages indexOfObjectIdenticalTo: self]];
	[self removePrimitiveThreadsObject: oldThread];
	// Update the inverse relation:
	[oldThread willChange: NSKeyValueChangeRemoval valuesAtIndexes: removeSet forKey: @"messageGroups"];
	[(OPFaultingArray*)oldThread removeObject: self];  
	[oldThread didChange: NSKeyValueChangeRemoval valuesAtIndexes: removeSet forKey: @"messageGroups"];
}

- (void) increaseUnreadMessageCount
{
	[self adjustUnreadMessageCountBy: 1];
}

- (void) decreaseUnreadMessageCount
{
	[self adjustUnreadMessageCountBy: -1];
}

- (void) encodeWithCoder: (NSCoder*) coder
{
	[super encodeWithCoder: coder];
	[coder encodeObject: threads forKey: @"threads"];
	[coder encodeOID: defaultProfileOID forKey: @"defaultProfile"];
	[coder encodeInt: unreadMessageCount forKey: @"unreadMessageCount"];
}

- (void) addThreadsByDateObject: (GIThread*) aThread
/*" Should be called by the mutableSetProxy. "*/
{
	[threads addObject: aThread];
	if (! [[aThread messageGroups] containsObject: self]) {
		[[aThread mutableArrayValueForKey: @"messageGroups"] addObject: self];	
	}
}

- (void) removeThreadsByDateObject: (GIThread*) aThread
/*" Should be called by the mutableSetProxy. "*/
{
	[threads removeObject: aThread];
	if ([[aThread messageGroups] containsObject: self]) {
		[[aThread mutableArrayValueForKey: @"messageGroups"] removeObject: self];	
	}
}


@end
