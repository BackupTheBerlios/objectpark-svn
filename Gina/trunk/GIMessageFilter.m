//
//  GIMessageFilter.m
//  Gina
//
//  Created by Axel Katerbau on 21.12.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "GIMessageFilter.h"
#import "GIMessage.h"
#import "GIMessageGroup.h"
#import "OPPersistentObjectContext.h"
#import "GIThread.h"
#import "OPFaultingArray.h"


@implementation GIMessageFilter

/*" Returns a (sub)set of the receiver's filters which match for the given message. "*/
+ (NSArray *)filtersMatchingForMessage:(id)message
{
    NSMutableArray *result = [NSMutableArray array];
	
    for (GIMessageFilter *filter in [self filters]) 
    {
        if (filter.enabled && [filter.predicate evaluateWithObject:message]) 
        {
            [result addObject:filter];
        }
    }
    
    return result;
}

/*" Applies matching filters to the given message. Returns YES if message was inserted/moved into a box different to currentBox. NO otherwise. "*/
+ (BOOL)applyFiltersToMessage:(GIMessage *)message
{
    BOOL inserted = NO;
	
	for (id filter in [self filtersMatchingForMessage:message])
	{
		BOOL putInBox = NO;
		BOOL shouldStop = NO;
		
		[filter performFilterActionsOnMessage:message putIntoMessagebox:&putInBox shouldStop:&shouldStop];
		
		inserted |= putInBox;
		
		if (shouldStop) break;
	}
	
    return inserted;
}

/*" Applies filtering to the threads someThreads. The threads are removed from the group aGroup and only added again if they fit in no group defined by filtering. "*/
+ (void)applyFiltersToThreads:(id <NSFastEnumeration>)someThreads inGroup:(GIMessageGroup *)aGroup
{
	NSParameterAssert([aGroup isKindOfClass:[GIMessageGroup class]]);
	
	for (GIThread *thread in someThreads) {
		NSAssert([thread isKindOfClass:[GIThread class]], @"threads only");
		//		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		NSMutableSet *messageGroups = [thread mutableSetValueForKey:@"messageGroups"];
		// Remove selected thread from receiver's group:
		[messageGroups removeObject:aGroup];
		
		BOOL threadWasPutIntoAtLeastOneGroup = NO;
		
		@try {
			// apply sorters and filters (and readd threads that have no fit to avoid dangling threads):
			for (GIMessage *message in thread.messages)
			{
				threadWasPutIntoAtLeastOneGroup |= [self applyFiltersToMessage:message];
			}
		} @catch (id localException) {
			@throw;
		} @finally {
			if (!threadWasPutIntoAtLeastOneGroup) {				
				[messageGroups addObject:aGroup];
			}
		}
	}
}

+ (BOOL)cachesAllObjects
{
	return YES;
}

+ (NSArray*) filters
{	
	OPPersistentObjectContext *context = [OPPersistentObjectContext defaultContext];
	
	OPFaultingArray* result = [context rootObjectForKey: @"Filters"];
	
	if (!result) {
		result = [[[OPFaultingArray alloc] init] autorelease];
		[context setRootObject: result forKey: @"Filters"];
	}
	return result;
}

//- (void) didChangeValueForKey: (NSString*) key
//{
//	[super didChangeValueForKey: key];
//}

+ (void) insertObject: (GIMessageFilter*) aFilter inFiltersAtIndex: (NSUInteger) index 
{
	[(OPFaultingArray*)[self filters] insertObject: aFilter atIndex: index];
}

+ (void) removeObjectFromFiltersAtIndex: (NSUInteger)index 
{
	OPFaultingArray* allFilters = (OPFaultingArray*)[self filters];
	[allFilters removeObjectAtIndex: index];
}


