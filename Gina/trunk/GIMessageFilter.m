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

@implementation GIMessageFilter

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
			(*putInBox) = NO;
		}
		else
		{
			[[group mutableSetValueForKey:@"threads"] addObject:[message thread]];;
		}
	}
}

/*" Applies matching filters to the given message. Returns YES if message was inserted/moved into a box different to currentBox. NO otherwise. "*/
+ (BOOL)applyFiltersToMessage:(GIMessage *)message
{
    BOOL inserted = NO;

	for (id filter in [self filtersMatchingForMessage:message])
	{
		BOOL putInBox;
		BOOL shouldStop;
		
		[self performFilterActions:filter onMessage:message putIntoMessagebox:&putInBox shouldStop:&shouldStop];
		
		if (shouldStop) break;
		
		inserted |= putInBox;
	}
	
    return inserted;
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