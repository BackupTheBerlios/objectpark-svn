//
//  GIMainWindowController.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 12.10.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "GIMainWindowController.h"

// helper
#import "NSArray+Extensions.h"
#import "GIUserDefaultsKeys.h"

// model stuff
#import "GIMessageGroup+Statistics.h"
#import "GIThread.h"
#import "GIMessage.h"

static inline NSString *nilGuard(NSString *str)
{
    return str ? str : @"";
}

// diverse attributes
static NSDictionary* unreadAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes){
        attributes = [[NSDictionary alloc] initWithObjectsAndKeys:
					  [NSFont boldSystemFontOfSize:12], NSFontAttributeName,
					  nil];
    }
    return attributes;
}

static NSDictionary* readAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes) {
        attributes = [[NSDictionary alloc] initWithObjectsAndKeys:
					  [NSFont systemFontOfSize:12], NSFontAttributeName,
					  [[NSColor blackColor] highlightWithLevel:0.15], NSForegroundColorAttributeName, nil];
    }
    return attributes;
}

static NSDictionary* newAttributesWithColor(NSColor* color) 
{
	NSDictionary* attributes = [[NSDictionary alloc] initWithObjectsAndKeys:
								[NSFont systemFontOfSize: 12], NSFontAttributeName,
								color, NSForegroundColorAttributeName, 
								nil, nil];
	return attributes;
}


static NSDictionary* spamMessageAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes) {
        attributes = newAttributesWithColor([[NSColor brownColor] highlightWithLevel: 0.0]);
    }
    return attributes;
}

static NSDictionary* selectedReadAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes) {
        attributes = newAttributesWithColor([[NSColor selectedMenuItemTextColor] shadowWithLevel: 0.15]);
    }
    
    return attributes;
}

static NSDictionary* fromAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes) {
        attributes = newAttributesWithColor([[NSColor darkGrayColor] shadowWithLevel:0.3]);
    }
    return attributes;
}

static NSDictionary* unreadFromAttributes()
{
	return unreadAttributes();
}

static NSDictionary *selectedUnreadFromAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes)
    {
        attributes = [[unreadFromAttributes()mutableCopy] autorelease];
        [(NSMutableDictionary *)attributes setObject: [[NSColor selectedMenuItemTextColor] shadowWithLevel:0.15] forKey:NSForegroundColorAttributeName];
        attributes = [attributes copy];
    }
    return attributes;
}

static NSDictionary *readFromAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes) {
        attributes = [[fromAttributes()mutableCopy] autorelease];
        [(NSMutableDictionary *)attributes addEntriesFromDictionary:readAttributes()];
        [(NSMutableDictionary *)attributes setObject: [[NSColor darkGrayColor] highlightWithLevel:0.25] forKey:NSForegroundColorAttributeName];
        attributes = [attributes copy];
    }
    return attributes;
}

static NSDictionary *selectedReadFromAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes) {
        attributes = [[readFromAttributes()mutableCopy] autorelease];
        [(NSMutableDictionary *)attributes setObject: [[NSColor selectedMenuItemTextColor] shadowWithLevel:0.15] forKey:NSForegroundColorAttributeName];
        attributes = [attributes copy];
    }
    
    return attributes;
}

static NSAttributedString *spacer()
/*" String for inserting for message inset. "*/
{
    static NSAttributedString *spacer = nil;
    if (! spacer)
	{
        spacer = [[NSAttributedString alloc] initWithString:@"     "];
    }
    return spacer;
}

/*" String for inserting for messages which are to deep to display insetted. "*/
//static NSAttributedString* spacer2()
//{
//    static NSAttributedString *spacer = nil;
//    if (! spacer){
//        spacer = [[NSAttributedString alloc] initWithString: [NSString stringWithFormat: @"%C ", 0x21e5]];
//    }
//    return spacer;
//}

@interface GIMessage (private)
- (id)renderedMessage;
@end

@implementation GIMessageGroup (copying)
- (id)copyWithZone:(NSZone *)aZone
{
	return [self retain];
}
@end

@interface GIThread (ThreadViewSupport)
- (NSArray *)children;
- (id)subjectAndAuthor;
- (NSAttributedString *)messageForDisplay;
- (NSAttributedString *)dateForDisplay;
@end

@implementation GIThread (ThreadViewSupport)

- (NSArray *)children
{
	NSArray *messagesByTree = [self messagesByTree];
	
	if ([messagesByTree count] > 1)
	{
		// multi-message thread
		return messagesByTree;
	}
	else
	{
		// single-message thread
		return nil;
	}
}