- (void)performFilterActionsOnMessage:(GIMessage *)message putIntoMessagebox:(BOOL *)putInBox shouldStop:(BOOL *)shouldStop
{
	if (self.performActionMarkAsSpam)
	{
		if (![message hasFlags:OPJunkMailStatus])
		{
			[message toggleFlags:OPJunkMailStatus];
		}
	}
	
	(*shouldStop) = self.performActionPreventFurtherFiltering;
	(*putInBox) = self.performActionPutInMessageGroup;
	
	if (*putInBox)
	{
		GIMessageGroup *group = self.putInMessageGroup;
		
		if (!group) 
		{
			// TODO: create message group with name of the filter
			(*putInBox) = NO;
		}
		else
		{
			[[group mutableSetValueForKey:@"threads"] addObject:[message thread]];
			(*putInBox) = YES;
		}
	}
}

- (NSString *)name
{
	return name;
}

- (void)setName:(NSString *)aString
{
	[self willChangeValueForKey:@"name"];
	[name autorelease];
	name = [aString copy];
	[self didChangeValueForKey:@"name"];
}

- (BOOL)enabled
{
	return enabled;
}

- (void)setEnabled:(BOOL)aBool
{
	[self willChangeValueForKey:@"enabled"];
	enabled = aBool;
	[self didChangeValueForKey:@"enabled"];
}

- (NSPredicate *)predicate
{
	if (!predicate)
	{
		NSPredicate *innerPredicate = [NSComparisonPredicate predicateWithLeftExpression:[NSExpression expressionForKeyPath:@"from"] rightExpression:[NSExpression expressionForConstantValue:@""] modifier:NSDirectPredicateModifier type:NSContainsPredicateOperatorType options:NSCaseInsensitivePredicateOption];
		
		predicate = [[NSCompoundPredicate orPredicateWithSubpredicates:[NSArray arrayWithObject:innerPredicate]] retain];
	}
	
	return predicate;
}

- (void)setPredicate:(NSPredicate *)aPredicate
{
	[self willChangeValueForKey:@"predicate"];
	[predicate autorelease];
	predicate = [aPredicate retain];
	[self didChangeValueForKey:@"predicate"];
}

- (BOOL)performActionPutInMessageGroup
{
	return performActionPutInMessageGroup;
}

- (void)setPerformActionPutInMessageGroup:(BOOL)aBool
{
	[self willChangeValueForKey:@"performActionPutInMessageGroup"];
	performActionPutInMessageGroup = aBool;
	[self didChangeValueForKey:@"performActionPutInMessageGroup"];
}

- (GIMessageGroup *)putInMessageGroup
{
	return [self.objectContext objectForOID:putInMessageGroupOID];
}

- (void)setPutInMessageGroup:(GIMessageGroup *)aMessageGroup
{
	if (putInMessageGroupOID != [aMessageGroup oid]) 
	{
		[self willChangeValueForKey:@"putInMessageGroup"];		
		putInMessageGroupOID = [aMessageGroup oid];
		[self didChangeValueForKey:@"putInMessageGroup"];
	}
}

- (BOOL)performActionMarkAsSpam
{
	return performActionMarkAsSpam;
}

- (void)setPerformActionMarkAsSpam:(BOOL)aBool
{
	[self willChangeValueForKey:@"performActionMarkAsSpam"];
	performActionMarkAsSpam = aBool;
	[self didChangeValueForKey:@"performActionMarkAsSpam"];
}

- (BOOL)performActionPreventFurtherFiltering
{
	return performActionPreventFurtherFiltering;
}

- (void)setPerformActionPreventFurtherFiltering:(BOOL)aBool
{
	[self willChangeValueForKey:@"performActionPreventFurtherFiltering"];
	performActionPreventFurtherFiltering = aBool;
	[self didChangeValueForKey:@"performActionPreventFurtherFiltering"];
}

