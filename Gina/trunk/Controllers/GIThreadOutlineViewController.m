//
//  GIThreadOutlineViewController.m
//  Gina
//
//  Created by Axel Katerbau on 08.01.08.
//  Copyright 2008 Objectpark Group. All rights reserved.
//

#import "GIThreadOutlineViewController.h"
#import "GIApplication.h"
#import "GIMessage.h"
#import "GIMessage+Rendering.h"
#import "GIThread.h"
#import "GIUserDefaultsKeys.h"
#import "NSAttributedString+Extensions.h"
#import "NSString+Extensions.h"

static inline NSString *nilGuard(NSString *str)
{
    return str ? str : @"";
}

// diverse attributes
static NSDictionary *unreadAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes)
	{
        attributes = [[NSDictionary alloc] initWithObjectsAndKeys:
					  [NSFont boldSystemFontOfSize:12], NSFontAttributeName,
					  nil];
    }
    return attributes;
}

static NSDictionary *readAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes) 
	{
        attributes = [[NSDictionary alloc] initWithObjectsAndKeys:
					  [NSFont systemFontOfSize:12], NSFontAttributeName,
					  nil];
    }
    return attributes;
}

static NSDictionary *newAttributesWithColor(NSColor *color) 
{
	NSDictionary* attributes = [[NSDictionary alloc] initWithObjectsAndKeys:
								[NSFont systemFontOfSize: 12], NSFontAttributeName,
								color, NSForegroundColorAttributeName, 
								nil, nil];
	return attributes;
}


static NSDictionary *spamMessageAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes) 
	{
        attributes = newAttributesWithColor([[NSColor brownColor] highlightWithLevel:0.0]);
    }
    return attributes;
}

static NSDictionary *fromAttributes()
{
//	return readAttributes();
	
	static NSDictionary *attributes = nil;
	
	if (! attributes) 
	{
		attributes = newAttributesWithColor([[NSColor darkGrayColor] shadowWithLevel:0.3]);
	}
	return attributes;
}

static NSDictionary *unreadFromAttributes()
{
	return fromAttributes();
//  return unreadAttributes();
}

static NSDictionary *readFromAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes) 
	{
        attributes = [[fromAttributes()mutableCopy] autorelease];
        [(NSMutableDictionary *)attributes addEntriesFromDictionary:readAttributes()];
        attributes = [attributes copy];
    }
    return attributes;
}

/*" String for inserting for message inset. "*/
static NSAttributedString *spacer()
{
    static NSAttributedString *spacer = nil;
    if (! spacer)
	{
        spacer = [[NSAttributedString alloc] initWithString:@"     "];
    }
    return spacer;
}

NSDateFormatter *timeAndDateFormatter()
{
	static NSDateFormatter *timeAndDateFormatter = nil;
	
	if (!timeAndDateFormatter)
	{
		timeAndDateFormatter = [[NSDateFormatter alloc] init];
		[timeAndDateFormatter setDateStyle:NSDateFormatterShortStyle];
		[timeAndDateFormatter setTimeStyle:NSDateFormatterShortStyle];
	}
	
	return timeAndDateFormatter;
}

@implementation GIMessage (ThreadControllerExtensions)

- (NSAttributedString *)renderedMessage
{
	NSAttributedString *result;
	BOOL showRawSource = [[NSUserDefaults standardUserDefaults] boolForKey:ShowRawSource];;
	
	if (showRawSource) 
	{
		NSData *transferData = [(OPInternetMessage *)[self internetMessage] transferData];
		NSString *transferString = [NSString stringWithData:transferData encoding:NSUTF8StringEncoding];
		
		static NSDictionary *fixedFont = nil;
		
		if (!fixedFont) 
		{
			fixedFont = [[NSDictionary alloc] initWithObjectsAndKeys:[NSFont userFixedPitchFontOfSize:10], NSFontAttributeName, nil, nil];
		}
		
		// joerg: this is a quick hack (but seems sufficient here) to handle 8 bit transfer encoded messages (body) without having to do the mime parsing
		if (! transferString) 
		{
			transferString = [NSString stringWithData:transferData encoding:NSISOLatin1StringEncoding];
		}
		
		result = [[[NSAttributedString alloc] initWithString:transferString attributes:fixedFont] autorelease]; 
	} 
	else 
	{
		result = [self renderedMessageIncludingAllHeaders:[[NSUserDefaults standardUserDefaults] boolForKey:ShowAllHeaders]];
	}
	
	if (!result) 
	{
		result = [[NSAttributedString alloc] initWithString:@"Warning: Unable to decode message. messageText == nil."];
	}
	
	return result;
}

@end

@interface GIMessage (private)
- (id)renderedMessage;
@end

@interface GIMessage (ThreadViewSupport)
- (GIMessage *)message;
- (NSArray *)threadChildren;
- (id)subjectAndAuthor;
- (NSAttributedString *)messageForDisplay;
- (NSImage *)statusImage;
@end

@implementation GIMessage (ThreadViewSupport)

