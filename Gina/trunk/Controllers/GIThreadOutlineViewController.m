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
#import "GIMessageGroup.h"
#import "GIThread.h"
#import "GIUserDefaultsKeys.h"
#import "NSAttributedString+Extensions.h"
#import "NSString+Extensions.h"
#import "OPPersistentObjectContext.h"
#import "OPPersistentObject.h"
#import "OPPersistentSet.h"

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
	static NSDictionary *fromAttributes = nil;
	
	if (! fromAttributes) 
	{
		fromAttributes = newAttributesWithColor([[NSColor blueColor] shadowWithLevel:0.5]);
	}
	return fromAttributes;
}

static NSDictionary *unreadFromAttributes()
{
	static NSMutableDictionary *unreadFromAttributes = nil;
	
	if (!unreadFromAttributes)
	{
		unreadFromAttributes = [fromAttributes() mutableCopy];
		[unreadFromAttributes setObject:[NSFont boldSystemFontOfSize:12] forKey:NSFontAttributeName];
	}

	return unreadFromAttributes;
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
        spacer = [[NSAttributedString alloc] initWithString:@"      "];
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

#import "OPInternetMessage.h"

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

- (unsigned)threadChildrenCount
{
	return 0;
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
	
	NSDictionary *completeAttributes = (self.flags & OPSeenStatus) ? readFromAttributes() : unreadFromAttributes();

//	NSDictionary *completeAttributes = (self.flags & OPSeenStatus) ? readAttributes() : unreadAttributes();
	
	if (flags & OPJunkMailStatus) 
	{
		completeAttributes = spamMessageAttributes();
	}
	
	[result appendAttributedString:[[[NSAttributedString alloc] initWithString:nilGuard(from) attributes:completeAttributes] autorelease]];
	
	return result;
}

- (NSAttributedString *)messageForDisplay
{
	NSAttributedString *messageText = nil;
	BOOL showRawSource = [[NSUserDefaults standardUserDefaults] boolForKey:ShowRawSource];
	
	if (showRawSource) 
	{
		NSData *transferData = self.internetMessage.transferData;
		NSString *transferString = [NSString stringWithData:transferData encoding:NSUTF8StringEncoding];
		
		// joerg: this is a quick hack (but seems sufficient here) to handle 8 bit transfer encoded messages (body) without having to do the mime parsing
		if (! transferString) 
		{
			transferString = [NSString stringWithData:transferData encoding:NSISOLatin1StringEncoding];
		}
		
		static NSDictionary *fixedFont = nil;
		if (!fixedFont) 
		{
			fixedFont = [[NSDictionary alloc] initWithObjectsAndKeys: [NSFont userFixedPitchFontOfSize:10], NSFontAttributeName, nil, nil];
		}
		
		messageText = [[[NSAttributedString alloc] initWithString:transferString attributes:fixedFont] autorelease]; 
	} 
	else 
	{
		messageText = [self renderedMessageIncludingAllHeaders:[[NSUserDefaults standardUserDefaults] boolForKey:ShowAllHeaders]];
	}
	
	return messageText;
}

- (NSAttributedString *)dateForDisplay
{
	BOOL isRead = [self hasFlags:OPSeenStatus];
	
	NSString *dateString = [timeAndDateFormatter() stringFromDate:self.date];
	
	return [[[NSAttributedString alloc] initWithString:nilGuard(dateString) attributes:isRead ? readAttributes() : unreadAttributes()] autorelease];
}

+ (NSSet *)keyPathsForValuesAffectingSubjectForDisplay
{
	return [NSSet setWithObjects:@"flags", nil];
}

- (NSAttributedString *)subjectForDisplay
{
	BOOL isSeen = [self isSeen];
	
	NSAttributedString *result = [[[NSAttributedString alloc] initWithString:[self subject] attributes:isSeen ? readAttributes() : unreadAttributes()] autorelease];
	return result;
}

+ (NSSet *)keyPathsForValuesAffectingAuthorForDisplay
{
	return [NSSet setWithObjects:@"flags", nil];
}

- (NSAttributedString *)authorForDisplay
{
	NSString *from = nil;
	
	if (self.flags & OPIsFromMeStatus) 
	{
		from = [NSString stringWithFormat:@"%C %@", 0x279F/*Right Arrow*/, self.recipientsForDisplay];
	} 
	else 
	{
		from = [self senderName];
		if (!from.length) from = @"- sender missing -";
		from = [NSString stringWithFormat:@"%@", from];
	}       
	NSDictionary *completeAttributes = ((flags & OPSeenStatus) || (flags & OPIsFromMeStatus)) ? readAttributes() : unreadAttributes();
	
	if (flags & OPJunkMailStatus) 
	{
		completeAttributes = spamMessageAttributes();
	}
	
	NSAttributedString *result = [[NSAttributedString alloc] initWithString:nilGuard(from) attributes:completeAttributes];
	
	return result;
}

+ (NSSet *)keyPathsForValuesAffectingMessageGroupsForDisplay
{
	return [NSSet setWithObjects:@"flags", nil];
}

- (NSAttributedString *)messageGroupsForDisplay
{
	NSMutableString *messageGroupsString = [NSMutableString string];
	BOOL first = YES;
	BOOL isRead = [self hasFlags:OPSeenStatus];
	
	for (GIMessageGroup *group in self.thread.messageGroups)
	{
		if (!first)	[messageGroupsString appendString:@", "];
		else first = NO;
		
		[messageGroupsString appendString:group.name];
	}
	
	return [[[NSAttributedString alloc] initWithString:messageGroupsString attributes:isRead ? readAttributes() : unreadAttributes()] autorelease];
}

- (NSImage *)statusImage
{
	if (!self.isSeen) return [NSImage imageNamed:@"unread"];
	return nil;
}

@end

@implementation GIThread (ThreadViewSupport)

+ (NSSet *)keyPathsForValuesAffectingThreadChildren
{
	return [NSSet setWithObject:@"messages"];
}

+ (NSSet *)keyPathsForValuesAffectingMessagesByTree
{
	return [NSSet setWithObject:@"messages"];
}

+ (NSSet *)keyPathsForValuesAffectingSubjectAndAuthor
{
	return [NSSet setWithObjects: @"messages", @"subject", nil];
}

+ (NSSet *)keyPathsForValuesAffectingDateForDisplay
{
	return [NSSet setWithObjects:@"date", @"isSeen", nil];
}

+ (NSSet *)keyPathsForValuesAffectingStatusImage
{
	return [NSSet setWithObject:@"isSeen"];
}

- (unsigned) threadChildrenCount
{
	return self.messages.count;
}


- (NSArray*) threadChildren
{
	if (self.messages.count > 1) {
		// multi-message thread
		return self.messagesByTree;
	} else {
		// single-message thread
		return nil;
	}
}

- (id)subjectAndAuthor
{
	NSArray* msgs = self.messages;
	
	if ([msgs count] > 1) 
	{
		// multi-message thread
		return [[[NSAttributedString alloc] initWithString:nilGuard(self.subject) attributes:![self isSeen] ? unreadAttributes() : readAttributes()] autorelease];
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
	NSArray *msgs = self.messages;
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
		
		if ([self.messages count] > 0)
		{
			[result appendString:[NSString stringWithFormat:@"\nThread '%@':\n", [[self subjectAndAuthor] string]]];
			[result appendString:[NSString stringWithFormat:@"contains %d messages (%u unread)\n", [[self messages] count], [self unreadMessageCount]]];
		}
		return result;
	}
}

- (NSAttributedString *)dateForDisplay
{
	BOOL isRead = self.isSeen;
	
	NSString *dateString = [timeAndDateFormatter() stringFromDate:self.date];
	
	return [[[NSAttributedString alloc] initWithString:nilGuard(dateString) attributes:isRead ? readAttributes() : unreadAttributes()] autorelease];
}

- (NSImage *)statusImage
{
	if (![self isSeen]) return [NSImage imageNamed:@"unread"];
	return nil;
}

@end

@implementation GIThreadOutlineViewController

- (void) awakeFromNib
{
	// Register to grok GinaThreads drags:
    [outlineView registerForDraggedTypes:[NSArray arrayWithObjects:@"GinaThreads", nil]];
}

- (void) moveSelectionToTrash
/*" Moves the selected threads to the trash group. "*/
{
	GIMessageGroup* trash = [GIMessageGroup trashMessageGroup];
	NSArray* threadsToMove = self.selectedObjects;
	// Select the item at previous first selection index:
	NSUInteger firstSelectedIndex = [self.outlineView.selectedRowIndexes firstIndex];

	[self.outlineView deselectAll: self]; // performance improvement - the controller does not try to keep the selection
	
	NSLog(@"Will move %@ to trash.", threadsToMove);
	for (GIThread* thread in threadsToMove) {
		if ([thread isKindOfClass: [GIThread class]]) {
			//[thread setValue:  forKey: @"messageGroups"];
			NSMutableSet* groups = [thread mutableSetValueForKey: @"messageGroups"];
			[groups setSet: [NSSet setWithObject: trash]];
		}
	}
	
	[self.outlineView selectRow: MIN(firstSelectedIndex, self.outlineView.numberOfRows - 1) byExtendingSelection: NO]; 
}

- (void) setRootItem: (id) newItem
{
	if ([newItem isKindOfClass: [GIMessageGroup class]]) [super setRootItem: newItem];
	else [super setRootItem: nil];
}

//- (void) expandItem: (id) item expandChildren: (BOOL) expandChildren
//{
//	[self setCachesItems: NO];
//	[outlineView expandItem: item expandChildren: expandChildren];
//	[self setCachesItems: YES];	
//}

- (void) restoreSelectionForMessageGroup: (GIMessageGroup*) aGroup
{
	if (!aGroup || ![aGroup isKindOfClass: [GIMessageGroup class]]) return;
		
	// restore selection for message group (root item):
	NSString *groupSelectionDefaultKey = [NSString stringWithFormat:@"GroupSelection-%llu", [(OPPersistentObject *)aGroup oid]];
	NSArray *oidsOfSelectedObjects = [[NSUserDefaults standardUserDefaults] objectForKey:groupSelectionDefaultKey];
	
	NSMutableArray* itemPaths = [NSMutableArray arrayWithCapacity: oidsOfSelectedObjects.count];
	for (NSNumber* oidNumber in oidsOfSelectedObjects) {			
		OPPersistentObject *selectedObject = [[OPPersistentObjectContext defaultContext] objectForOID: [oidNumber OIDValue]];
		if (selectedObject) {
			GIMessage *message = nil;
			GIThread *thread = nil;
			
			if ([selectedObject isKindOfClass: [GIMessage class]]) {
				message = (GIMessage *)selectedObject;
				if ([message.thread messageCount] < 1)  message = nil;
				thread = message.thread;
			} else {
				thread = (GIThread *)selectedObject;
			}
			// thread is now set
			NSArray* itemPath = message ? [NSArray arrayWithObjects: thread, message, nil] : [NSArray arrayWithObject: thread];
			[itemPaths addObject: itemPath];

		} else {
			NSLog(@"warning could not retrieve object with OID: 0x%llx", [oidNumber OIDValue]);
		}
	}
	
	selectionRestoreInProgress = YES; // prevent items to be stored again:
	[self setSelectedItemsPaths: itemPaths byExtendingSelection: NO];
	[outlineView scrollRowToVisible: [[outlineView selectedRowIndexes] lastIndex]];
	selectionRestoreInProgress = NO;
}

- (void)reloadData
/*" Call this instead of calling reloadData on the outline. "*/
{
	[super reloadData];
	[self restoreSelectionForMessageGroup:self.rootItem];
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	[super outlineViewSelectionDidChange:notification];
	
	if ( selectionRestoreInProgress) return;
	
	if (outlineView.dataSource && [self.rootItem isKindOfClass: [OPPersistentObject class]]) 
	{
		// remember selection for messsage group (root item):
		NSArray *selectedObjects = self.selectedObjects;
		
#warning restricted remembering of selected threads to 100 thread max.
		if (selectedObjects.count > 100)
		{
			selectedObjects = [NSArray arrayWithObject:[selectedObjects lastObject]];
		}
		
		NSMutableArray *oidsOfSelectedObjects = [NSMutableArray arrayWithCapacity:[selectedObjects count]];
		for (OPPersistentObject *selectedObject in selectedObjects) 
		{
			if ([selectedObject conformsToProtocol:@protocol(OPPersisting)]) 
			{
				[oidsOfSelectedObjects addObject:[NSNumber numberWithOID:[selectedObject oid]]];
			}
		}
		
		NSString *groupSelectionDefaultKey = [NSString stringWithFormat:@"GroupSelection-%llu", [(OPPersistentObject *)self.rootItem oid]];
		[[NSUserDefaults standardUserDefaults] setObject:oidsOfSelectedObjects forKey:groupSelectionDefaultKey];
	}
	
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
			if ([selectedObject isKindOfClass:[GIMessage class]]) {
				[result addObject:selectedObject];
			}
			//NSAssert([selectedObject isKindOfClass:[GIMessage class]], @"expected a GIMessage object");
		}
	}	
	
	return result;
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