- (id)subjectAndAuthor
{
	NSArray *messagesByTree = [self messagesByTree];
	//BOOL inSelectionAndAppActive = [[threadTreeController selectedObjects] containsObject:self];
	BOOL inSelectionAndAppActive = NO;

	if ([messagesByTree count] > 1)
	{
		// multi-message thread
		return [[[NSAttributedString alloc] initWithString:nilGuard([self valueForKey:@"subject"]) attributes:[self hasUnreadMessages] ? unreadAttributes() : (inSelectionAndAppActive ? selectedReadAttributes() : readAttributes())] autorelease];
	}	
	else
	{
		// single-message thread
		NSString *from;
		NSAttributedString *aFrom;
		GIMessage *message = [[self valueForKey:@"messages"] lastObject];
		NSMutableAttributedString *result = [[[NSMutableAttributedString alloc] init] autorelease];
				
		if (message) 
		{
			unsigned flags  = [message flags];
			NSString *subject = nilGuard([message valueForKey:@"subject"]);
			
			NSAttributedString *aSubject = [[NSAttributedString alloc] initWithString:nilGuard(subject) attributes:(flags & OPSeenStatus) ? (inSelectionAndAppActive ? selectedReadAttributes() : readAttributes()) : unreadAttributes()];
			
			[result appendAttributedString:aSubject];
			
			if (flags & OPIsFromMeStatus) 
			{
				from = [NSString stringWithFormat:@" (%C %@)", 0x279F/*Right Arrow*/, [message recipientsForDisplay]];
			} 
			else 
			{
				from = [message senderName];
				if (!from) from = @"- sender missing -";
				from = [NSString stringWithFormat:@" (%@)", from];
			}       
			NSDictionary *completeAttributes = ((flags & OPSeenStatus) || (flags & OPIsFromMeStatus)) ? (inSelectionAndAppActive ? selectedReadFromAttributes() : readFromAttributes()) : (inSelectionAndAppActive ? selectedUnreadFromAttributes() : unreadFromAttributes());
			
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

- (NSAttributedString *)messageForDisplay
{
	NSArray *messagesByTree = [self messagesByTree];

	if ([messagesByTree count] > 1)
	{
		// multi-message thread
		return [[[NSAttributedString alloc] initWithString:@""] autorelease];
	}
	else
	{
		// single-message thread
		return [[messagesByTree lastObject] renderedMessage];
	}
}

- (NSAttributedString *)dateForDisplay
{
	//BOOL inSelectionAndAppActive = [[threadTreeController selectedObjects] containsObject:self];
	BOOL inSelectionAndAppActive = NO;
	BOOL isRead = ![self hasUnreadMessages];
	
	NSCalendarDate *date = [self valueForKey:@"date"]; // both thread an message respond to "date"
	NSAssert2(date==nil || [date isKindOfClass:[NSCalendarDate class]], @"NSCalendarDate expected but got %@ from %@", NSStringFromClass([date class]), self);
	
	NSString *dateString = [date descriptionWithCalendarFormat:[[NSUserDefaults standardUserDefaults] objectForKey:NSShortTimeDateFormatString] timeZone:[NSTimeZone localTimeZone] locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
	
	return [[[NSAttributedString alloc] initWithString:nilGuard(dateString) attributes:isRead ? (inSelectionAndAppActive ? selectedReadFromAttributes() : readFromAttributes()) : unreadAttributes()] autorelease];
}

@end

@interface GIMessage (ThreadViewSupport)
- (NSArray *)children;
- (id)subjectAndAuthor;
- (NSAttributedString *)messageForDisplay;
@end

@implementation GIMessage (ThreadViewSupport)

- (NSArray *)children
{
	return nil;
}

- (id)subjectAndAuthor
{
	//	return [NSString stringWithFormat:@"    %@", [self valueForKey:@"senderName"]];
	NSMutableAttributedString *result = [[[NSMutableAttributedString alloc] init] autorelease];
	//BOOL inSelectionAndAppActive = [[threadTreeController selectedObjects] containsObject:self];
	BOOL inSelectionAndAppActive = NO;
	NSString *from = [self senderName];
	BOOL flags  = [self flags];
	
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
	
	NSDictionary *completeAttributes = (flags & OPSeenStatus) ? (inSelectionAndAppActive ? selectedReadFromAttributes() : readFromAttributes()) : (inSelectionAndAppActive ? selectedUnreadFromAttributes() : unreadFromAttributes());
	
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
	//BOOL inSelectionAndAppActive = [[threadTreeController selectedObjects] containsObject:self];
	BOOL inSelectionAndAppActive = NO;
	BOOL isRead = [self hasFlags:OPSeenStatus];
	
	NSCalendarDate *date = [self valueForKey:@"date"]; // both thread an message respond to "date"
	NSAssert2(date==nil || [date isKindOfClass:[NSCalendarDate class]], @"NSCalendarDate expected but got %@ from %@", NSStringFromClass([date class]), self);
	
	NSString *dateString = [date descriptionWithCalendarFormat:[[NSUserDefaults standardUserDefaults] objectForKey:NSShortTimeDateFormatString] timeZone:[NSTimeZone localTimeZone] locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
	
	return [[[NSAttributedString alloc] initWithString:nilGuard(dateString) attributes:isRead ? (inSelectionAndAppActive ? selectedReadFromAttributes() : readFromAttributes()) : unreadAttributes()] autorelease];
}

@end

@interface GIMessageGroup (MessageGroupHierarchySupport)
- (NSArray *)children;
- (NSNumber *)count;
@end

@implementation GIMessageGroup (MessageGroupHierarchySupport)
- (NSArray *)children
{
	return nil;
}

- (NSNumber *)count
{
	return [NSNumber numberWithInt:0];
}

@end

@interface NSArray (MessageGroupHierarchySupport)
- (NSDictionary *)messageGroupHierarchyAsDictionaries;
@end

@implementation NSArray (MessageGroupHierarchySupport)

- (NSDictionary *)messageGroupHierarchyAsDictionaries
{
	NSMutableArray *children = [NSMutableArray array];
	if ([self count] >= 2) 
	{
		NSEnumerator *enumerator = [[self subarrayFromIndex:1] objectEnumerator];
		id object;
		
		while (object = [enumerator nextObject])
		{
			if ([object isKindOfClass:[NSArray class]])
			{
				[children addObject:[object messageGroupHierarchyAsDictionaries]];
			}
			else
			{
				GIMessageGroup *group = [OPPersistentObjectContext objectWithURLString:object resolve:YES];
				NSAssert1([group isKindOfClass:[GIMessageGroup class]], @"Object is not a GIMessageGroup object: %@", object);
				[children addObject:group];
			}
		}
	}
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[[self objectAtIndex:0] objectForKey:@"name"], @"name",
		[[self objectAtIndex:0] objectForKey:@"uid"], @"uid",
		[NSNumber numberWithInt:[children count]], @"count",
		children, @"children",
		nil, nil];
}

@end

@implementation GIMainWindowController

- (id)init
{
	self = [self initWithWindowNibName:@"MainWindow"];
	
	[GIMessageGroup loadGroupStats];
	
	// receiving update notifications:
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter addObserver:self selector:@selector(groupsChanged:) name:GIMessageGroupWasAddedNotification object:nil];
	[notificationCenter addObserver:self selector:@selector(groupsChanged:) name:GIMessageGroupsChangedNotification object:nil];
	[notificationCenter addObserver:self selector:@selector(groupsChanged:) name:GIMessageGroupStatisticsDidUpdateNotification object:nil];
	[notificationCenter addObserver:self selector:@selector(groupStatsInvalidated:) name:GIMessageGroupStatisticsDidInvalidateNotification object:nil];

	[self loadWindow];

	// configuring message tree view:
	NSDictionary *options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
														forKey:NSAllowsEditingMultipleValuesSelectionBindingOption];
	
	[commentTreeView bind:@"selectedMessage" toObject:threadTreeController withKeyPath:@"selection.self" options:options];
	[commentTreeView setTarget:self];
	[commentTreeView setAction:@selector(commentTreeSelectionChanged:)];
	
	// configuring thread view:
	[threadsOutlineView setHighlightThreads:YES];
	[[self window] makeKeyAndOrderFront:self];
	
	return self;
}

- (void)windowDidLoad
{
	NSLog(@"windowDidLoad");
}

// --- change notification handling ---

- (void)groupsChanged:(NSNotification *)aNotification
{
    [messageGroupTreeController rearrangeObjects];
}

- (void)groupStatsInvalidated:(NSNotification *)aNotification
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(groupsChanged:) object:nil];
    [self performSelector:@selector(groupsChanged:) withObject:nil afterDelay:(NSTimeInterval)5.0];
}