+ (NSSet *)keyPathsForValuesAffectingSubjectAndAuthor
{
	return [NSSet setWithObjects:@"senderName", @"flags", nil];
}

+ (NSSet *)keyPathsForValuesAffectingDateForDisplay
{
	return [NSSet setWithObjects:@"date", @"flags", nil];
}

+ (NSSet *)keyPathsForValuesAffectingStatusImage
{
	return [NSSet setWithObject:@"flags"];
}

- (GIMessage *)message
{
	return self;
}

- (NSArray *)threadChildren
{
	return nil;
}

- (id)subjectAndAuthor
{
	//	return [NSString stringWithFormat:@"    %@", [self valueForKey:@"senderName"]];
	NSMutableAttributedString *result = [[[NSMutableAttributedString alloc] init] autorelease];
	NSString *from = [self senderName];
	
	if (!from) 
	{
		from = @"- sender missing -";
	}
	
	
	[result appendAttributedString:spacer()];
	//	NSUInteger indentation = [self numberOfReferences];
	
	//	for (i = MIN(MAX_INDENTATION, indentation); i > 0; i--) 
	//	{
	//		[result appendAttributedString:spacer()];
	//	}
	//	
	//	[result appendAttributedString: (indentation > MAX_INDENTATION)? spacer2() : spacer()];
	
	NSDictionary *completeAttributes = (self.flags & OPSeenStatus) ? readAttributes() : unreadAttributes();
	
	if (flags & OPJunkMailStatus) 
	{
		completeAttributes = spamMessageAttributes();
	}
	
	[result appendAttributedString:[[[NSAttributedString alloc] initWithString:nilGuard(from) attributes:completeAttributes] autorelease]];
	
	return result;
}

- (NSAttributedString *)messageForDisplay
{
	return [self renderedMessage];
}

- (NSAttributedString *)dateForDisplay
{
	BOOL isRead = [self hasFlags:OPSeenStatus];
	
	NSString *dateString = [timeAndDateFormatter() stringFromDate:self.date];
	
	return [[[NSAttributedString alloc] initWithString:nilGuard(dateString) attributes:isRead ? readAttributes() : unreadAttributes()] autorelease];
}

- (NSImage *)statusImage
{
	if (!self.isSeen) return [NSImage imageNamed:@"unread"];
	return nil;
}

@end

@interface GIThread (ThreadViewSupport)
- (GIMessage *)message;
- (OPFaultingArray *)threadChildren;
- (id)subjectAndAuthor;
- (NSAttributedString *)messageForDisplay;
- (NSAttributedString *)dateForDisplay;
- (NSImage *)statusImage;
@end

@implementation GIThread (ThreadViewSupport)

+ (NSSet *)keyPathsForValuesAffectingThreadChildren
{
	return [NSSet setWithObject:@"messagesByTree"];
}

+ (NSSet *)keyPathsForValuesAffectingSubjectAndAuthor
{
	return [NSSet setWithObjects:@"messagesByTree", @"messages", @"subject", nil];
}

+ (NSSet *)keyPathsForValuesAffectingDateForDisplay
{
	return [NSSet setWithObjects:@"date", @"hasUnreadMessages", nil];
}

+ (NSSet *)keyPathsForValuesAffectingStatusImage
{
	return [NSSet setWithObject:@"hasUnreadMessages"];
}

- (OPFaultingArray *)threadChildren
{
	OPFaultingArray *threadChildren = self.messagesByTree;
	
	if ([threadChildren count] > 1)
	{
		// multi-message thread
		return threadChildren;
	}
	else
	{
		// single-message thread
		return nil;
	}
}

- (id)subjectAndAuthor
{
	OPFaultingArray *msgs = self.messagesByTree;
	
	if ([msgs count] > 1)
	{
		// multi-message thread
		return [[[NSAttributedString alloc] initWithString:nilGuard(self.subject) attributes:[self hasUnreadMessages] ? unreadAttributes() : readAttributes()] autorelease];
	}	
	else
	{
		// single-message thread
		NSString *from;
		NSAttributedString *aFrom;
		GIMessage *message = [self.messages lastObject];
		NSMutableAttributedString *result = [[[NSMutableAttributedString alloc] init] autorelease];
		
		if (message) 
		{
			unsigned flags  = [message flags];
			NSString *subjectString = nilGuard([message valueForKey:@"subject"]);
			
			NSAttributedString *aSubject = [[NSAttributedString alloc] initWithString:nilGuard(subjectString) attributes:(flags & OPSeenStatus) ? readAttributes() : unreadAttributes()];
			
			[result appendAttributedString:aSubject];
			
			if (flags & OPIsFromMeStatus) 
			{
				from = [NSString stringWithFormat:@" (%C %@)", 0x279F/*Right Arrow*/, message.recipientsForDisplay];
			} 
			else 
			{
				from = message.senderName;
				if (!from) from = @"- sender missing -";
				from = [NSString stringWithFormat:@" (%@)", from];
			}       
			NSDictionary *completeAttributes = ((flags & OPSeenStatus) || (flags & OPIsFromMeStatus)) ? readFromAttributes() : unreadFromAttributes();
			
			if (flags & OPJunkMailStatus) 
			{
				completeAttributes = spamMessageAttributes();
			}
			
			aFrom = [[NSAttributedString alloc] initWithString:nilGuard(from) attributes:completeAttributes];
			
			[result appendAttributedString:aFrom];
			
			[aSubject release];
			[aFrom release];
		}
		
		return result;
	}
}