- (NSSet *)keyPathsAffectingDisplayOfItem:(id)item
{
	static NSSet *affectingKeyPaths = nil;
	if (! affectingKeyPaths) 
	{
		affectingKeyPaths = [[NSSet setWithObjects:@"isSeen", nil] retain];
	}
	return affectingKeyPaths;
}

@end

@implementation GIThreadOutlineViewController (OPDragNDrop)

- (NSSet *)threadsOfItems:(NSArray *)items
{
	NSMutableSet *result = [NSMutableSet set];
	
	for (id selectedObject in items)
	{
		if ([selectedObject isKindOfClass:[GIThread class]])
		{
			[result addObject:selectedObject];
		}
		else // assuming GIMessage
		{
			[result addObject:[selectedObject thread]];
		}
	}
	
	return result;
}

- (BOOL)outlineView:(NSOutlineView *)anOutlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{
	NSParameterAssert(outlineView == anOutlineView);
		
//	GIMessageGroup *sourceGroup = [outlineView.dataSource selectedObject];
	
//	if (![sourceGroup isValidUserCopyOrMoveSourceOrDestination]) return NO;
	
	[pboard declareTypes:[NSArray arrayWithObject:@"GinaThreads"] owner:self];
	
	NSSet *threads = [self threadsOfItems:items];
	NSMutableArray *pbItems = [NSMutableArray arrayWithCapacity:[threads count]];
	
	// Numbers with oids as content would have worked as well for internal d&d, propably more efficient
	for (GIThread *thread in threads)
	{
		NSString *url = [thread objectURLString];
		[pbItems addObject:url];
	}
	
	[pboard setPropertyList:pbItems forType:@"GinaThreads"];
    
    return YES;
}


