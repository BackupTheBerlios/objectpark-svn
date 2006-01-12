//
//  OPersistenceTests.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 24.07.05.
//  Copyright 2005 Dirk Theisen. All rights reserved.
//

#import "TestPersistence.h"
#import "OPPersistence.h"
#import "GIMessage.h"
#import "GIThread.h"
#import "GIMessageGroup.h"
#import "OPFaultingArray.h"

@implementation TestPersistence

- (void) setUp
{
    context = [OPPersistentObjectContext defaultContext];

    if (![context databaseConnection]) {
        
		if (!context) {
			context = [[[OPPersistentObjectContext alloc] init] autorelease];
			[context setDatabaseConnectionFromPath: [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Application Support/GinkoVoyager/MessageBase.sqlite"]];
			[OPPersistentObjectContext setDefaultContext: context];
		}
    }
}

- (void) tearDown
{
    [context reset];
}

- (void) testSimpleFaulting
{
    OID testOid = 2;
    GIMessage* message = [context objectForOid: testOid ofClass: [GIMessage class]];
    NSLog(@"Got message fault: %@", message);
    [message resolveFault];
    NSLog(@"Got message: %@", message);
	NSAssert(![message isFault], @"Faulting did not work for oid 2.");
	[[message valueForKey: @"sendProfile"] resolveFault]; // make sure we do not print a profile fault below
	NSLog(@"Message has profile: %@", [message valueForKey: @"sendProfile"]);
}

- (void) testInsert
{
    GIMessage* newMessage = [[GIMessage alloc] init];
	
	[newMessage setValue: [NSDate date] forKey: @"date"];
	[newMessage setValue: @"BlaBla" forKey: @"subject"];
	[newMessage setValue: @"Ernst Schwallkopf <ernst@schwallkopf.net>" forKey: @"senderName"];
	[newMessage insertIntoContext: context];
	NSAssert([[newMessage valueForKey: @"subject"] isEqualToString: @"BlaBla"], @"Inserted object value not set.");

	[context saveChanges];
	
	NSAssert1([newMessage currentOid], @"No oid was assigned during -saveChanges for %@", newMessage);
	
	NSAssert([[newMessage valueForKey: @"subject"] isEqualToString: @"BlaBla"], @"Inserted object value not set.");
	
	[newMessage revert];
	
	NSAssert([[newMessage valueForKey: @"subject"] isEqualToString: @"BlaBla"], @"Unable to retrieve inserted object value.");
	
}

- (void) testOidGeneration
{
    GIMessage* newMessage = [[GIMessage alloc] init];
	
	[newMessage setValue: @"BlaBla" forKey: @"subject"];
	[newMessage setValue: @"Ernst Schwallkopf <ernst@schwallkopf.net>" forKey: @"senderName"];
	
	// This inserts the object into the database:
	NSAssert1([newMessage oid], @"No oid was assigned during -saveChanges for %@", newMessage);
	
	NSLog(@"New message object created: %@", newMessage);	
	
}


- (void) testSimpleDelete
{
    GIMessage* newMessage = [[GIMessage alloc] init];
	
	[newMessage setValue: @"Re: Re: Schwall" forKey: @"subject"];
	[newMessage setValue: @"Ernst Schwallinger <ernst@schwallkopf.net>" forKey: @"senderName"];
	
	[context saveChanges];
	
	OID oid = [newMessage oid];
	
	[context reset];
	
	newMessage = [context objectForOid: oid ofClass: [GIMessage class]];
	
	NSAssert(newMessage, @"New message not retrievable.");
	
	[newMessage delete];
	
	NSAssert([newMessage isDeleted], @"Deleted message not marked deleted.");
	
	[context saveChanges];
	[context reset];
	
	newMessage = [context objectForOid: oid ofClass: [GIMessage class]];
	
	NSAssert1(![newMessage resolveFault], @"deleted object still accessible from the database: %@", newMessage);
	
}

- (void) testDeleteNullify
{
	
	// Creation:
    GIMessage* newMessage = [[GIMessage alloc] init];
	GIThread* aThread = [context objectForOid: 1 ofClass: [GIThread class]];
	
	[newMessage setValue: @"Re: Re: Schwall" forKey: @"subject"];
	[newMessage setValue: @"Ernst Schwallinger <ernst@schwallkopf.net>" forKey: @"senderName"];
	[newMessage setValue: aThread forKey: @"thread"];
	
	[context saveChanges];
	
	OID oid = [newMessage oid];
	
	[context reset];
	
	// Deletion
	newMessage = [context objectForOid: oid ofClass: [GIMessage class]];
	aThread = [context objectForOid: 1 ofClass: [GIThread class]];
	unsigned messageCount = [[aThread valueForKey: @"messages"] count];
	
	NSAssert(newMessage, @"New message not retrievable.");
	
	[newMessage delete];
	
	NSAssert([newMessage isDeleted], @"Deleted message not marked deleted.");
	
	[context saveChanges];
	
	

	NSAssert1([[aThread valueForKey: @"messages"] count] == messageCount-1, @"Relationship 'messages' not nullified: ", [aThread valueForKey: @"messages"]);
	
	
	[context reset];
	
	newMessage = [context objectForOid: oid ofClass: [GIMessage class]];
	
	NSAssert1(![newMessage resolveFault], @"deleted object still accessible from the database: %@", newMessage);
	
}

/*
- (void) testManualFetch
{	
	// Insert an object, so we are sure it's there:
	NSString* messageId = [[NSDate date] description]; // just a unique string for testing
	
	GIMessage* newMessage = [[GIMessage alloc] init];
	
	[newMessage setValue: @"Re: Re: Schwall" forKey: @"subject"];
	[newMessage setValue: @"Ernst Schwallinger <ernst@schwallkopf.net>" forKey: @"senderName"];
	[newMessage setValue: messageId forKey: @"messageId"];
	[newMessage insertIntoContext: context];
	
	[context saveChanges];
	
	
	OPPersistentObjectEnumerator* enumerator = [context objectEnumeratorForClass: [GIMessage class] where: @"ZMESSAGEID=?"];
	
	[enumerator reset]; // optional
	[enumerator bind: messageId, nil]; // only necessary for requests containing question mark placeholders
	
	id result = [enumerator nextObject];	
	
	NSAssert(newMessage == result, @"Fetch did not return identical object.");
	
}
*/


- (void) testDataPersistence
{
	char bytes[256];
	int i;
	for (i=0;i<256;i++) bytes[i] = i % 32;
	
	NSData* writeData = [NSData dataWithBytes: bytes length: 255];
	
	GIProfile* testProfile = [[[GIProfile alloc] init] autorelease];
	[testProfile setValue: @"TestProfileName" forKey: @"name"];
	[testProfile insertIntoContext: context];
	[testProfile setValue: writeData forKey: @"messageTemplate"];
	//OID oid = [testProfile oid];
	[context saveChanges];
	// testProfile should be released
	
	[testProfile revert];
	//testProfile = [context objectForOid: oid ofClass: [GIProfile class]];
	
	NSData* readData = [testProfile valueForKey: @"messageTemplate"];
	
	NSAssert([writeData isEqual: readData], @"NSData write-reread failed.");
}

- (void) testAttributedStringPersistence
{	
	NSAttributedString* writeData = [[[NSAttributedString alloc] initWithString: @"This is an Attributed Test\nString\n."] autorelease];
	
	GIProfile* testProfile = [[[GIProfile alloc] init] autorelease];
	[testProfile setValue: @"TestProfileName" forKey: @"name"];
	[testProfile insertIntoContext: context];
	[testProfile setValue: writeData forKey: @"signature"];
	//OID oid = [testProfile oid];
	[context saveChanges];
	// testProfile should be released
	
	[testProfile revert];
	//testProfile = [context objectForOid: oid ofClass: [GIProfile class]];
	
	NSAttributedString* readData = [testProfile valueForKey: @"signature"];
	
	NSAssert([[writeData string] isEqualToString: [readData string]], @"NSAttributedString write-reread failed.");
}


- (void) notestManualUpdate
{
	[[context databaseConnection] beginTransaction];
	//OPSQLiteStatement* statement = [[[OPSQLiteStatement alloc] initWithSQL: @"update ZPROFILE set ZENABLED=1 where ROWID=1;" connection: [context databaseConnection]] autorelease];
	//[statement execute];
	
	[[context databaseConnection] performCommand: @"update ZPROFILE set ZENABLED=1 where ROWID=1;"];
	[[context databaseConnection] commitTransaction];
}

/*
- (void) testManualFetch2
{	

	OPPersistentObjectEnumerator* enumerator = [context objectEnumeratorForClass: [GIMessage class] where: @"ZMESSAGEID like ?"];
	
	[enumerator reset]; // optional
	[enumerator bind: @"%2005%", nil]; // only necessary for requests containing question mark placeholders
	
	NSArray* results = [enumerator allObjects];
	
	NSAssert([results count]>0, @"No results for query for messageID containing '2005'.");
	
}
*/

- (void) testGettingAllObjects
{
	NSArray* allThreads = [context objectsForClass: [GIMessageGroup class] whereFormat: nil, nil];
	
	NSLog(@"Got %d thread faults.", [allThreads count]);
	
	NSAssert([allThreads count]>0, @"Problem getting allThread faults at once");
}

- (void) testGroupsRelationshipRead
{
	GIMessage* message = [context objectForOid: 2 ofClass: [GIMessage class]];
	GIThread* thread = [message valueForKey: @"thread"];
	
	OPFaultingArray* groups = [thread valueForKey: @"groups"];
	NSLog(@"Thread %@ is contained in %d group(s) (e.g. %@)", thread, [groups count], [[groups lastObject] valueForKey: @"name"]);
	NSAssert([groups count], @"Thread has no groups!");
	
	NSArray* messages = [thread valueForKey: @"messages"];
	
	NSAssert([messages containsObject: message], @"1:n inverse relationship did not work.");
	
	NSLog(@"Messages in thread for message (oid 2): %@", messages);	
}

- (void) testGroupsRelationshipWrite
{
	GIMessage* message = [context objectForOid: 2 ofClass: [GIMessage class]];
	GIThread* thread = [message valueForKey: @"thread"];
	
	OPFaultingArray* groups = [thread valueForKey: @"groups"];
	NSLog(@"Thread %@ is contained in %d group(s) (e.g. %@)", thread, [groups count], [[groups lastObject] valueForKey: @"name"]);
	int groupCount = [groups count];
	
	GIMessageGroup* additionalGroup = [context objectForOid: 4 ofClass: [GIMessageGroup class]];
	
	NSAssert(![groups containsObject: additionalGroup], @"Bad test data.");
	
	[thread addValue: additionalGroup forKey: @"groups"];
	
	groups = [thread valueForKey: @"groups"];
	
	NSAssert([groups count] == groupCount+1, @"relationship addition failed.");
		
	[thread removeValue: additionalGroup forKey: @"groups"];

	NSAssert([groups count] == groupCount, @"relationship removal failed.");

}


- (void) testThreadInverseRelationship
{
	GIMessageGroup* group = [context objectForOid: 2 ofClass: [GIMessageGroup class]];
	NSAssert(group, @"Unable to fetch group 0.");
	OPFaultingArray* threads = [group valueForKey: @"threadsByDate"];
	GIThread* someThread = [threads lastObject];
	GIThread* otherThread = [threads objectAtIndex: 0];
	GIMessage* someMessage = [[someThread valueForKey: @"messages"] lastObject];
	NSAssert(someThread!=otherThread, @"Bad test setup");

	[someMessage setValue: otherThread forKey: @"thread"];
	
	NSAssert(![[someThread messages] containsObject: someMessage], @"someMessage not removed from [someThreads messages].");
	NSAssert([[otherThread messages] containsObject: someMessage], @"someMessage not inserted into [otherThreads messages].");
}


- (void) testThreadsRelationship
{
	GIMessageGroup* group = [context objectForOid: 2 ofClass: [GIMessageGroup class]];
	NSAssert(group, @"Unable to fetch group 0.");
	
	OPFaultingArray* threads = [group valueForKey: @"threadsByDate"];
	
	GIThread* someThread = [threads lastObject];
	[someThread valueForKey: @"subject"]; // fire fault
	
	NSLog(@"Got threadsByDate: %@, e.g. %@", threads, someThread);

	NSAssert1([threads count]>0, @"Unable to fetch threads for group %@.", group);

}

- (void) testFaultingArray
{
	NSArray* allGroups = [context objectsForClass: [GIMessageGroup class] whereFormat: nil, nil];
	OPFaultingArray* testArray = [OPFaultingArray array];
	
	[testArray addObject: [allGroups objectAtIndex: 0]];
	[testArray addObject: [allGroups objectAtIndex: 1]];
	NSAssert([testArray count] == 2, @"add-problem with OPFaultingArray.");
	NSAssert([testArray objectAtIndex: 0]==[allGroups objectAtIndex: 0], @"Add/Retrieve problem with OPFaultingArray.");
	
	unsigned index1 = [testArray indexOfObject: [allGroups objectAtIndex: 1]];
	unsigned index0 = [testArray indexOfObject: [allGroups objectAtIndex: 0]];
	
	NSAssert(index1!=NSNotFound, @"Unable to find added object in test array.");
	NSAssert(index0!=NSNotFound, @"Unable to find added object in test array.");
	NSAssert(index0!=index1, @"Inconsistent indexes for added objects.");
	
	[testArray removeObject: [allGroups objectAtIndex: 0]];

	NSAssert([testArray count] == 1, @"remove-problem with OPFaultingArray.");
	NSAssert([testArray objectAtIndex: 0] == [allGroups objectAtIndex: 1], @"remove-problem with OPFaultingArray.");
	
}

@end