- (id)init
{
	self = [super init];
	enabled = YES;
	return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
	name = [[coder decodeObjectForKey:@"name"] retain];
	enabled = [coder decodeBoolForKey:@"enabled"];
	predicate = [[coder decodeObjectForKey:@"predicate"] retain];
	performActionPutInMessageGroup = [coder decodeBoolForKey:@"performActionPutInMessageGroup"];
	putInMessageGroupOID = [coder decodeOIDForKey:@"putInMessageGroupOID"];
	performActionMarkAsSpam = [coder decodeBoolForKey:@"performActionMarkAsSpam"];
	performActionPreventFurtherFiltering = [coder decodeBoolForKey:@"performActionPreventFurtherFiltering"];
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:name forKey:@"name"];
	[coder encodeBool:enabled forKey:@"enabled"];
	[coder encodeObject:predicate forKey:@"predicate"];
	[coder encodeBool:performActionPutInMessageGroup forKey:@"performActionPutInMessageGroup"];
	[coder encodeOID:putInMessageGroupOID forKey:@"putInMessageGroupOID"];
	[coder encodeBool:performActionMarkAsSpam forKey:@"performActionMarkAsSpam"];
	[coder encodeBool:performActionPreventFurtherFiltering forKey:@"performActionPreventFurtherFiltering"];
}

- (id)mutableCopyWithZone:(NSZone *)aZone
{
	GIMessageFilter *result = [[[self class] alloc] init];

	result.name = [self.name stringByAppendingString:NSLocalizedString(@" Clone", @"Clone")];
	result.enabled = self.enabled;
	result.predicate = self.predicate;
	result.performActionPutInMessageGroup = self.performActionPutInMessageGroup;
	result->putInMessageGroupOID = self->putInMessageGroupOID;
	result.performActionMarkAsSpam = self.performActionMarkAsSpam;
	result.performActionPreventFurtherFiltering = self.performActionPreventFurtherFiltering;
	
	return result;
}

- (void)dealloc
{
	[name release];
	[predicate release];
	
	[super dealloc];
}

@end

#import "GIMessage.h"
#import <InternetMessage/OPInternetMessage.h>
#import <InternetMessage/EDTextFieldCoder.h>

@implementation GIMessage (GIFilterSupport)

- (NSString *)replyTo
{
	NSString *fBody;
	NSString *result = @"";
	
	if (fBody = [self.internetMessage bodyForHeaderField:@"reply-to"])
	{
		result = [[EDTextFieldCoder decoderWithFieldBody:fBody] text];
	}
	
	return result;
}

- (NSString *)listId
{
	NSString *fBody;
	NSString *result = @"";
	
	if (fBody = [self.internetMessage bodyForHeaderField:@"list-id"])
	{
		result = [[EDTextFieldCoder decoderWithFieldBody:fBody] text];
	}
	
	return result;
}

- (NSString *)to
{
	NSString *fBody;
	NSString *result = @"";
	
	if (fBody = [self.internetMessage bodyForHeaderField:@"to"])
	{
		result = [[EDTextFieldCoder decoderWithFieldBody:fBody] text];
	}
	
	return result;
}

- (NSString *)resentTo
{
	NSString *fBody;
	NSString *result = @"";
	
	if (fBody = [self.internetMessage bodyForHeaderField:@"resent-to"])
	{
		result = [[EDTextFieldCoder decoderWithFieldBody:fBody] text];
	}
	
	return result;
}

- (NSString *)cc
{
	NSString *fBody;
	NSString *result = @"";
	
	if (fBody = [self.internetMessage bodyForHeaderField:@"cc"])
	{
		result = [[EDTextFieldCoder decoderWithFieldBody:fBody] text];
	}
	
	return result;
}

- (NSString *)mailinglist
{
	return [[self listId] stringByAppendingString:[self to]];
}

- (NSString *)newsgroups
{
	NSString *fBody;
	NSString *result = @"";
	
	if (fBody = [self.internetMessage bodyForHeaderField:@"newsgroups"])
	{
		result = [[EDTextFieldCoder decoderWithFieldBody:fBody] text];
	}
	
	return result;
}

- (NSString *)from
{
	NSString *fBody;
	NSString *result = @"";
	
	if (fBody = [self.internetMessage bodyForHeaderField:@"from"])
	{
		result = [[EDTextFieldCoder decoderWithFieldBody:fBody] text];
	}
	
	return result;
}

- (NSString *)subjectRaw
{
	return [self.internetMessage subject];
}

- (NSString *)contentType
{
	return [self.internetMessage contentType];
}

- (NSString *)anyRecipient
{
	return [[[self to] stringByAppendingString:[self cc]] stringByAppendingString:[self resentTo]];
}

@end