- (GIMessage *)message
{
	OPFaultingArray *msgs = [self messagesByTree];
	if ([msgs count] == 1)
	{
		return [msgs lastObject];
	}
	else
	{
		return nil;
	}
}

- (NSAttributedString *)messageForDisplay
{
	GIMessage *message = [self message];
	
	if (message)
	{
		// single-message thread
		return [message renderedMessage];
	}	
	else
	{
		// multi-message thread
		NSMutableAttributedString *result = [[[NSMutableAttributedString alloc] init] autorelease];
		
		if (NO) //[messagesByTree count] > 0)
		{
			[result appendString:[NSString stringWithFormat:@"\nThread '%@':\n", [[self subjectAndAuthor] string]]];
			[result appendString:[NSString stringWithFormat:@"contains %d messages\n", [[self messages] count]]];
		}
		return result;
	}
}

- (NSAttributedString *)dateForDisplay
{
	BOOL isRead = !self.hasUnreadMessages;
	
	NSString *dateString = [timeAndDateFormatter() stringFromDate:self.date];
	
	return [[[NSAttributedString alloc] initWithString:nilGuard(dateString) attributes:isRead ? readAttributes() : unreadAttributes()] autorelease];
}

- (NSImage *)statusImage
{
	if ([self hasUnreadMessages]) return [NSImage imageNamed:@"unread"];
	return nil;
}

@end

@implementation GIThreadOutlineViewController

@synthesize suspendUpdatesUntilNextReloadData;

- (id) init
{
	if (self = [super init]) 
	{
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(suspend:) name:GISuspendThreadViewUpdatesNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resume:) name:GIResumeThreadViewUpdatesNotification object:nil];
	}
	return self;
}

- (void)suspend:(NSNotification *)aNotification
{
	self.suspendUpdatesUntilNextReloadData = YES;
}

- (void)resume:(NSNotification *)aNotification
{
	[self reloadData];
}

- (void) observeValueForKeyPath: (NSString*) keyPath 
					   ofObject: (id) object 
						 change: (NSDictionary*) change 
						context: (void*) context
{
	if (!self.suspendUpdatesUntilNextReloadData)
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}	

- (void) reloadData
/*" Call this instead of calling reloadData on the outline. "*/
{
	self.suspendUpdatesUntilNextReloadData = NO;
	[super reloadData];
}

/*" Changes the text color to white, if the cell's background is darkish. "*/
- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	NSBackgroundStyle backgroundStyle = [cell backgroundStyle];

	if (backgroundStyle == NSBackgroundStyleDark)
	{
		id objectValue = [cell objectValue];
		if ([objectValue isKindOfClass:[NSAttributedString class]])
		{
			NSMutableAttributedString *title = [objectValue mutableCopy];
			
			[title addAttribute:NSForegroundColorAttributeName value:[NSColor whiteColor] range:NSMakeRange(0, [title length])];
			[cell setObjectValue:title];
			
			[title release];
		}
	}
}

- (NSArray *)selectedMessages
{
	NSMutableArray *result = [NSMutableArray array];
	
	for (id selectedObject in [self selectedObjects])
	{
		if ([selectedObject isKindOfClass:[GIThread class]])
		{
			[result addObjectsFromArray:[(GIThread *)selectedObject messages]];
		}
		else
		{
			NSAssert([selectedObject isKindOfClass:[GIMessage class]], @"expected a GIMessage object");
			[result addObject:selectedObject];
		}
	}	
	
	return result;
}

- (void)setSelectedMessages:(NSArray *)someMessages
{
	if (![someMessages isEqual:[self selectedObjects]]) 
	{
		for (GIMessage *messageToSelect in someMessages)
		{
			// make sure thread is expanded:
			[outlineView expandItem:[messageToSelect thread] expandChildren:YES];
		}
		
		[self setSelectedObjects:someMessages];
	}
}

- (BOOL)selectionHasUnreadMessages
{
	for (GIMessage *message in [self selectedMessages])
	{
		if (!([message flags] & OPSeenStatus))
		{
			return YES;
		}
	}
	
	return NO;
}

- (BOOL)selectionHasReadMessages
{
	for (GIMessage *message in [self selectedMessages])
	{
		if ([message flags] & OPSeenStatus)
		{
			return YES;
		}
	}
	
	return NO;
}

- (NSSet*) keyPathsAffectingDisplayOfItem: (id) item
{
	return [NSSet setWithObjects: @"isSeen", @"hasUnreadMessages", nil];
}

@end