// --- dinding data ---
- (NSArray *)messageGroupHierarchyRoot
{
	return [[[GIMessageGroup hierarchyRootNode] messageGroupHierarchyAsDictionaries] objectForKey:@"children"];
}

- (NSFont *)messageGroupListFont
{
	return [NSFont systemFontOfSize:12.0];
}

- (float)messageGroupListRowHeight
{
	return 18.0;
}

- (NSFont *)threadListFont
{
	return [NSFont systemFontOfSize:12.0];
}

- (float)threadListRowHeight
{
	return 16.0;
}

- (BOOL)isEditable
{
	return NO;
}

// -- handling message tree view selection --
- (IBAction)commentTreeSelectionChanged:(id)sender
{
	GIMessage *message = [commentTreeView selectedMessage];
	
	if (message)
	{
		NSUInteger indexes[2];
		
		indexes[0] = [[threadTreeController selectionIndexPath] indexAtPosition:0];
		indexes[1] = [[[message thread] messagesByTree] indexOfObjectIdenticalTo:message];
		NSAssert(indexes[1] != NSNotFound, @"message should be found");

		NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
		[threadTreeController setSelectionIndexPath:indexPath];
	}
	else
	{
		[threadTreeController setSelectionIndexPaths:[NSArray array]];
	}
}

@end
