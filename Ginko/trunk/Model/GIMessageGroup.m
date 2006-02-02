//
//  GIMessageGroup.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 02.08.05.
//  Copyright 2005 Objectpark Group. All rights reserved.
//

#import "GIMessageGroup.h"
#import "OPPersistentObject+Extensions.h"
#import "OPManagedObject.h"
#import "GIThread.h"
#import "GIProfile.h"
#import "GIApplication.h"
#import "NSApplication+OPExtensions.h"
#import "GIUserDefaultsKeys.h"
#import "OPPersistentObject+Extensions.h"
#import "NSEnumerator+Extensions.h"
#import "OPMBoxFile.h"
#import "GIMessage.h"
#import "NSData+MessageUtils.h"
#import "OPJobs.h"


#define MESSAGEGROUP     OPL_DOMAIN  @"MessageGroup"

#define EXPORT_FILE      OPL_ASPECT  0x01
#define EXPORT_PROGRESS  OPL_ASPECT  0x02
#define EXPORT           OPL_ASPECT  (EXPORT_FILE | EXPORT_PROGRESS)
#define STANDARDBOXES    OPL_ASPECT  0x04
#define FINDGROUP        OPL_ASPECT  0x08


@implementation GIMessageGroup


+ (NSString*) databaseProperties
{
	return 
	@"{"
	@"  TableName = ZMESSAGEGROUP;"
	@"  CacheAllObjects = 1;"
	@"  CreateStatements = (\""
	@"  CREATE TABLE ZMESSAGEGROUP ( Z_ENT INTEGER, Z_PK INTEGER PRIMARY KEY, Z_OPT INTEGER, ZNAME VARCHAR );"
	@"  \",\""
	@"  CREATE TABLE Z_4THREADS ( Z_4GROUPS, Z_6THREADS )"
	@"  \",\""
	@"  CREATE INDEX Z_4THREADS_Z_4GROUPS_INDEX ON Z_4THREADS (Z_4GROUPS)"
	@"  \",\""
	@"  CREATE INDEX Z_4THREADS_Z_6THREADS_INDEX ON Z_4THREADS (Z_6THREADS)"
	@"  \");"
	@""
	@"}";
}

+ (NSString*) persistentAttributesPlist
{
	return 
	@"{"
	@"name = {ColumnName = ZNAME; AttributeClass = NSString;};"
    @"threadsByDate = {AttributeClass = GIThread; QueryString = \"select ZTHREAD.ROWID, ZTHREAD.ZDATE from Z_4THREADS, ZTHREAD where ZTHREAD.ROWID = Z_4THREADS.Z_6THREADS and Z_4THREADS.Z_4GROUPS=? order by ZTHREAD.ZDATE;\"; SortAttribute = date; JoinTableName = Z_4THREADS; SourceColumnName = Z_4GROUPS; TargetColumnName = Z_6THREADS; InverseRelationshipKey=groups;};"
    //@"defaultProfile = {AttributeClass = GIProfile; ColumnName = ZDEFAULTPROFILE; }
	// @"threadsByDate = {AttributeClass = GIThread; JoinTableName = Z_4THREADS; SourceKeyColumnName = Z_4GROUPS targetKeyColumnName = Z_6THREADS; SortAttributeName = date};"
	@"}";
}




NSString* GIMessageGroupWasAddedNotification = @"GIMessageGroupWasAddedNotification";

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


+ (GIMessageGroup *)newMessageGroupWithName: (NSString*) aName atHierarchyNode: (NSMutableArray*) aNode atIndex:(int)anIndex
/*" Returns a new message group with name aName at the hierarchy node aNode on position anIndex. If aName is nil, the default name for new groups is being used. If aNode is nil, the group is being put on the root node at last position (anIndex is ignored in this case). "*/ 
{
    GIMessageGroup *result = nil;
    NSString* resultURLString = nil;
    
    if (!aName) {
        aName = NSLocalizedString(@"New Group", @"Default name for new group");
    }
    
    if (!aNode) {
        aNode = [self hierarchyRootNode];
        anIndex = [aNode count];
    }
    
    // creating new group and setting name:
    result = [[[self alloc] init] autorelease];
	[result insertIntoContext: [OPPersistentObjectContext threadContext]];
    [result setValue: aName forKey: @"name"];

    // placing new group in hierarchy:
    NSParameterAssert((anIndex >= 0) && (anIndex <= [aNode count]));
    anIndex += 1; // first position is node info
    resultURLString = [result objectURLString];
    
    if (anIndex = [aNode count]) {
        [aNode addObject: resultURLString];
    } else {
        [aNode insertObject: resultURLString atIndex: anIndex];
    }
    
    [self saveHierarchy];
	[GIApp saveAction: nil]; // hack
    
    [[NSNotificationCenter defaultCenter] postNotificationName: GIMessageGroupWasAddedNotification object:result];
    
    return result;
}