//- (BOOL)outlineView:(NSOutlineView *)anOutlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(int)index
//{
//	NSParameterAssert(outlineView == anOutlineView);
//
//	// move threads from source group to destination group:
//	NSArray *threadURLs = [[info draggingPasteboard] propertyListForType:@"GinaThreads"];
//        GIMessageGroup *sourceGroup = [(GIThreadListController *)[[info draggingSource] delegate] group];
//        GIMessageGroup *destinationGroup = [self group];
//        
//        [GIMessageGroup moveThreadsWithOids:threadOids fromGroup:sourceGroup toGroup:destinationGroup];
//        /*
//		 NSEnumerator *enumerator = [threadURLs objectEnumerator];
//		 NSString *threadURL;
//		 
//		 while (threadURL = [enumerator nextObject])
//		 {
//		 GIThread *thread = [OPPersistentObjectContext objectWithURLString:threadURL];
//		 NSAssert([thread isKindOfClass: [GIThread class]], @"should be a thread");
//		 
//		 // remove thread from source group:
//		 [thread removeGroup:sourceGroup];
//		 
//		 // add thread to destination group:
//		 [thread addGroup:destinationGroup];
//		 }
//		 */
//        
//        // select all in dragging source:
//        NSOutlineView *sourceView = [info draggingSource];        
//        [sourceView selectRow:[sourceView selectedRow] byExtendingSelection:NO];
//        
//        [NSApp saveAction:self];
//    
//    return NO;
//}
//
//- (NSDragOperation)outlineView:(NSOutlineView *)anOutlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)index
//{
//    if (anOutlineView == threadsView) 
//    {
//        if ([info draggingSource] != threadsView) // don't let drop on itself
//        {
//            NSArray *items = [[info draggingPasteboard] propertyListForType:@"GinkoThreads"];
//            
//            if ([items count] > 0) 
//            {
//                [anOutlineView setDropItem:nil dropChildIndex:-1]; 
//                return NSDragOperationMove;
//            }
//        }
//    }
//    
//    return NSDragOperationNone;
//}
//

@end

#import "GIMessageBase.h"

@implementation NSMetadataItem (GinkoExtensions)

- (GIMessage *)message
{
	OPPersistentObjectContext *context = [OPPersistentObjectContext defaultContext];
	
	NSString *filename = [self valueForAttribute:(NSString *)kMDItemFSName];
	OID oid = [context oidFromMessageFilename:filename];
	GIMessage *result = [context objectForOID:oid];
	return result;
}

- (NSDate *)date
{
	return [self valueForAttribute:(NSString *)kMDItemContentCreationDate];
}

- (NSString *)author
{
	return [[self valueForAttribute:(NSString *)kMDItemAuthors] lastObject];
}

- (NSString *)subject
{
	return [self valueForAttribute:(NSString *)kMDItemSubject];
}

@end

@implementation GIThreadOutlineView

- (NSImage *)dragImageForRowsWithIndexes:(NSIndexSet *)dragRows tableColumns:(NSArray *)tableColumns event:(NSEvent *)dragEvent offset:(NSPointPointer)dragImageOffset
{
	// TODO: pimp the drag image by adding a badge with numbers of threads/messages being dragged
	return [NSImage imageNamed:@"drag"];
}

@end