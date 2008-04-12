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

@implementation GIMessageFilter

+ (BOOL)cachesAllObjects
{
	return YES;
}

static NSMutableArray *filters = nil;

+ (NSMutableArray *)filters
{	
	if (!filters)
	{
		filters = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Filters"] mutableCopy];
		if (!filters)
		{
			filters = [[NSMutableArray alloc] init];
		}
	}
	
	return filters;
}

+ (void)setFilters:(NSMutableArray *)someFilters
{
	[filters autorelease];
	filters = [someFilters retain];
	[self saveFilters];
}

+ (void)saveFilters
{
	[[NSUserDefaults standardUserDefaults] setObject:filters forKey:@"Filters"];
}

/*" Returns a (sub)set of the receiver's filters which match for the given message. "*/
+ (NSArray *)filtersMatchingForMessage:(id)message
{
    NSMutableArray *result = [NSMutableArray array];
	    
    for (id filter in [self filters]) 
    {
		NSString *predicateFormat = [filter valueForKey:@"predicateFormat"];
		NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateFormat];
		
        if ([predicate evaluateWithObject:message]) 
        {
            [result addObject:filter];
        }
    }
    
    return result;
}

+ (void)performFilterActions:(id)filter onMessage:(GIMessage *)message putIntoMessagebox:(BOOL *)putInBox shouldStop:(BOOL *)shouldStop
{
	BOOL markAsSpam = [[filter objectForKey:@"performActionMarkAsSpam"] boolValue];
	if (markAsSpam)
	{
		if (![message hasFlags:OPJunkMailStatus])
		{
			[message toggleFlags:OPJunkMailStatus];
		}
	}
	
	(*shouldStop) = [[filter objectForKey:@"performActionPreventFurtherFiltering"] boolValue];
	(*putInBox) = [[filter objectForKey:@"performActionPutInMessageGroup"] boolValue];
	
	if (*putInBox)
	{
		NSString *messageBoxURLString = [filter objectForKey:@"putInMessageGroupObjectURLString"];
		
		GIMessageGroup *group = [[OPPersistentObjectContext defaultContext] objectWithURLString:messageBoxURLString];
		
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

/*" Applies matching filters to the given message. Returns YES if message was inserted/moved into a box different to currentBox. NO otherwise. "*/
+ (BOOL)applyFiltersToMessage:(GIMessage *)message
{
    BOOL inserted = NO;

	for (id filter in [self filtersMatchingForMessage:message])
	{
		BOOL putInBox = NO;
		BOOL shouldStop = NO;
		
		[self performFilterActions:filter onMessage:message putIntoMessagebox:&putInBox shouldStop:&shouldStop];
		
		inserted |= putInBox;

		if (shouldStop) break;
	}
	
    return inserted;
}

/*" Applies filtering to the threads someThreads. The threads are removed from the group aGroup and only added again if they fit in no group defined by filtering. "*/
+ (void)applyFiltersToThreads:(id <NSFastEnumeration>)someThreads inGroup:(GIMessageGroup *)aGroup
{
	NSParameterAssert([aGroup isKindOfClass:[GIMessageGroup class]]);
	
	for (GIThread *thread in someThreads)
	{
		NSAssert([thread isKindOfClass:[GIThread class]], @"threads only");
//		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		NSMutableArray *messageGroups = [thread mutableArrayValueForKey:@"messageGroups"];
		// Remove selected thread from receiver's group:
		[messageGroups removeObject:aGroup];
		
		BOOL threadWasPutIntoAtLeastOneGroup = NO;
		
		@try 
		{
			// apply sorters and filters (and readd threads that have no fit to avoid dangling threads):
			for (GIMessage *message in thread.messages)
			{
				threadWasPutIntoAtLeastOneGroup |= [GIMessageFilter applyFiltersToMessage:message];
			}
		} 
		@catch (id localException) 
		{
			@throw;
		} 
		@finally 
		{
			if (!threadWasPutIntoAtLeastOneGroup) 
			{				
				if (![messageGroups containsObject:aGroup])
				{
					[messageGroups addObject:aGroup];
				}
			}
		}
//		[pool release];
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

- (NSPredicate *)predicate
{
	return predicate;
}

- (void)setPredicate:(NSPredicate *)aPredicate
{
	[self willChangeValueForKey:@"predicate"];
	[predicate autorelease];
	predicate = [aPredicate copy];
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
	return [[self context] objectForOID:putInMessageGroupOID];
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

- (id)initWithCoder:(NSCoder *)coder
{
	name = [coder decodeObjectForKey:@"name"];
	predicate = [coder decodeObjectForKey:@"predicate"];
	performActionPutInMessageGroup = [coder decodeBoolForKey:@"performActionPutInMessageGroup"];
	putInMessageGroupOID = [coder decodeOIDForKey:@"putInMessageGroupOID"];
	performActionMarkAsSpam = [coder decodeBoolForKey:@"performActionMarkAsSpam"];
	performActionPreventFurtherFiltering = [coder decodeBoolForKey:@"performActionPreventFurtherFiltering"];
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:name forKey:@"name"];
	[coder encodeObject:predicate forKey:@"predicate"];
	[coder encodeBool:performActionPutInMessageGroup forKey:@"performActionPutInMessageGroup"];
	[coder encodeOID:putInMessageGroupOID forKey:@"putInMessageGroupOID"];
	[coder encodeBool:performActionMarkAsSpam forKey:@"performActionMarkAsSpam"];
	[coder encodeBool:performActionPreventFurtherFiltering forKey:@"performActionPreventFurtherFiltering"];
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
	return [[self to] stringByAppendingString:[self cc]];
}

@end