+ (id) messageGroupWithURIReferenceString: (NSString*) anUrl
/*" Returns the message group object referenced by the given reference string anUrl. See also: #{-URIReferenceString}. "*/
{
    id referencedGroup = nil;
    
    NSParameterAssert([anUrl isKindOfClass:[NSString class]]);
    
    if ([anUrl length]) {
        @try {
            referencedGroup = [[OPPersistentObjectContext threadContext] objectWithURLString: anUrl];
        }
        @catch (NSException* e) {
            OPDebugLog(MESSAGEGROUP, FINDGROUP, @"Could not find group for URI ''", anUrl);
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

/*
- (void) addThread: (GIThread*) thread 
{    
#warning lots of work for Dirk here
    [thread addToGroups: self];
}

- (void) removeThread: (GIThread*) thread 
{
    [thread removeFromGroups: self];
}
*/

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
    [unreadMessageCount release];
    [super dealloc];
}

- (GIProfile*) defaultProfile
/*" Returns the default profile to use for replies on messages on this group. 
    Returns nil, if no default profile was specified. "*/
{	
	[self willAccessValueForKey: @"defaultProfile"];
	id profile = [self primitiveValueForKey: @"defaultProfile"];
	[self didAccessValueForKey: @"defaultProfile"];
	return profile;
}

- (void) setDefaultProfile: (GIProfile*) aProfile
/*" Sets the default profile for the receiver. The default profile is used for replies on messages in this group. May set to nil. Then a more global default will be used. "*/
{
	[self willChangeValueForKey: @"defaultProfile"];
    [self setPrimitiveValue: aProfile forKey: @"defaultProfile"];
	[self willChangeValueForKey: @"defaultProfile"];
}

static NSMutableArray* root = nil;

+ (void) saveHierarchy
/*" Saves the hierarchy information to disk. "*/
{
    NSString* error;
	NSString* plistPath = [[NSApp applicationSupportPath] stringByAppendingPathComponent: @"GroupHierarchy.plist"];
	NSData*   plistData = [NSPropertyListSerialization dataFromPropertyList: [self hierarchyRootNode] format: NSPropertyListXMLFormat_v1_0 errorDescription: &error];
	
    if (plistData) {
        [plistData writeToFile:plistPath atomically: YES];
    } else {
        NSLog(error);
        [error release];
    }
}

+ (void) checkHierarchy: (NSMutableArray*) hierarchy withGroups: (NSMutableArray*) groupUrlsToCheck
/*" Checks the given hierarchy if all groups (referenced by groupUrlsToCheck) and no more are contained in the hierarchy. Adjusts the hierarchy accordingly. "*/
{
    int i;
    int count = [hierarchy count];
    
    for(i = 1; i < count; i++) {
        id object;
        
        object = [hierarchy objectAtIndex:i];
        
        if ([object isKindOfClass:[NSString class]]) {
            if (! [groupUrlsToCheck containsObject:object]) {
                // nonexistent group -> remove
                [hierarchy removeObjectAtIndex:i];
                i--;
                count--;
            } else {
                [groupUrlsToCheck removeObject:object];
            }
        } else {
            [self checkHierarchy:object withGroups:groupUrlsToCheck];
        }
    }
}

+ (void) enforceIntegrity
/*" Checks if all groups are in the hierarchy and that the hierarchy has no nonexistent groups in it. "*/
{    
    NSMutableArray* groupUrlsToCheck = [NSMutableArray array];
    NSEnumerator* enumerator = [[self allObjects] objectEnumerator];
	GIMessageGroup* group;

    // building array of Object ID URLs:
    while ((group = [enumerator nextObject])) {
        [groupUrlsToCheck addObject:[group objectURLString]];
    }
    
    [self checkHierarchy:[self hierarchyRootNode] withGroups: groupUrlsToCheck];
    
    [[self hierarchyRootNode] addObjectsFromArray: groupUrlsToCheck];
    
    [self saveHierarchy];
}

+ (NSMutableArray*) hierarchyRootNode
/*" Returns the root node of the message group hierarchy. The first entry in every node describes the hierarchy. It is a #{NSDictionary} with keys 'name' for the name of the hierarchy and 'uid' for an unique id of the hierarchy. "*/
{
    if (! root) 
    {
        NSString* error;
        NSPropertyListFormat format;
                
        // Read from application support folder:
        NSString* plistPath = [[NSApp applicationSupportPath] stringByAppendingPathComponent:@"GroupHierarchy.plist"];
        
        NSData *plistData = [NSData dataWithContentsOfFile:plistPath];
        root = [[NSPropertyListSerialization propertyListFromData:plistData
                                                 mutabilityOption:NSPropertyListMutableContainers
                                                           format:&format
                                                 errorDescription:&error] retain];
        if (! root) 
        {
            root = [[NSMutableArray arrayWithObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                @"Root", @"name",
                [NSNumber numberWithFloat: 0.0], @"uid",
                nil, nil
                ]] retain];
            
            //NSLog(error);
            [error release];
        }
        
        [self enforceIntegrity];
		
		[[self allObjects] makeObjectsPerformSelector: @selector(retain)]; // Groups are retained to prevent them from being re-fetched every time.
    }
    
    return root;
}

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

+ (void) moveThreadsWithOids: (NSArray*) threadOids 
				   fromGroup: (GIMessageGroup*) sourceGroup 
					 toGroup: (GIMessageGroup*) destinationGroup
{
	if (sourceGroup != destinationGroup) {
		
		NSEnumerator *enumerator = [threadOids objectEnumerator];
		NSNumber *oid;
		
		while (oid = [enumerator nextObject]) {
			GIThread *thread = [[OPPersistentObjectContext threadContext] objectForOid:[oid unsignedLongLongValue] ofClass:[GIThread class]];
			
			// remove thread from source group:
			[thread removeValue:sourceGroup forKey: @"groups"];
			
			// add thread to destination group:
			[thread addValue:destinationGroup forKey: @"groups"];
			
		}
	} else {
		NSLog(@"Warning: Try to move into same group %@", self);
	}
}

+ (void) removeHierarchyNode: (id) entry
	/*" Moves entry (either a hierarchy node or a group reference to another hierarchy node aHierarchy at the given index anIndex. If testOnly is YES, it only checks if the move was legal. Returns YES if the move was successful, NO otherwise. "*/
{
    // Find entry's hierarchy and index:
    NSMutableArray* entrysHierarchy = [self findHierarchyNodeForEntry: entry startingWithHierarchyNode: [self hierarchyRootNode]];    
	
	[entrysHierarchy removeObject: entry];
	
	if (![entry isKindOfClass: [NSMutableArray class]]) {
		[entry release]; // Groups are retained to prevent them from being re-fetched every time.
	}
	
	[self saveHierarchy];
}


+ (BOOL) moveEntry: (id) entry toHierarchyNode: (NSMutableArray*) aHierarchy atIndex: (int) anIndex testOnly: (BOOL) testOnly
/*" Moves entry (either a hierarchy node or a group reference to another hierarchy node aHierarchy at the given index anIndex. If testOnly is YES, it only checks if the move was legal. Returns YES if the move was successful, NO otherwise. "*/
{
    NSMutableArray* entrysHierarchy;
    int entrysIndex;
    
    // find entry's hierarchy and index
    entrysHierarchy = [self findHierarchyNodeForEntry: entry startingWithHierarchyNode: [self hierarchyRootNode]];
    entrysIndex = [entrysHierarchy indexOfObject: entry];
    
    // don't allow folders being moved to subfolders of themselves
    if ([entry isKindOfClass: [NSMutableArray class]]) {
        if ([entry isEqual: aHierarchy]) return NO;
        if ([entry containsObject: aHierarchy]) return NO;
        if ([self findHierarchyNodeForEntry: aHierarchy startingWithHierarchyNode: entry]) {
            return NO;
        }
    }
    
    if (! testOnly) {
        anIndex += 1; // first entry is the folder name
        
        // is entry's hierarchy equal target hierarchy?
        if (entrysHierarchy == aHierarchy) {
            // take care of indexes:
            if (entrysIndex < anIndex) anIndex--;
        }
        
        [entry retain];
        
        [entrysHierarchy removeObject: entry];
        
        if (anIndex < [aHierarchy count]) {
            [aHierarchy insertObject: entry atIndex: anIndex];
        } else {
            [aHierarchy addObject: entry];
        }
        
        [entry release];
        
        [self saveHierarchy];
    }
    
    return YES;
}

- (void) willDelete
{
	// delete dependent objects
	[super willDelete];
}

- (void) willChangeValueForKey: (NSString*) key
{
	//NSLog(@"MessageGroup changes value for key %@", key);
	[super willChangeValueForKey: key];
}


- (NSArray*) allMessages
/*" Only returns persistent messages (from the database). "*/
{
// 	OPPersistentObjectEnumerator* result;

	NSString* queryString = @"select ZMESSAGE.ROWID from Z_4THREADS, ZMESSAGE where ZMESSAGE.ZTHREAD = Z_4THREADS.Z_6THREADS and Z_4THREADS.Z_4GROUPS=?";

#warning needs testing.
	
	return [[self context] fetchObjectsOfClass: [GIMessage class] queryFormat: queryString, self, nil];
	
	// todo: Cache enumerator object
	//result = [[[OPPersistentObjectEnumerator alloc] initWithContext: [self context]
	//													resultClass: [GIMessage class] 
	//													queryString: queryString] autorelease];
	
	//[result bind: self]; // fill "?" above with own oid;
	
	//return result;
}


- (void) exportAsMboxFileWithPath:(NSString*)path
{
    OPDebugLog(MESSAGEGROUP, EXPORT_FILE, @"Exporting mbox '%@' to file at %@", [self valueForKey: @"name"], path);
    
    OPMBoxFile* mbox = [OPMBoxFile mboxWithPath: path createIfNotPresent: YES];
    
    [OPJobs setProgressInfo:[OPJobs indeterminateProgressInfoWithDescription:[NSString stringWithFormat:NSLocalizedString(@"determining messages in group '%@'", @"mbox export, determining messages"), [self valueForKey: @"name"]]]];
	NSArray* allMessages = [self allMessages];
    unsigned int messagesToExport = [allMessages count];
    NSEnumerator* messages = [allMessages objectEnumerator];
    GIMessage* msg;
    int exportedMessages = 0;
    
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
    [OPJobs setProgressInfo:[OPJobs progressInfoWithMinValue:0 maxValue:messagesToExport currentValue:exportedMessages description:[NSString stringWithFormat:NSLocalizedString(@"exporting '%@'", @"mbox export, exporting"), [self valueForKey: @"name"]]]];
    while (msg = [messages nextObject]) {
        
#warning Improve From_ line
        NSString* head = [NSString stringWithFormat:@"From %@\r\n"
                                                    @"X-Ginko-Flags: %@\r\n",
nil, //                                                     [[[NSString alloc] initWithData:[[[msg senderName] dataUsingEncoding:NSISOLatin1StringEncoding] encodeHeaderQuotedPrintable]
//                                                               encoding:NSISOLatin1StringEncoding] autorelease],
                                                    [msg flagsString]
                                                    ];
                                                    
        NSData* transferData = [[msg transferData] fromQuote];
        
        [mbox appendMBoxData:[head dataUsingEncoding:NSISOLatin1StringEncoding]];
        [mbox appendMBoxData:transferData];
        [mbox appendMBoxData:[@"\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
        
        [msg refault];
            
        if (++exportedMessages % 100 == 0) {
            [OPJobs setProgressInfo:[OPJobs progressInfoWithMinValue:0 maxValue:messagesToExport currentValue:exportedMessages description:[NSString stringWithFormat:NSLocalizedString(@"exporting '%@'", @"mbox export, exporting"), [self valueForKey: @"name"]]]];
            OPDebugLog(MESSAGEGROUP, EXPORT_PROGRESS, @"%d messages exported", exportedMessages);
            
            if ([OPJobs shouldTerminate])
                break;
                
            [pool release];
            pool = [[NSAutoreleasePool alloc] init];
        }
    }
    
    [pool release];
    
    [OPJobs setProgressInfo:[OPJobs progressInfoWithMinValue:0 maxValue:messagesToExport currentValue:exportedMessages description:[NSString stringWithFormat:NSLocalizedString(@"exporting '%@'", @"mbox export, exporting"), [self valueForKey: @"name"]]]];
    OPDebugLog(MESSAGEGROUP, EXPORT_PROGRESS, @"%d messages exported", exportedMessages);
    
//     [OPJobs setResult:@"ready"];
}


+ (void) addNewHierarchyNodeAfterEntry:(id)anEntry
/*" Adds a new hierarchy node below (as visually indicated in the groups list) the given entry anEntry. "*/ 
{
    NSMutableArray *hierarchy = [self findHierarchyNodeForEntry:anEntry startingWithHierarchyNode:[self hierarchyRootNode]];
    NSMutableArray *newHierarchy = [NSMutableArray arrayWithObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
        NSLocalizedString(@"New Folder", @"new messagegroup folder"), @"name",
        [NSNumber numberWithFloat:[NSCalendarDate timeIntervalSinceReferenceDate]], @"uid",
        nil, nil
        ]];
    int index = [hierarchy indexOfObject:anEntry] + 1;
    
    if (index < [hierarchy count]) {
        [hierarchy insertObject: newHierarchy atIndex: index];
    } else {
        [hierarchy addObject: newHierarchy];
    }
    
    [self saveHierarchy];
}

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

+ (NSMutableArray*) hierarchyNodeForUid: (NSNumber*) anUid
{
    return [self hierarchyNodeForUid:anUid startHierarchyNode: [self hierarchyRootNode]];
}

+ (GIMessageGroup*) standardMessageGroupWithUserDefaultsKey: (NSString* )defaultsKey defaultName: (NSString*) defaultName
/*" Returns the standard message group (e.g. outgoing group) defined by defaultsKey. If not present, a group is created with the name defaultName and set as this standard group. "*/
{
    NSParameterAssert(defaultName != nil);
    
    NSString* URLString = [[NSUserDefaults standardUserDefaults] stringForKey:defaultsKey];
    GIMessageGroup *result = nil;
        
    if (URLString) {
        result = [GIMessageGroup messageGroupWithURIReferenceString: URLString];
		// Test, if the URL is still valid:
		if (![result resolveFault]) {
			result = nil;
		}
        if (!result)
            OPDebugLog(MESSAGEGROUP, STANDARDBOXES, @"Couldn't find standard box '%@'", defaultName);
    }
    
    if (!result) {
        // not found creating new:
        result = [GIMessageGroup newMessageGroupWithName:defaultName atHierarchyNode: nil atIndex:0];
                
        NSAssert1([result valueForKey: @"name"] != nil, @"group should have a name: %@", defaultName);
        
        [[NSUserDefaults standardUserDefaults] setObject: [result objectURLString] forKey: defaultsKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        NSAssert([[[NSUserDefaults standardUserDefaults] stringForKey: defaultsKey] isEqualToString: [result objectURLString]], @"Fatal error. User defaults are wrong.");
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

+ (NSImage *)imageForMessageGroup:(GIMessageGroup *)aMessageGroup
{
    NSString* imageName = nil;
    
    if (aMessageGroup == [self defaultMessageGroup]) imageName = @"InMailbox";
    else if (aMessageGroup == [self sentMessageGroup]) imageName = @"OutMailbox";
    else if (aMessageGroup == [self queuedMessageGroup]) imageName = @"ToBeDeliveredMailbox";
    else if (aMessageGroup == [self draftMessageGroup]) imageName = @"DraftsMailbox";
    else if (aMessageGroup == [self spamMessageGroup]) imageName = @"JunkMailbox";
    else if (aMessageGroup == [self trashMessageGroup]) imageName = @"TrashMailbox";
    else imageName = @"OtherMailbox";
    
    return [NSImage imageNamed:imageName];
}


-  (NSArray*) fetchThreadsNewerThan: (NSTimeInterval) sinceRefDate
						withSubject: (NSString*) subject
							 author: (NSString*) author
			  sortedByDateAscending: (BOOL) ascending
{    
    NSLog(@"Entered fetchThreads query");
	NSNumber* sinceDate = [NSNumber numberWithFloat: sinceRefDate];
	
	NSMutableArray* clauses = [NSMutableArray arrayWithObject: @"ZTHREAD.Z_PK = Z_4THREADS.Z_6THREADS"];
	
	// Find only threads belonging to self:
	[clauses addObject: @"Z_4THREADS.Z_4GROUPS=$1"];
	
	if ([subject length]) {
		[clauses addObject: [NSString stringWithFormat: @"ZTHREAD.ZSUBJECT like $2", subject]];
	}
	if ([author length]) {
		[clauses addObject: [NSString stringWithFormat: @"ZTHREAD.ZAUTHOR like $3", author]];
	}
	if (sinceRefDate>0.0) {
		[clauses addObject: [NSString stringWithFormat: @"ZTHREAD.ZDATE >= $4", sinceRefDate]];
	}

	
	NSString* queryString = [NSString stringWithFormat: @"select ZTHREAD.ROWID from Z_4THREADS, ZTHREAD where %@ order by ZTHREAD.ZDATE %@;", [clauses componentsJoinedByString: @" and "], ascending ? @"ASC" : @"DESC"];
	
	
	NSLog(@"Entered fetchThreads query with sql: %@", queryString);
	
	return [[self context] fetchObjectsOfClass: [GIThread class]
							   queryFormat: queryString, self, subject, author, sinceDate, nil];
		
}

@end
