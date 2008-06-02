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

- (GIProfile *)defaultProfile
{
	return [self.objectContext objectForOID: defaultProfileOID];
}

- (void)setDefaultProfile:(GIProfile *)newProfile
{
	[self willChangeValueForKey:@"defaultProfile"];
	defaultProfileOID = [newProfile oid];
	[self didChangeValueForKey:@"defaultProfile"];
}

+ (BOOL)cachesAllObjects
{
	return YES;
}

/*" GIMessageGroup is a collection of GIThread objects (which in turn are a collection of GIMessage objects). GIMessageGroups are ordered hierarchically. "*/

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

- (void) dealloc
{
	[threads release];
    [super dealloc];
}

- (NSString *)description
{
	return [NSString stringWithFormat: @"%@ #unread=%u", [super description], unreadMessageCount];
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

- (NSArray*) children
{
	return nil;
}

+ (NSSet *)keyPathsForValuesAffectingThreadChildren
{
	return [NSSet setWithObject:@"threads"];
}

- (NSArray *)threadChildren
{
	return [(OPLargePersistentSet*)[self threads] sortedArray];
}

- (unsigned) threadChildrenCount
{
	return self.threads.count;
}

- (NSUInteger) messageCount
{
	NSUInteger result = 0;
	for (GIThread* thread in self.threads) {
		result += thread.messages.count;
	}
	return result;
}

//- (NSUInteger) calculatedUnreadMessageCount
///*" debug only "*/
//{
//	NSUInteger result = 0;
//	for (GIThread* thread in self.threads) {
//		result += thread.unreadMessageCount;
//	}
//	return result;
//}
//
//- (NSUInteger) calculatedUnreadMessageCount2
///*" debug only "*/
//{
//	NSUInteger result = 0;
//	
//	for (GIThread* thread in self.threads) {
//		for (GIMessage* message in thread.messages) {
//			if (! [message isSeen]) {
//				result += 1;
//			}
//		}
//	}
//	return result;
//}
//
//- (NSUInteger) calculatedMessageCount
///*" debug only "*/
//{
//	NSUInteger result = 0;
//	
//	for (GIThread* thread in self.threads) {
//		for (GIMessage* message in thread.messages) {
//				result += 1;
//		}
//	}
//	return result;
//}

- (void)willDelete
{
	[super willDelete]; // removes itself from the node hierarchy

	OPPersistentObjectContext *theContext = self.objectContext;
	// Delete dependent objects:
	GIThread *thread;
	NSMutableSet *mutableThreads = [self mutableSetValueForKey:@"threads"];

	// Remove all threads from the receiver:
	while (thread = mutableThreads.anyObject) 
	{
		[mutableThreads removeObject:thread];
		// Delete thread, if contained in no other group:
		if (! thread.messageGroups.count) 
		{
			[theContext deleteObject:thread];
		} 
	}
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

+ (void)copyThreadsWithURLs:(NSArray *)threadURLs fromGroup:(GIMessageGroup *)sourceGroup toGroup:(GIMessageGroup *)destinationGroup move:(BOOL)move
{
	NSParameterAssert([sourceGroup isValidUserCopyOrMoveSourceOrDestination] || !move);
	NSParameterAssert([destinationGroup isValidUserCopyOrMoveSourceOrDestination]);
		
	if (sourceGroup != destinationGroup) 
	{		
		for (NSString *threadURL in threadURLs)
		{
			GIThread *thread = [[OPPersistentObjectContext defaultContext] objectWithURLString:threadURL];
			NSMutableSet *messageGroups = [thread mutableSetValueForKey:@"messageGroups"];
			
			if (move) {
				[messageGroups removeObject:sourceGroup];
			}			
			[messageGroups addObject:destinationGroup];
		}
	} 
	else 
	{
		NSLog(@"Warning: Try to move into same group %@", sourceGroup);
	}
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

+ (id) newWithName:(NSString *)aName type: (int) groupType atHierarchyNode:(GIHierarchyNode *)aNode atIndex:(int)anIndex
{
	GIMessageGroup* result = [self newWithName: aName atHierarchyNode: aNode atIndex: anIndex];
	result->type = groupType;
	return result;
}

/*" Returns the standard message group (e.g. outgoing group) defined by defaultsKey. If not present, a group is created with the name defaultName and set as this standard group. "*/
+ (GIMessageGroup *)standardMessageGroupWithType: (int) groupType defaultName: (NSString*) defaultName
{
    NSParameterAssert(defaultName != nil);
	defaultName = NSLocalizedString(defaultName, @"");
	GIMessageGroup *result = nil;
	OPPersistentObjectContext *context = [OPPersistentObjectContext defaultContext];

	@synchronized(self) {
		for (id node in [context allObjectsOfClass: [GIMessageGroup class]]) {
			if ([(GIMessageGroup*)node type] == groupType) {
				return node;
			}
		}
		
		// result = [context rootObjectForKey:defaultsKey];
		if (!result) if (NSDebugEnabled) NSLog(@"Couldn't find standard box '%@'", defaultName);
		
		if (!result) {
			// Group not found - create a new one:
			result = [GIMessageGroup newWithName: defaultName type: groupType 
								 atHierarchyNode: nil atIndex: NSNotFound];
			
			NSAssert1([result name] != nil, @"group should have a name: %@", defaultName);
			
			[context insertObject: result];
			
			if (groupType == GIDefaultMessageGroup) {
				// generate greeting e-mail in default group:
				NSString *transferDataPath = [[NSBundle mainBundle] pathForResource:@"GreetingMail" ofType:@"transferData"];				
				NSData *transferData = [NSData dataWithContentsOfFile:transferDataPath];				
				OPInternetMessage *internetMessage = [[[OPInternetMessage alloc] initWithTransferData:transferData] autorelease];
				GIMessage *message = [GIMessage messageWithInternetMessage:internetMessage appendToAppropriateThread:NO];
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
    return [self standardMessageGroupWithType: GIDefaultMessageGroup defaultName: @"Default"];
}

//+ (void)setDefaultMessageGroup:(GIMessageGroup *)aMessageGroup
//{
//	[self setStandardMessageGroup:aMessageGroup forDefaultsKey:DefaultMessageGroupURLString];
//}

+ (GIMessageGroup *)sentMessageGroup
{
    return [self standardMessageGroupWithType: GISentMessageGroup defaultName: @"My Threads"];
}

//+ (void)setSentMessageGroup:(GIMessageGroup *)aMessageGroup
//{
//	[self setStandardMessageGroup:aMessageGroup forDefaultsKey:SentMessageGroupURLString];
//}

+ (GIMessageGroup *)draftMessageGroup
{
    return [self standardMessageGroupWithType: GIDraftMessageGroup defaultName: @"Draft Messages"];
}

//+ (void)setDraftMessageGroup:(GIMessageGroup *)aMessageGroup
//{
//	[self setStandardMessageGroup:aMessageGroup forDefaultsKey:DraftsMessageGroupURLString];
//}

+ (GIMessageGroup *)queuedMessageGroup
{
    return [self standardMessageGroupWithType: GIQueuedMessageGroup defaultName: @"Queued Messages"];
}

//+ (void)setQueuedMessageGroup:(GIMessageGroup *)aMessageGroup
//{
//	[self setStandardMessageGroup:aMessageGroup forDefaultsKey:QueuedMessageGroupURLString];
//}

+ (GIMessageGroup *)spamMessageGroup
{
    return [self standardMessageGroupWithType: GISpamMessageGroup defaultName: @"Spam"];
}

//+ (void)setSpamMessageGroup:(GIMessageGroup *)aMessageGroup
//{
//	[self setStandardMessageGroup:aMessageGroup forDefaultsKey:SpamMessageGroupURLString];
//}

+ (GIMessageGroup *)trashMessageGroup
{
    return [self standardMessageGroupWithType: GITrashMessageGroup defaultName: @"Trash"];
}

//+ (void)setTrashMessageGroup:(GIMessageGroup *)aMessageGroup
//{
//	[self setStandardMessageGroup:aMessageGroup forDefaultsKey:TrashMessageGroupURLString];
//}

- (int)type
/*" Returns the special type of messageGroup (e.g. GIQueuedMessageGroup) or 0 for a regular messageGroup. "*/
{
	return type;
}

- (BOOL)isDeletable
{
	return self.type == GIRegularMessageGroup;
}

- (BOOL)isValidUserCopyOrMoveSourceOrDestination
{
	return type == GIRegularMessageGroup || type == GISpamMessageGroup || type == GITrashMessageGroup || type == GIDefaultMessageGroup;
}

- (NSString *)imageName
{
	static NSString *imageNames[] = {@"OtherMailbox", @"InMailbox", @"ToBeDeliveredMailbox", @"DraftsMailbox", @"OutMailbox", @"JunkMailbox", @"TrashMailbox"};
	return imageNames[MAX(0, [self type] - 1)];
}
 
+ (NSImage *)imageForMessageGroup:(GIMessageGroup *)aMessageGroup
{
    NSString *imageName = [aMessageGroup imageName];    
    return [NSImage imageNamed:imageName];
}

- (BOOL)canHaveChildren
{
	return NO;
}

- (void)willSave
{
	[super willSave];
	if ([[self valueForKey:@"name"] length] == 0) {
		NSLog(@"Pleased supply a name for %@.", self);
	}
}
 
- (NSSet *)threads
{
	if (!threads) {
		threads = [[OPLargePersistentSet alloc] init];
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
		defaultProfileOID = [coder decodeOIDForKey: @"defaultProfile"];
		type = [coder decodeInt32ForKey: @"type"];
		if ([coder allowsPartialCoding]) {
			threads = [[coder decodeObjectForKey: @"threads"] retain];
			unreadMessageCount = [coder decodeIntForKey: @"unreadMessageCount"];
		}
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
	}
	
//	NSUInteger umc  = self.unreadMessageCount;
//	NSUInteger cumc = self.calculatedUnreadMessageCount;
//	if (umc != cumc) {
//		NSLog(@"Warning! unreadMessageCount out of sync.");
//	}
}

- (void) addPrimitiveThreadsObject: (GIThread*) newThread
{
	[(NSMutableSet*)self.threads addObject: newThread];
	[self adjustUnreadMessageCountBy: newThread.unreadMessageCount];
}

- (void) addThreadsObject: (GIThread*) newThread
/*" Sent by the mutableSet proxy. "*/
{	
	// Prevent newThread from being added multiple times:
	if (! [self.threads containsObject: newThread]) {
		[self addPrimitiveThreadsObject: newThread];
		
		// Update the inverse relation:	
		NSSet* selfSet = [NSSet setWithObject: self];
		[newThread willChangeValueForKey: @"messageGroups" withSetMutation: NSKeyValueUnionSetMutation usingObjects: selfSet];
		[newThread addPrimitiveMessageGroupsObject: self];
		[newThread didChangeValueForKey: @"messageGroups" withSetMutation:NSKeyValueUnionSetMutation usingObjects: selfSet];
	}
}


- (void) removePrimitiveThreadsObject: (GIThread*) oldThread
{
	[(NSMutableSet*)self.threads removeObject: oldThread];
	[self adjustUnreadMessageCountBy: -oldThread.unreadMessageCount];
}

- (void) removeThreadsObject: (GIThread*) oldThread
/*" Sent by the mutableSet proxy. "*/
{
	// Prevent newThread from being added multiple times:
	if ([self.threads containsObject: oldThread]) {
		[self removePrimitiveThreadsObject: oldThread];
		
		// Update the inverse relation:
		NSSet* selfSet = [NSSet setWithObject: self];
		[oldThread willChangeValueForKey: @"messageGroups" withSetMutation: NSKeyValueMinusSetMutation usingObjects: selfSet];
		[oldThread removePrimitiveMessageGroupsObject: self];
		[oldThread didChangeValueForKey: @"messageGroups" withSetMutation:NSKeyValueMinusSetMutation usingObjects: selfSet];
	}
}

- (void) increaseUnreadMessageCount
{
	[self adjustUnreadMessageCountBy:1];
}

- (void) decreaseUnreadMessageCount
{
	[self adjustUnreadMessageCountBy:-1];
}

- (void) encodeWithCoder: (NSCoder*) coder
{
	[super encodeWithCoder: coder];
	[coder encodeOID: defaultProfileOID forKey: @"defaultProfile"];
	[coder encodeInt32: type forKey: @"type"];
	// Encode threads only with encoders that support big object archives:
	if ([coder allowsPartialCoding]) {
		[coder encodeObject: threads forKey: @"threads"];
		[coder encodeInt: unreadMessageCount forKey: @"unreadMessageCount"];
	}
}

- (void) addThreadsByDateObject: (GIThread*) aThread
/*" Should be called by the mutableSetProxy. "*/
{
	[threads addObject: aThread];
	//if (! [[aThread messageGroups] containsObject: self]) {
		[[aThread mutableSetValueForKey: @"messageGroups"] addObject: self];	
	//}
}

- (void) removeThreadsByDateObject: (GIThread*) aThread
/*" Should be called by the mutableSetProxy. "*/
{
	[threads removeObject: aThread];
	//if ([[aThread messageGroups] containsObject: self]) {
		[[aThread mutableSetValueForKey: @"messageGroups"] removeObject: self];	
	//}
}


@end
