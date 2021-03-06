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

@implementation TestPersistence

- (void) setUp
{
    context = [OPPersistentObjectContext defaultContext];

    if (![context databaseConnection]) {
        
        [context setDatabaseConnectionFromPath: [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Application Support/GinkoVoyager/GinkoBase.sqlite"]];

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
	[[message valueForKey: @"profile"] resolveFault]; // make sure we do not print a profile fault below
	NSLog(@"Message has profile: %@", [message valueForKey: @"profile"]);
}

- (void) testInsert
{
    GIMessage* newMessage = [[GIMessage alloc] init];
	
	[newMessage setValue: [NSDate date] forKey: @"date"];
	[newMessage setValue: @"BlaBla" forKey: @"subject"];
	[newMessage setValue: @"Ernst Schwallkopf <ernst@schwallkopf.net>" forKey: @"author"];
	
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
	[newMessage setValue: @"Ernst Schwallkopf <ernst@schwallkopf.net>" forKey: @"author"];
	
	// This inserts the object into the database:
	NSAssert1([newMessage oid], @"No oid was assigned during -saveChanges for %@", newMessage);
	
	NSLog(@"New message object created: %@", newMessage);	
	
}


- (void) testDelete
{
    GIMessage* newMessage = [[GIMessage alloc] init];
	
	[newMessage setValue: @"Re: Re: Schwall" forKey: @"subject"];
	[newMessage setValue: @"Ernst Schwallinger <ernst@schwallkopf.net>" forKey: @"author"];
	
	[context saveChanges];
	
	OID oid = [newMessage oid];
	
	[context reset];
	
	newMessage = [context objectForOid: oid ofClass: [GIMessage class]];
	
	[context deleteObject: newMessage];
	
	NSAssert([newMessage isDeleted], @"Deleted message not marked deleted.");
	
	[context saveChanges];
	[context reset];
	
	newMessage = [context objectForOid: oid ofClass: [GIMessage class]];
	
	NSAssert1(![newMessage resolveFault], @"deleted object still accessible from the database: %@", newMessage);
	
}

- (void) testManualFetch
{	
	// Insert an object, so we are sure it's there:
	NSString* messageId = [[NSDate date] description]; // just a unique string for testing
	
	GIMessage* newMessage = [[GIMessage alloc] init];
	
	[newMessage setValue: @"Re: Re: Schwall" forKey: @"subject"];
	[newMessage setValue: @"Ernst Schwallinger <ernst@schwallkopf.net>" forKey: @"author"];
	[newMessage setValue: messageId forKey: @"messageId"];
	
	[context saveChanges];
	
	
	OPPersistentObjectEnumerator* enumerator = [context objectEnumeratorForClass: [GIMessage class] where: @"ZMESSAGEID=?"];
	
	[enumerator reset]; // optional
	[enumerator bind: messageId, nil]; // only necessary for requests containing question mark placeholders
	
	id result = [enumerator nextObject];	
	
	NSAssert(newMessage == result, @"Fetch did not return identical object.");
	
}


- (void) testManualFetch2
{	

	OPPersistentObjectEnumerator* enumerator = [context objectEnumeratorForClass: [GIMessage class] where: @"ZMESSAGEID like ?"];
	
	[enumerator reset]; // optional
	[enumerator bind: @"%2005%", nil]; // only necessary for requests containing question mark placeholders
	
	NSArray* results = [enumerator allObjects];
	
	NSAssert([results count]>0, @"No results for query for messageID containing '2005'.");
	
}

- (void) testGettingAllObjects
{
	NSArray* allThreads = [[context objectEnumeratorForClass: [GIMessageGroup class] where: nil] allObjects];
	
	NSLog(@"Got %d thread faults.", [allThreads count]);
	
	NSAssert([allThreads count]>0, @"Problem getting allThread faults at once");
}

- (void) testGroupsRelationshipRead
{
	GIMessage* message = [context objectForOid: 2 ofClass: [GIMessage class]];
	GIThread* thread = [message valueForKey: @"thread"];
	
	NSArray* groups = [thread valueForKey: @"groups"];
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
	
	NSArray* groups = [thread valueForKey: @"groups"];
	NSLog(@"Thread %@ is contained in %d group(s) (e.g. %@)", thread, [groups count], [[groups lastObject] valueForKey: @"name"]);
	int groupCount = [groups count];
	
	GIMessageGroup* additionalGroup = [context objectForOid: 4 ofClass: [GIMessageGroup class]];
	
	NSAssert(![groups containsObject: additionalGroup], @"Bad test data.");
	
	[thread addToGroups: additionalGroup];
	
	groups = [thread valueForKey: @"groups"];
	
	NSAssert([groups count] == groupCount+1, @"relationship addition failed.");
		
	[thread removeFromGroups: additionalGroup];

	NSAssert([groups count] == groupCount, @"relationship removal failed.");

}


- (void) testThreadsRelationship
{
	// Test, if we can attach a single attribute (date) to the GIThread faults: 
	GIMessageGroup* group = [context objectForOid: 1 ofClass: [GIMessageGroup class]];
	NSAssert(group, @"Unable to fetch group 0.");
	
	NSArray* threads = [group valueForKey: @"threadsByDate"];
	
	GIThread* someThread = [threads lastObject];
	
	NSAssert1([threads count]>0, @"Unable to fetch threads for group %@.", group);

}

@end
