//
//  GinkoVoyager
//
//  Created by Axel Katerbau on 03.12.04.
//  Copyright 2004, 2005 Objectpark.org. All rights reserved.
//

#import "GIThreadListController.h"
#import "GIMessage+Rendering.h"
#import "GIThread.h"
#import "GICommentTreeCell.h"
#import <Foundation/NSDebug.h>
#import "NSToolbar+OPExtensions.h"
#import "GIMessageEditorController.h"
#import "GIProfile.h"
#import "OPCollapsingSplitView.h"
#import "GIUserDefaultsKeys.h"
#import "GIApplication.h"
#import "NSArray+Extensions.h"
#import "NSEnumerator+Extensions.h"
#import "GIGroupInspectorController.h"
#import "OPPersistentObject+Extensions.h"
#import "GIMessageGroup.h"
#import "OPJobs.h"
#import "GIFulltextIndex.h"
#import "GIOutlineViewWithKeyboardSupport.h"
#import "GIMessage.h"
#import "GIMessageBase.h"
#import "NSString+MessageUtils.h"
#import "GIMessageFilter.h"
#import "OPPersistence.h"
#import "OPObjectPair.h"
#import "GIMessageGroup+Statistics.h"
#import "NSAttributedString+MessageUtils.h"

static NSString *ShowOnlyRecentThreads = @"ShowOnlyRecentThreads";

@interface GIThreadListController (CommentsTree)

- (void)awakeCommentTree;
- (void)deallocCommentTree;
- (IBAction)selectTreeCell:(id)sender;
- (void)updateCommentTree:(BOOL)rebuildThread;
- (BOOL)matrixIsVisible;

@end


@implementation GIThreadListController

- (id)init
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(modelChanged:) name:@"GroupContentChangedNotification" object:self];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(modelChanged:) name:OPJobDidFinishNotification object:MboxImportJobName];
    
    itemRetainer = [[NSMutableSet alloc] init];
    //observedThreads = [[NSMutableSet alloc] init];
    
    return [[super init] retain]; // self retaining!
}

- (id)initWithGroup:(GIMessageGroup *)aGroup
/*" aGroup may be nil, any group will be used then. "*/
{
    if (self = [self init]) 
    {
        if (! aGroup) 
        {
			aGroup = [[GIMessageGroup allObjects] lastObject];
        }
		
		[NSBundle loadNibNamed:@"Group" owner:self]; // sets threadsView
		[self setGroup:aGroup];
    }
    
    return self;
}

- (void) updateWindowTitle
{
    [window setTitle:[NSString stringWithFormat:@"%@", [group valueForKey: @"name"]]];
}

static NSPoint lastTopLeftPoint = {0.0, 0.0};

- (void)awakeFromNib
{    
    [threadsView setTarget:self];
    [threadsView setDoubleAction:@selector(openSelection:)];
    [threadsView setHighlightThreads:YES];
    [threadsView registerForDraggedTypes:[NSArray arrayWithObjects:@"GinkoThreads", nil]];
    ///[threadsView setIndentationPerLevel:1.0];
	
    [searchHitsTableView setTarget:self];
    [searchHitsTableView setDoubleAction:@selector(openSelection:)];

    // configure search hit date formatter:
    [searchHitDateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [searchHitDateFormatter setDateStyle:NSDateFormatterShortStyle];
    [searchHitDateFormatter setTimeStyle:NSDateFormatterShortStyle];
    
    [self awakeToolbar];
    [self awakeCommentTree];

    lastTopLeftPoint = [window cascadeTopLeftFromPoint:lastTopLeftPoint];
    
    [window makeKeyAndOrderFront:self];    
	[self updateWindowTitle];
}

- (void)dealloc
{
    if (NSDebugEnabled) NSLog(@"GIThreadListController dealloc");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [window setDelegate:nil];
    
    [self deallocCommentTree];
    [self deallocToolbar];

    [displayedMessage release];
	
	[displayedThread removeObserver:self forKeyPath:@"messages"];
    [displayedThread release];
    [border release];
	
	//[[observedThreads objectEnumerator] makeObjectsPerformSelector:@selector(removeObserver:forKeyPath:)
    //														withObject:self
	//													withObject:@"messages"];
	//[observedThreads release];
	
    [self setGroup:nil];
    [itemRetainer release];
    [hits release];
    
    [super dealloc];
}

static BOOL isThreadItem(id item)
{
    return [item isKindOfClass:[GIThread class]];
}

- (id)valueForGroupProperty:(NSString *)prop
/*" Used for accessing user defaults for current message group. "*/
{
    NSString *key = [[self group] objectURLString];
    if (key) 
    {
        return [[[NSUserDefaults standardUserDefaults] objectForKey:key] objectForKey:prop];
    }
    return nil;
}

- (void)setValue:(id)value forGroupProperty:(NSString *)prop 
/*" Used for accessing user defaults for current message group. "*/
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString *key = [[self group] objectURLString];
    
    NSMutableDictionary *groupProperties = [[ud objectForKey:key] mutableCopy];
    if (!groupProperties) groupProperties = [[NSMutableDictionary alloc] init];
    
    if (value) [groupProperties setObject:value forKey:prop];
    else [groupProperties removeObjectForKey:prop];
    
    [ud setObject:groupProperties forKey:key];
    [groupProperties release];
}

- (void)windowWillClose:(NSNotification *)notification 
{
    lastTopLeftPoint = NSMakePoint(0.0, 0.0); // reset cascading
	[self setGroup:nil];
    [self autorelease]; // balance self-retaining
}

- (NSArray*) threadsByDate
    /*" Returns an ordered list of all message threads of the receiver, ordered by date. "*/
{
	return [group valueForKey: @"threadsByDate"];
}

- (int) threadLimitCount 
{
#warning optimization in -threadLimitCount removed.
	//if (!recentThreadsCache) {
		BOOL showOnlyRecentThreads = [[self valueForGroupProperty: ShowOnlyRecentThreads] boolValue];	
		recentThreadsCache = showOnlyRecentThreads ? recentThreadsCache = 150 : INT_MAX;
	//}
	return recentThreadsCache;
}

- (BOOL) threadByDateSortAscending
{
	return YES;
}

- (void) showMessageInThreadList: (GIMessage*) aMessage
{
	if (aMessage) {
		GIThread* thread = [aMessage valueForKey: @"thread"];
		int itemRow;
		
		// make sure that thread is expanded in threads outline view:
		if (thread && (![thread containsSingleMessage]))  {
			[threadsView expandItem:thread];
		}
		
		// select responding item in threads view:
		
		NSArray *threadArray = [self threadsByDate];
		
		itemRow = [threadArray indexOfObject:thread]; // estimation!
		
		/*
		 if ([self threadByDateSortAscending])
		 {
			 itemRow += ([threadArray count]-MIN([self threadLimitCount], [[self threadsByDate] count]));
		 }
		 else
		 {
			 itemRow = ([threadArray count]-1) - itemRow;
		 }
		 */
		
		if ([self threadLimitCount] != INT_MAX) itemRow = 0;
		
		itemRow = [threadsView rowForItemEqualTo:([thread containsSingleMessage] ? (id)thread : (id)aMessage) startingAtRow:itemRow];
		
		if (itemRow != -1) {
			[threadsView selectRow:itemRow byExtendingSelection:NO];
			[threadsView scrollRowToVisible:itemRow];
		}
	}
}

- (void)setDisplayedMessage:(GIMessage *)aMessage thread:(GIThread *)aThread
/*" Central method for detail viewing of a message aMessage in a thread aThread. "*/
{
	if (!aThread) aThread = [aMessage valueForKey:@"thread"];
	
	NSParameterAssert(aThread==nil || isThreadItem(aThread));
	
	BOOL isNewThread = ![aThread isEqual:displayedThread];
	
	[displayedMessage autorelease];
	displayedMessage = [aMessage retain];

	[displayedMessage addFlags: OPSeenStatus];
	
	if (isNewThread) {
		[displayedThread removeObserver: self forKeyPath: @"messages"];
		[displayedThread autorelease];
		displayedThread = [aThread retain];
		[displayedThread addObserver: self 
						  forKeyPath: @"messages" 
							 options: NSKeyValueObservingOptionNew 
							 context: NULL];		
	}
	
	if (aMessage) {
		[self showMessageInThreadList: aMessage];
		
		// message display string:
		NSAttributedString* messageText = nil;
		
		if (showRawSource) {
			NSData* transferData = [displayedMessage transferData];
			NSString* transferString = [NSString stringWithData: transferData encoding: NSUTF8StringEncoding];
			
			static NSDictionary* fixedFont = nil;
			
			if (!fixedFont) {
				fixedFont = [[NSDictionary alloc] initWithObjectsAndKeys: [NSFont userFixedPitchFontOfSize:10], NSFontAttributeName, nil, nil];
			}
			
			// joerg: this is a quick hack (but seems sufficient here) to handle 8 bit transfer encoded messages (body) without having to do the mime parsing
			if (! transferString) {
				transferString = [NSString stringWithData: transferData encoding: NSISOLatin1StringEncoding];
			}
			
			messageText = [[[NSAttributedString alloc] initWithString:transferString attributes: fixedFont] autorelease]; 
		} else {
			messageText = [displayedMessage renderedMessageIncludingAllHeaders:[[NSUserDefaults standardUserDefaults] boolForKey:ShowAllHeaders]];
		}
		
		if (!messageText) {
			messageText = [[NSAttributedString alloc] initWithString: @"Warning: Unable to decode message. messageText == nil."];
		}
		
		[[messageTextView textStorage] setAttributedString: messageText];
		
		// set the insertion point (cursor)to 0, 0
		[messageTextView setSelectedRange: NSMakeRange(0, 0)];
		[messageTextView sizeToFit];
		// make sure that the message's header is displayed:
		[messageTextView scrollRangeToVisible: NSMakeRange(0, 0)];
		
		[self updateCommentTree: isNewThread];
	} else {
		// Clear the content:
		[[messageTextView textStorage] replaceCharactersInRange: NSMakeRange(0, [[messageTextView textStorage] length]) withString: @""];
	}
	
	[displayedMessage addFlags: OPSeenStatus];
}

- (GIMessage*) displayedMessage
{
    return displayedMessage;
}

- (GIThread*) displayedThread
{
    return displayedThread;
}

+ (NSWindow *)windowForGroup:(GIMessageGroup *)aGroup
/*" Returns the window for the group aGroup. nil if no such window exists. "*/
{
    NSWindow* win;
    NSEnumerator* enumerator = [[NSApp windows] objectEnumerator];
    while (win = [enumerator nextObject]) {
        if ([[win delegate] isKindOfClass:self]) {
            if ([[win delegate] group] == aGroup) return win;
        }
    }
    
    return nil;
}

- (NSWindow*) window 
{
    return window;
}

- (void) observeValueForKeyPath: (NSString*) keyPath 
					   ofObject: (id) object 
						 change: (NSDictionary*) change 
						context: (void*) context
{
	if ([keyPath isEqualToString: @"messages"]) {
		
		if (object == displayedThread) {
			[self updateCommentTree: YES];
		}
		[threadsView reloadItem: object reloadChildren: YES];
		
	} else if ([object isEqual: [self group]] && isAutoReloadEnabled) {
		
		[threadsView noteNumberOfRowsChanged]; // make sure, we are not called back with illegal indexes
		
        NSNotification* notification = [NSNotification notificationWithName: @"GroupContentChangedNotification" object: self];
        
        //NSLog(@"observeValueForKeyPath %@", keyPath);

        [[NSNotificationQueue defaultQueue] enqueueNotification: notification 
												   postingStyle: NSPostWhenIdle 
												   coalesceMask: NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender 
													   forModes: nil];
    }
}

- (NSTimeInterval) nowForThreadFiltering
{
    if (![[self valueForGroupProperty: ShowOnlyRecentThreads] intValue]) return 0;
    
    if (nowForThreadFiltering == 0) {
        nowForThreadFiltering = [[NSDate date] timeIntervalSinceReferenceDate] - 60 * 60 * 24 * 28;
    }
    return nowForThreadFiltering;
}

- (BOOL) isThreadlistShownCurrently
/*" Returns YES if the tab with the threads outline view is currently visible. NO otherwise. "*/
{
    return [[[tabView selectedTabViewItem] identifier] isEqualToString:@"threads"];
}

- (BOOL) isSearchShownCurrently
/*" Returns YES if the tab with the search results is currently visible. NO otherwise. "*/
{
    return (hits != nil);
}

- (BOOL) isMessageShownCurrently
/*" Returns YES if the tab with the message is currently visible. NO otherwise. "*/
{
    return [[[tabView selectedTabViewItem] identifier] isEqualToString:@"message"];
}

- (BOOL)openSelection:(id)sender
{    
    if ([self isThreadlistShownCurrently]) 
    {
        int selectedRow = [threadsView selectedRow];
        
        if (selectedRow >= 0) 
        {
            GIMessage *message = nil;
            GIThread *selectedThread = nil;
            id item = [threadsView itemAtRow:selectedRow];
            
            if (!isThreadItem(item)) 
            {
                // it's a message, show it:
                message = item;
                // find the thread above message:
                selectedThread = [message valueForKey:@"thread"];
            } 
            else 
            {
                selectedThread = item;
                
                if ([selectedThread containsSingleMessage]) 
                {
                    message = [[selectedThread valueForKey:@"messages"] lastObject];
                } 
                else 
                {
                    if ([threadsView isItemExpanded:item]) 
                    {
                        [threadsView collapseItem:item];
                    } 
                    else 
                    {                        
                        [threadsView expandItem:item];                    
                        // ##TODO:select first "interesting" message of this thread
                        // perhaps the next/first unread message
                        
						/* Do this on hitting "space" only:
                        NSEnumerator *enumerator = [[selectedThread messagesByTree] objectEnumerator];
						GIMessage *message;

                        while (message = [enumerator nextObject]) 
                        {
                            if (! [message hasFlags:OPSeenStatus]) 
                            {
                                [threadsView selectRowIndexes:[NSIndexSet indexSetWithIndex:[threadsView rowForItem:message]] byExtendingSelection:NO];
                                break;
                            }
                        }
                        
                        if (! message) 
                        {
                            // if no message found select last one:
                            [threadsView selectRowIndexes:[NSIndexSet indexSetWithIndex:[threadsView rowForItem:[[selectedThread messagesByTree] lastObject]]] byExtendingSelection:NO];   
                        }
                        
                        // make selection visible:
                        [threadsView scrollRowToVisible:[threadsView selectedRow]];
						*/
                    }
                    return YES;
                }
            }
            
			unsigned messageSendStatus = [message sendStatus];
            if (messageSendStatus > OPSendStatusNone) 
            {
                if (messageSendStatus >= OPSendStatusSending) 
                {
					NSLog(@"message is in send job"); // replace by alert
                    NSBeep();
                } 
                else 
                {
                    [[[GIMessageEditorController alloc] initWithMessage:message] autorelease];
                }
            } 
            else 
            {
				
				[self setDisplayedMessage: nil thread: nil];

                [tabView selectTabViewItemWithIdentifier:@"message"];
                
                //[message addFlags:OPSeenStatus];
                
                [self setDisplayedMessage:message thread:selectedThread];
                
                //if ([self matrixIsVisible]) [window makeFirstResponder:commentsMatrix];
                //else 
				[window makeFirstResponder:messageTextView];                    
            }
        }
		
	} 
    else if ([self isSearchShownCurrently]) 
    {
        int selectedIndex = [searchHitsTableView selectedRow];
        
        if ((selectedIndex >= 0) && (selectedIndex < [hits count])) 
        {
            GIMessage *message = [[[hits sortedArrayUsingDescriptors:[searchHitsTableView sortDescriptors]] objectAtIndex:selectedIndex] objectForKey:@"message"];
            
			unsigned messageSendStatus = [message sendStatus];
            if (messageSendStatus > OPSendStatusNone) 
            {
                if (messageSendStatus >= OPSendStatusSending) 
                {
                    NSLog(@"message is in send job");
                    NSBeep();
                } 
                else 
                {
                    [[[GIMessageEditorController alloc] initWithMessage:message] autorelease];
                }
            } 
            else 
            {
                [tabView selectTabViewItemWithIdentifier:@"message"];
                
                //[message addFlags: OPSeenStatus];
                GIThread *thread = [message thread];
                [self setDisplayedMessage:message thread:thread];
                
                if ([self matrixIsVisible]) [window makeFirstResponder:commentsMatrix];
                else [window makeFirstResponder:messageTextView];                    
            }       
        }
    } 
    else if ([self isMessageShownCurrently])
    {
		// message shown
        if ([window firstResponder] == commentsMatrix) [window makeFirstResponder:messageTextView];
        else [window makeFirstResponder:commentsMatrix];
    }
    return YES;
}

- (IBAction) closeSelection: (id) sender
{
    if (sender == messageTextView) {
        if ([self isSearchShownCurrently]) [tabView selectTabViewItemWithIdentifier:@"searchresult"];
        else [tabView selectTabViewItemWithIdentifier:@"threads"];
    } else {
        if ([[[tabView selectedTabViewItem] identifier] isEqualToString:@"message"]) {
            // From message switch back to threads:
            if ([self isSearchShownCurrently]) [tabView selectTabViewItemWithIdentifier:@"searchresult"];
            else [tabView selectTabViewItemWithIdentifier:@"threads"];
        } else if ([[[tabView selectedTabViewItem] identifier] isEqualToString:@"searchresult"]) {
			// From search hits, remove search term and switch back to thread list:
			[searchField setStringValue: @""]; [self search: nil];
		} else {
            // From threads switch back to the groups window:
            [[GIApp groupsWindow] makeKeyAndOrderFront:sender];
            [window performClose:self];
        }
    }
}

// actions

- (void)placeSelectedTextOnQuotePasteboard
{
    NSArray *types = [messageTextView writablePasteboardTypes];
    NSPasteboard *quotePasteboard = [NSPasteboard pasteboardWithName:@"QuotePasteboard"];
    
    [quotePasteboard declareTypes:types owner:nil];
    [messageTextView writeSelectionToPasteboard:quotePasteboard types:types];
}

- (GIMessage *)selectedMessage
/*" Returns selected message, iff one message is selected. nil otherwise. "*/
{
	if ([self isSearchShownCurrently]) 
    {
        int selectedIndex = [searchHitsTableView selectedRow];
        
        if ((selectedIndex >= 0) && (selectedIndex < [hits count])) 
        {
            GIMessage *message = [[[hits sortedArrayUsingDescriptors:[searchHitsTableView sortDescriptors]] objectAtIndex:selectedIndex] objectForKey:@"message"];
			
			return message;
		}
		
		return nil;
	}
	else
	{
		GIMessage *result = nil;
		id item = [threadsView itemAtRow:[threadsView selectedRow]];
		
		if ([item isKindOfClass:[GIMessage class]]) 
		{
			result = item;
		} 
		else
		{
			result = [[item messagesByTree] lastObject];
		}    
		
		return result;
	}
}

- (GIProfile *)profileForMessage:(GIMessage *)aMessage
/*" Return the profile to use for email replies. Tries first to guess a profile based on the replied email. If no matching profile can be found, the group default profile is chosen. May return nil in case of no group default and no match present. "*/
{
    GIProfile *result;
    
    result = [GIProfile guessedProfileForReplyingToMessage:[aMessage internetMessage]];
    
    if (!result)
    {
        result = [[self group] defaultProfile];
    }
    
    return result;
}

- (IBAction)replySender:(id)sender
{
    GIMessage* message = [self selectedMessage];
    
    [self placeSelectedTextOnQuotePasteboard];
    
    [[[GIMessageEditorController alloc] initReplyTo:message all:NO profile: [self profileForMessage:message]] autorelease];
}

- (IBAction)followup:(id)sender
{
    GIMessage *message = [self selectedMessage];
    
    [self placeSelectedTextOnQuotePasteboard];
    
    [[[GIMessageEditorController alloc] initFollowupTo:message profile: [[self group] defaultProfile]] autorelease];
}

- (IBAction)replyAll:(id)sender
{
    GIMessage* message = [self selectedMessage];
    
    [self placeSelectedTextOnQuotePasteboard];
    
    [[[GIMessageEditorController alloc] initReplyTo:message all: YES profile: [self profileForMessage: message]] autorelease];
}

- (IBAction)replyDefault:(id)sender
{
    GIMessage *message = [self selectedMessage];

    if ([message isListMessage] || [message isUsenetMessage]) {
        [self followup:sender];
    } else {
        [self replySender:sender];
    }
}

- (IBAction)forward:(id)sender
{
    GIMessage *message = [self selectedMessage];
        
    [[[GIMessageEditorController alloc] initForward: message profile: [self profileForMessage: message]] autorelease];
}

- (IBAction)applySortingAndFiltering:(id)sender
/*" Applies sorting and filtering to the selected threads. The selected threads are removed from the receivers group and only added again if they fit in no group defined by sorting and filtering. "*/
{
    NSIndexSet *selectedIndexes = [threadsView selectedRowIndexes];
    int lastIndex = [selectedIndexes lastIndex];
    int firstIndex = [selectedIndexes firstIndex];
    int i;
	
    for (i = firstIndex; i <= lastIndex; i++) 
	{
        if ([threadsView isRowSelected: i]) 
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            // get one of the selected threads:
            GIThread *thread = [threadsView itemAtRow: i];
			
			// Skip messages - should we apply to message also or to the messages' thread?
			if (isThreadItem(thread)) 
			{
				// Remove selected thread from receiver's group:
				[[self group] removeValue:thread forKey:@"threadsByDate"];

				BOOL threadWasPutIntoAtLeastOneGroup = NO;
				
				@try 
				{
					// apply sorters and filters (and readd threads that have no fit to avoid dangling threads):
					NSEnumerator *enumerator = [[thread messages] objectEnumerator];
					GIMessage *message;
					
					while (message = [enumerator nextObject])
					{
						threadWasPutIntoAtLeastOneGroup |= [GIMessageFilter filterMessage: message flags: 0];
					}
				} 
				@catch (NSException *localException) 
				{
					@throw;
				} 
				@finally 
				{
					if (!threadWasPutIntoAtLeastOneGroup) 
					{
						//[[self group] addValue: thread forKey: @"threadsByDate"];
						[thread addToGroups_Manually:[self group]]; // does dupe-check
					}
				}
				[pool release];
			}
		}
	}
    // commit changes:
    [NSApp saveAction:self];
    [threadsView selectRow:firstIndex byExtendingSelection:NO];
    [threadsView scrollRowToVisible:firstIndex];
}

- (IBAction)threadFilterPopUpChanged:(id)sender
{
    if (NSDebugEnabled) NSLog(@"-threadFilterPopUpChanged:");

    nowForThreadFiltering = 0;
	
	recentThreadsCache = 0; // clear cache
	
    // boolean value:
    [self setValue: [NSNumber numberWithInt:[[threadFilterPopUp selectedItem] tag]] forGroupProperty:ShowOnlyRecentThreads];

    [self modelChanged:nil];
}

- (NSArray *)hits
{
    return hits;
}

- (void)setHits:(NSArray *)someHits
{
    if (hits != someHits) 
    {
        [hits release];
        hits = [someHits retain];
    }
}

- (IBAction) search: (id) sender
{
    if (!searchField) searchField = sender;
    
    NSString* query = [searchField stringValue];
    
    if ([query length]) {
        @try {
            [OPJobs suspendPendingJobs];
            
            NSArray *conflictingJobs = [OPJobs runningJobsWithName:[GIFulltextIndex jobName]];
            if ([conflictingJobs count]) {
                NSEnumerator *enumerator = [conflictingJobs objectEnumerator];
                NSNumber *jobId;
                
                while (jobId = [enumerator nextObject]) {
                    [OPJobs suggestTerminatingJob:jobId];
                }
            }
            
            [tabView selectTabViewItemWithIdentifier:@"searchresult"];
            
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            BOOL limitSearchToGroup = [defaults integerForKey: @"searchRange"] == 1;
            int defaultFieldTag = [defaults integerForKey: @"defaultSearchField"];
            int searchLimit = [defaults integerForKey:SearchHitLimit];
            
            NSString *defaultField = @"body";
            switch (defaultFieldTag) {
                case 0: {
                    static NSArray *allFields = nil;
                    if (!allFields) {
                        allFields = [[NSArray alloc] initWithObjects:@"body", @"subject", @"author", @"recipients", nil];
                    }
                    
                    NSEnumerator *enumerator = [allFields objectEnumerator];
                    NSString *fieldName;
                    NSString *allQuery = @"";
                    while (fieldName = [enumerator nextObject]) {
                        allQuery = [allQuery stringByAppendingFormat:@"%@:(%@) ", fieldName, query];
                    }
                    query = allQuery;
                    
                    break;
                }
                case 1: defaultField = @"body"; break;
                case 2: defaultField = @"subject"; break;
                case 3: defaultField = @"author"; break;
                case 4: defaultField = @"recipients"; break;
                default: break;
            }
            
            NSLog(@"query = %@", query);
            
            [self setHits:[GIFulltextIndex hitsForQueryString:query defaultField:defaultField group:limitSearchToGroup ? [self group] : nil limit:searchLimit]];
            
            if (NSDebugEnabled) NSLog(@"hits count = %d", [hits count]);
            
            [searchHitsTableView reloadData];
        } @catch (NSException *localException) {
            @throw;
        } @finally {
            [OPJobs resumePendingJobs];
        }
    } else {
        [self setHits: nil];
        [tabView selectTabViewItemWithIdentifier: @"threads"];
		//NSView* view = [[tabView selectedTabViewItem] view];
		[window makeFirstResponder: threadsView];
    }
}

- (IBAction)showThreads:(id)sender
{
    [tabView selectFirstTabViewItem:sender];
}

- (IBAction)showRawSource:(id)sender
{
    showRawSource = !showRawSource;
    
	if (displayedMessage && displayedThread) 
    {
        [self setDisplayedMessage:displayedMessage thread:displayedThread];
    }
}

- (NSArray *)allSelectedMessages
{
    NSMutableArray *result = [NSMutableArray array];
    NSIndexSet *selectedIndexes = [threadsView selectedRowIndexes];
    
    if (! [selectedIndexes count]) return [NSArray array];
    
    unsigned int i = [selectedIndexes firstIndex];
    
    do {
        id item = [threadsView itemAtRow:i];
        
        if ([item isKindOfClass:[GIMessage class]])
        {
            [result addObject:item];
        }
        else
        {
            // it's a thread:
            GIThread* thread = item;
            NSEnumerator* enumerator = [[thread messages] objectEnumerator];
            GIMessage* message;
            
            while (message = [enumerator nextObject]) {
                [result addObject:message];
            }
        }
        
        i = [selectedIndexes indexGreaterThanIndex:i];
    }
    while (i != NSNotFound);
    
    return result;
}

- (BOOL)isAnySelectedItemNotHavingMessageflag:(NSString *)attributeName allSelectedMessages:(NSArray **)allMessages
{
    (*allMessages) = [self allSelectedMessages];
    NSEnumerator *enumerator = [(*allMessages) objectEnumerator];
    GIMessage *message;
    
    while (message = [enumerator nextObject]) 
    {
        if (![[message valueForKey:attributeName] boolValue]) return YES;
    }
    
    return NO;
}

- (void)toggleFlag:(NSString *)attributeName
{
    NSParameterAssert(attributeName != nil);
    
    NSArray *selectedMessages;
    BOOL set = [self isAnySelectedItemNotHavingMessageflag:attributeName 
                                       allSelectedMessages:&selectedMessages];
    NSEnumerator *enumerator = [selectedMessages objectEnumerator];
    GIMessage *message;
    NSNumber *setNumber = [NSNumber numberWithBool:set];
    
    while (message = [enumerator nextObject]) 
    {
        [message setValue:setNumber forKey:attributeName];
        /*
        if (set) [message addFlags:flag];
        else [message removeFlags:flag];
		[threadsView reloadItem:message reloadChildren:NO];
         */
    }
    
    [GIApp saveAction:self];
    
    [[self group] invalidateStatistics];
    
    // not necessary if flag changes would be recognized automatically:
    [threadsView reloadData];
}

- (IBAction)toggleReadFlag:(id)sender
{
    [self toggleFlag:@"isSeen"];
}

- (IBAction)toggleJunkFlag:(id)sender
{
    [self toggleFlag:@"isJunk"];
}

- (NSArray *)selectedThreads
/*" Returns a newly created array of threads selected. "*/
{
    NSMutableArray *result = [NSMutableArray array];
    NSIndexSet *set = [threadsView selectedRowIndexes];
	
    if ([set count]) 
    {
        int lastIndex = [set lastIndex];
        int i;
        for (i = [set firstIndex]; i<=lastIndex; i++) 
        {
            if ([set containsIndex: i]) 
            { // Is it a thread?
				id item = [threadsView itemAtRow:i];

                if (isThreadItem(item)) [result addObject:item];
            }
        }
    }
    return result;
}

- (void)cancelAutoReload
{
	isAutoReloadEnabled = NO;
}

- (void) reload
{
	NSLog(@"Reloading outlineview data");
	// Alternative to 
	NSLog(@"Statistics before reload: %@", [OPPersistentObjectContext defaultContext]);	
	[itemRetainer release]; itemRetainer = [[NSMutableSet alloc] init];
	isAutoReloadEnabled = YES;
	[threadsView reloadData];
	NSLog(@"Statistics after reload: %@", [OPPersistentObjectContext defaultContext]);
	
	
	/*
	 NSEnumerator* e = [itemRetainer objectEnumerator];
	 
	 id item;
	 while (item=[e nextObject]) {
		 [threadsView reloadItem: item reloadChildren: YES];
	 }
	 [threadsView noteNumberOfRowsChanged];
	 */
}


- (void) joinThreads
{
	unsigned targetRow = [[threadsView selectedRowIndexes] lastIndex];
	NSArray* selectedThreads = [self selectedThreads];
    //NSEnumerator* enumerator = [selectedThreads objectEnumerator];
//    GIThread* targetThread = [enumerator nextObject];
//	// Find the most recent thread and store it in targetThread. This thread object will survive.
//	GIThread* nextThread;
//	while (nextThread = [enumerator nextObject]) {
//		if ([[nextThread valueForKey: @"date"] compare: [targetThread valueForKey: @"date"]]>0) {
//			targetThread = nextThread; // aThread is nore recent
//		}
//	}
	GIThread* targetThread = [threadsView itemAtRow: targetRow]; // newest, with current, fixes sort order

    NSLog(@"Merging other threads into %@", targetThread);    
    
	NSEnumerator* enumerator = [selectedThreads objectEnumerator];
	GIThread* nextThread;

	[self cancelAutoReload];
    while (nextThread = [enumerator nextObject]) {
		if (nextThread != targetThread) {
			[threadsView collapseItem: nextThread]; // just to be sure
			[targetThread mergeMessagesFromThread: nextThread];
		}
	}
	[self reload];
	[threadsView expandItem: targetThread];
	targetRow = [threadsView rowForItem: targetThread];
	[threadsView selectRow: targetRow byExtendingSelection: NO];
	[threadsView scrollRowToVisible: targetRow + [[targetThread valueForKey: @"messages"] count]];
	[threadsView scrollRowToVisible: targetRow];
    
    [GIApp saveAction: self];
}

- (IBAction)selectThreadsWithCurrentSubject:(id)sender
/*" Joins all threads with the subject of the selected thread. "*/
{
    NSArray* selectedThreads = [self selectedThreads];
    if ([selectedThreads count]) {
        GIThread* thread = [selectedThreads objectAtIndex: 0];
        NSString* subject = [thread valueForKey: @"subject"];
        if (subject) {
            // query database
            NSArray* result;
			result = [[self group] fetchThreadsNewerThan: 0.0
											 withSubject: subject
												  author: nil 
								   sortedByDateAscending: YES];

            [threadsView selectItems: result ordered: YES];
        }
    }
}

- (IBAction) joinThreads:(id)sender
/*" Joins the selected threads into one. "*/
{
    [self joinThreads];
}


- (IBAction) extractThread:(id)sender
/*" Creates a new thread for the selected messages. "*/
{
	NSArray* items = [threadsView selectedItems];
	if ([items count]) {
		NSEnumerator* soe = [items objectEnumerator];
		NSMutableArray* newThreadMessages = [NSMutableArray arrayWithCapacity: [items count]+2];
		NSMutableSet* affectedThreads = [NSMutableSet set];
		
		id item;
		while (item = [soe nextObject]) {
			if (!isThreadItem(item)) {
				[item addOrderedSubthreadToArray: newThreadMessages];
				[affectedThreads addObject: [item thread]];
			} // ignore selected threads
		}
		
		GIMessage* anyThreadMessage = [newThreadMessages lastObject];
		
		if (anyThreadMessage) {
			[anyThreadMessage setValue: nil forKey: @"thread"];
			GIThread* newThread = [GIThread threadForMessage: anyThreadMessage];
			//[newThread insertIntoContext: [(GIMessage*)[newThreadMessages lastObject] context]];
			[newThread addMessages: newThreadMessages];
			//[group addValue: newThread forKey: @"messagesByDate"];
			[newThread addToGroups_Manually: group];
			[newThread calculateDate];
			[affectedThreads makeObjectsPerformSelector: @selector(calculateDate)];
		}
	}
}

- (IBAction)repairInReplyTo:(id)sender
{
	NSLog(@"Trying repair...");
	NSAttributedString *content = [[self displayedMessage] renderedMessageIncludingAllHeaders:NO];
	
	NSString *TOFUQuote = [content firstLevelMicrosoftTOFUQuote];
	
	NSLog(@"TOFU Quote = '%@'", TOFUQuote);
}

- (IBAction)moveSelectionToTrash:(id)sender
{
    int rowBefore = [[threadsView selectedRowIndexes] firstIndex];
    NSEnumerator *enumerator = [[threadsView selectedItems] objectEnumerator];
    id item;
    BOOL trashedAtLeastOne = NO;
	NSMutableDictionary *oldNewThreadDictionary = nil;
	GIMessageGroup *trash = [GIMessageGroup trashMessageGroup];
    
	// Make sure, update notifications do not try to re-select threads that no longer exist:
	[threadsView deselectAll:nil]; 
    
    while (item = [enumerator nextObject]) 
	{
		if (isThreadItem(item)) // trashing a thread:
		{
			[GIMessageBase addTrashThread:item];
			[[self group] removeValue:item forKey:@"threadsByDate"];
			trashedAtLeastOne = YES;	
		} 
		else // trashing a message
		{
			
			if (![[[item thread] valueForKey:@"groups"] containsObject:trash]) 
			{
				if (!oldNewThreadDictionary) oldNewThreadDictionary = [NSMutableDictionary dictionary];
				GIThread *newThread = [oldNewThreadDictionary objectForKey:[item thread]];
				if (!newThread) 
				{
					// Create new thread for all messages from the same thread:
					newThread = [[[[GIThread class] alloc] init] autorelease];
					[newThread insertIntoContext: [(GIMessage*)item context]];
					// xxx
					[oldNewThreadDictionary setObject: newThread forKey: [item thread]]; // *** -[GIThread copyWithZone:]: selector not recognized 
					[GIMessageBase addTrashThread: newThread];
				}
				[newThread addValue: item forKey: @"messages"];

			} // Otherwise we trash the whole thread anyway.
		}
    }
    
    if (trashedAtLeastOne)  {
		// Select first selected line, if it still exists;
        rowBefore = MIN([threadsView numberOfRows]-1, rowBefore); 
		if (rowBefore>=0) [threadsView selectRow: rowBefore byExtendingSelection: NO];
		
		[tabView selectTabViewItemWithIdentifier: @"threads"];
		[NSApp saveAction: self];
    } else  {
        NSBeep();
    }
}

- (void) updateGroupInfoTextField
{
    int numberOfThreads = MIN([self threadLimitCount], [[self threadsByDate] count]);
    [groupInfoTextField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%d threads", "group info text template"), numberOfThreads]];
}



- (void) modelChanged: (NSNotification*) aNotification
{
	// Re-query all threads keeping the selection, if possible.
	//NSArray* selectedItems = [threadsView selectedItems];
	if (NSDebugEnabled) NSLog(@"GroupController detected a model change. Cache cleared, OutlineView reloaded, group info text updated.");
	[self updateGroupInfoTextField];
	//[threadsView deselectAll:nil];
	
	[self reload];
	//[threadsView selectItems: selectedItems ordered: YES];
}

- (GIMessageGroup*) group
{
    return group;
}

- (void) setGroup: (GIMessageGroup*) aGroup
{
    if (aGroup != group) {
		[self setDisplayedMessage: nil thread: nil];
		
		[group removeObserver: self forKeyPath: @"threadsByDate"];
		
		[aGroup addObserver: self 
				 forKeyPath: @"threadsByDate" 
					options: NSKeyValueObservingOptionNew 
					context: NULL];
        
        [group autorelease];
        group = [aGroup retain];
		
		if (group) {
			// thread filter popup:
			[threadFilterPopUp selectItemWithTag: [[self valueForGroupProperty: ShowOnlyRecentThreads] intValue]];
			
			[self updateWindowTitle];
			[self updateGroupInfoTextField];
			[self reload];
            
            // Select and scroll:
			[threadsView scrollRowToVisible: [threadsView numberOfRows]-1];
            
            OPPersistentObjectContext *context = [OPPersistentObjectContext defaultContext];
			@try {
                id lastSelectedMessageItem = [context objectWithURLString:[self valueForGroupProperty:@"LastSelectedMessageItem"]];
                
                if (lastSelectedMessageItem) {
                    // is thread or message
                    GIThread* thread;
                    GIMessage* message;
                    
                    if (isThreadItem(lastSelectedMessageItem)) {
                        thread = lastSelectedMessageItem;
                        message = [[thread messagesByTree] lastObject];
                    } else {
                        NSAssert([lastSelectedMessageItem isKindOfClass: [GIMessage class]], @"should be a message object");
                        
                        message = lastSelectedMessageItem;
                        thread = [message thread];
                    }
                    [self showMessageInThreadList: message];
                }
			} @catch (NSException* localException) {
				// ignored
			}
		}
    }
}

// validation

- (BOOL)multipleThreadsSelected
/*" Returns YES, if more than one thread is selected in the thread list. "*/
{
    NSIndexSet *selectedIndexes;
    
    selectedIndexes = [threadsView selectedRowIndexes];
    if ([selectedIndexes count] > 0) 
    {
		unsigned count = 0;
        unsigned i;
        unsigned lastIndex = [selectedIndexes lastIndex];
        
        for (i = [selectedIndexes firstIndex]; i <= lastIndex; i = [selectedIndexes indexGreaterThanIndex:i]) {
			if (isThreadItem([threadsView itemAtRow: i])) 
            {
				if (++count > 1) return YES;
			}
        }
        return YES;
    }
    return NO;        
}

- (IBAction)showNextMessage:(id)sender 
{
	if ([self isThreadlistShownCurrently]) 
	{
		// Thread list is showing	
		NSLog(@"Should show next message!");
		NSBeep();
	} 
	else if ([self isMessageShownCurrently]) 
	{
		// Message view is showing
		NSArray *messages = [displayedThread messagesByTree];
		GIMessage *messageFound = nil;

		if ([messages count] > 1) 
		{
			unsigned displayedMessageIndex = [messages indexOfObject: displayedMessage];
			unsigned index = displayedMessageIndex;
			// Find the next unread message in current thread:
			while (displayedMessageIndex != (index = (index + 1) % [messages count])) 
			{
				GIMessage *message = [messages objectAtIndex:index];
				if (!([message flags] & OPSeenStatus)) 
				{
					messageFound = message;
					break;
				}
			}
		}
		
		if (messageFound) 
		{
			[self setDisplayedMessage: messageFound thread: displayedThread];
		} 
		else 
		{
			NSLog(@"Should show next thread !");
			NSBeep();
		}
	}
}

- (BOOL)validateSelector:(SEL)aSelector
{
	if ([self isSearchShownCurrently]
		&&
		(aSelector == @selector(replyDefault:))
		|| (aSelector == @selector(replySender:))
		|| (aSelector == @selector(replyAll:))
		|| (aSelector == @selector(forward:))
		|| (aSelector == @selector(followup:))		) 
	{
		int selectedIndex = [searchHitsTableView selectedRow];
		
		if (selectedIndex >= 0) return YES;
		else return NO;
	}
    else if ( (aSelector == @selector(replyDefault:))
         || (aSelector == @selector(replySender:))
         || (aSelector == @selector(replyAll:))
         || (aSelector == @selector(forward:))
         || (aSelector == @selector(followup:))
         //|| (aSelector == @selector(showTransferData:))
         ) 
	{
		if ([self isThreadlistShownCurrently] || [self isMessageShownCurrently]) 
		{
			NSIndexSet *selectedIndexes = [threadsView selectedRowIndexes];
			
			if ([selectedIndexes count] == 1) {
				id item = [threadsView itemAtRow:[selectedIndexes firstIndex]];
				if (([item isKindOfClass:[GIMessage class]]) || ([item containsSingleMessage])) 
				{
					return YES;
				}
			}
		}
		return NO;
    } 
	else if (aSelector == @selector(applySortingAndFiltering:)) 
	{
        return [self multipleThreadsSelected]; 
	} 
	else if ((aSelector == @selector(toggleReadFlag:)) || (aSelector == @selector(toggleJunkFlag:))) 
	{
        return [[threadsView selectedRowIndexes] count] > 0;
    } 
	else if (aSelector == @selector(moveSelectionToTrash:)) 
	{
        return [[threadsView selectedRowIndexes] count] > 0;
    } 
	else if (aSelector == @selector(delete:)) 
	{
        return [[threadsView selectedRowIndexes] count] > 0;
    }
    /*
     if ( 
          (aSelector == @selector(catchup:))
          || (aSelector == @selector(applySorters:))
          || (aSelector == @selector(moveToTrash:))
          )
     {
         if([[messageListController visibleSelectedMessageSummaries] count] > 0)
             return YES;
         else
             return NO;
     }
     
     if (aSelector == @selector(toggleShowListOfMessageboxes:))
     {
         if ([GIMessageboxesController isRememberedOpen])
             return NO;
         else
             return YES;
     }
     
     if ( (aSelector == @selector(newMessagebox:))
          || (aSelector == @selector(rename:))
          || (aSelector == @selector(delete:))
          || (aSelector == @selector(newMessageboxFolder:)))
     {
         if ([[[window drawers] objectAtIndex:0] state] == NSDrawerClosedState)
         {
             return NO;
         }
         else
         {
             return YES;
         }
     }
     */
    return YES;
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{
    if ([menuItem action] == @selector(showRawSource:)) 
    {
        [menuItem setState:showRawSource ? NSOnState : NSOffState];
        return ![self isThreadlistShownCurrently];
    } 
    else if ([menuItem action] == @selector(toggleReadFlag:)) 
    {
        if ([self validateSelector:[menuItem action]]) 
        {
            NSArray *selectedMessages;
            
            if ([self isAnySelectedItemNotHavingMessageflag:@"isSeen" allSelectedMessages:&selectedMessages]) 
            {
                [menuItem setTitle:NSLocalizedString(@"As Read", @"Menu title for toggling messages to read")];
            } 
            else 
            {
                [menuItem setTitle:NSLocalizedString(@"As Unread", @"Menu title for toggling messages to read")];
            }
            return YES;
        } 
        else return NO;
    } 
    else 
    {
        return [self validateSelector: [menuItem action]];
    }
}

@end

@implementation GIThreadListController (OutlineViewDataSource)

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
  if ([notification object] == threadsView) 
  {	  
        id item = [threadsView itemAtRow:[threadsView selectedRow]];
        
        if ([item isKindOfClass: [OPPersistentObject class]]) {
            item = [item objectURLString];
			[self setValue:item forGroupProperty:@"LastSelectedMessageItem"];
        }
    }
}

- (BOOL) outlineView: (NSOutlineView*) outlineView shouldExpandItem: (id) item
/*" Remembers last expanded thread for opening the next time. "*/
{	
    return YES;
}

- (int) outlineView: (NSOutlineView*) outlineView numberOfChildrenOfItem: (id) item
{
    if (outlineView == threadsView) {
		// thread list
        if (item == nil) {
			
			int result = MIN([self threadLimitCount], [[self threadsByDate] count]);
			NSLog(@"ThreadList %@ shows %d threads.", self, result);
			return result;
/*
			int result = [self threadLimitCount];
			int threadCount = [[self threadsByDate] count];
			if (threadCount < result) {
				result = threadCount;
			}
			return result;
 */
        } else {        
			// item should be a thread
            return [[item messages] count];
        }
    }
    return 0;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return isThreadItem(item) && [[item messages] count]>1;
}

- (id) outlineView: (NSOutlineView*) outlineView child: (int) index ofItem: (id) item
{
    id result = nil;
	if (! item) {
		NSArray* threadArray = [self threadsByDate];
		int arrayIndex = index;
		int threadLimit = [self threadLimitCount];
	
		if ([threadArray count]>threadLimit)  {
			//[threadArray count]-MIN(threadLimit, [threadArray count]);
			arrayIndex += ([threadArray count]-threadLimit);
		}
		result = [threadArray objectAtIndex: arrayIndex];
	} else {            
		result = [[item messagesByTree] objectAtIndex: index];
		[item messagesByTree];
	}
	[itemRetainer addObject:result];
    return result;
}

// diverse attributes
NSDictionary* unreadAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes){
        attributes = [[NSDictionary alloc] initWithObjectsAndKeys:
            [NSFont boldSystemFontOfSize:12], NSFontAttributeName,
            nil];
    }
    return attributes;
}

NSDictionary* readAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes) {
        attributes = [[NSDictionary alloc] initWithObjectsAndKeys:
            [NSFont systemFontOfSize:12], NSFontAttributeName,
            [[NSColor blackColor] highlightWithLevel:0.15], NSForegroundColorAttributeName, nil];
    }
    return attributes;
}

NSDictionary* selectedReadAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes) {
        attributes = [[readAttributes()mutableCopy] autorelease];
        [(NSMutableDictionary *)attributes setObject: [[NSColor selectedMenuItemTextColor] shadowWithLevel:0.15] forKey:NSForegroundColorAttributeName];
        attributes = [attributes copy];
    }
    
    return attributes;
}

NSDictionary *fromAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes) {
        attributes = [[readAttributes()mutableCopy] autorelease];
        [(NSMutableDictionary *)attributes setObject: [[NSColor darkGrayColor] shadowWithLevel:0.3] forKey:NSForegroundColorAttributeName];

        attributes = [attributes copy];
    }
    return attributes;
}

NSDictionary *unreadFromAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes)
    {
        attributes = [[fromAttributes()mutableCopy] autorelease];
        [(NSMutableDictionary *)attributes addEntriesFromDictionary:unreadAttributes()];
        attributes = [attributes copy];
    }
    return attributes;
}

NSDictionary *selectedUnreadFromAttributes()
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

NSDictionary *readFromAttributes()
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

NSDictionary *selectedReadFromAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes) {
        attributes = [[readFromAttributes()mutableCopy] autorelease];
        [(NSMutableDictionary *)attributes setObject: [[NSColor selectedMenuItemTextColor] shadowWithLevel:0.15] forKey:NSForegroundColorAttributeName];
        attributes = [attributes copy];
    }
    
    return attributes;
}

static NSAttributedString* spacer()
/*" String for inserting for message inset. "*/
{
    static NSAttributedString *spacer = nil;
    if (! spacer){
        spacer = [[NSAttributedString alloc] initWithString: @"   "];
    }
    return spacer;
}

static NSAttributedString* spacer2()
/*" String for inserting for messages which are to deep to display insetted. "*/
{
    static NSAttributedString *spacer = nil;
    if (! spacer){
        spacer = [[NSAttributedString alloc] initWithString: [NSString stringWithFormat: @"%C ", 0x21e5]];
    }
    return spacer;
}

#define MAX_INDENTATION 4

- (id) outlineView: (NSOutlineView*) outlineView objectValueForTableColumn: (NSTableColumn*) tableColumn byItem: (id) item
{
    BOOL inSelection = [[threadsView selectedRowIndexes] containsIndex:[threadsView rowForItem:item]];
    BOOL inSelectionAndAppActive = (inSelection && [NSApp isActive] && [window isMainWindow]);
    
    if (outlineView == threadsView) {
		// subjects list
        if ([[tableColumn identifier] isEqualToString: @"date"]) {

            BOOL isRead = ([item isKindOfClass: [GIThread class]]) ? ![(GIThread*)item hasUnreadMessages] : [(GIMessage*)item hasFlags: OPSeenStatus];
            
            NSCalendarDate* date = [item valueForKey: @"date"]; // both thread an message respond to "date"
            
			NSAssert2(date==nil || [date isKindOfClass: [NSCalendarDate class]], @"NSCalendarDate expected but got %@ from %@", NSStringFromClass([date class]), item);
            
            NSString* dateString = [date descriptionWithCalendarFormat: [[NSUserDefaults standardUserDefaults] objectForKey: NSShortTimeDateFormatString] timeZone: [NSTimeZone localTimeZone] locale: [[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
                            
            return [[[NSAttributedString alloc] initWithString: dateString attributes: isRead ? (inSelectionAndAppActive ? selectedReadFromAttributes() : readFromAttributes()) : unreadAttributes()] autorelease];
        }
        
        if ([[tableColumn identifier] isEqualToString: @"subject"]) {
			int i;
            NSMutableAttributedString* result = [[[NSMutableAttributedString alloc] init] autorelease];
            
            if (isThreadItem(item)) {
	        	// it's a thread:		
                GIThread* thread = item;
                
                if ([thread containsSingleMessage]) {
                    NSString* from;
                    NSAttributedString* aFrom;
                    GIMessage* message = [[thread valueForKey: @"messages"] lastObject];
                    
                    if (message) {
                        BOOL flags  = [message flags];
                        NSString* subject = [message valueForKey: @"subject"];
                        
                        if (!subject) subject = @"";
                        
                        NSAttributedString* aSubject = [[NSAttributedString alloc] initWithString: subject attributes: (flags & OPSeenStatus) ? (inSelectionAndAppActive ? selectedReadAttributes() : readAttributes()) : unreadAttributes()];
                        
                        [result appendAttributedString: aSubject];
                        
						if ([message hasFlags: OPIsFromMeStatus]) {
							from = [NSString stringWithFormat: @" (%C %@)", 0x279F/*Right Arrow*/, [message recipientsForDisplay]];
						} else {
							from = [message senderName];
							if (!from) from = @"- sender missing -";
							from = [NSString stringWithFormat: @" (%@)", from];
						}                        
                        aFrom = [[NSAttributedString alloc] initWithString: from attributes: ((flags & OPSeenStatus) || (flags & OPIsFromMeStatus)) ? (inSelectionAndAppActive ? selectedReadFromAttributes() : readFromAttributes()) : (inSelectionAndAppActive ? selectedUnreadFromAttributes() : unreadFromAttributes())];
                        
                        [result appendAttributedString: aFrom];
                        
                        [aSubject release];
                        [aFrom release];
                    }
                } else {
					// contains more than one message
                    return [[[NSAttributedString alloc] initWithString: [thread valueForKey: @"subject"] attributes: [thread hasUnreadMessages] ? unreadAttributes() : (inSelectionAndAppActive ? selectedReadAttributes() : readAttributes())] autorelease];
                }
            } else {
				// a message, not a thread
                NSString* from = [item senderName];
                if (!from) {
					from = @"- sender missing -";
				}
				
                unsigned indentation = [(GIMessage*) item numberOfReferences];
                
                [result appendAttributedString: spacer()];
                
                for (i = MIN(MAX_INDENTATION, indentation); i > 0; i--) {
                    [result appendAttributedString: spacer()];
                }
                
                [result appendAttributedString: (indentation > MAX_INDENTATION)? spacer2() : spacer()];
                
                [result appendAttributedString: [[NSAttributedString alloc] initWithString: from attributes: [(GIMessage *)item hasFlags: OPSeenStatus] ? (inSelectionAndAppActive ? selectedReadFromAttributes() : readFromAttributes()) : (inSelectionAndAppActive ? selectedUnreadFromAttributes() : unreadFromAttributes())]];
            }
            
            return result;
        }
    }
    return @"";
}

@end

@implementation GIThreadListController (TableViewDataSource)

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [hits count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
    NSDictionary *hit = [hits objectAtIndex:rowIndex];
    GIMessage *message = [hit objectForKey:@"message"];
    BOOL isAppActive = YES; // ([NSApp isActive] && [window isMainWindow]);

    if ([[aTableColumn identifier] isEqualToString:@"date"]) 
    {
        BOOL isRead = [message hasFlags:OPSeenStatus];
        NSCalendarDate *date = [message valueForKey:@"date"];
                
        NSString *dateString = [date descriptionWithCalendarFormat:[[NSUserDefaults standardUserDefaults] objectForKey:NSShortTimeDateFormatString] timeZone:[NSTimeZone localTimeZone] locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
        
        return [[[NSAttributedString alloc] initWithString:dateString attributes:isRead ? (isAppActive ? selectedReadFromAttributes() : readFromAttributes()) : unreadAttributes()] autorelease];
    } 
    else if ([[aTableColumn identifier] isEqualToString: @"subjectauthor"]) 
    {
        NSString *from;
        NSAttributedString *aFrom;
        NSMutableAttributedString *result = [[[NSMutableAttributedString alloc] init] autorelease];
        
        BOOL isRead  = [message hasFlags:OPSeenStatus];
        NSString *subject = [message valueForKey:@"subject"];
        
        if (!subject) subject = @"";
        
        NSAttributedString *aSubject = [[NSAttributedString alloc] initWithString:subject attributes:isRead ? (isAppActive ? selectedReadAttributes() : readAttributes()) : unreadAttributes()];
        
        [result appendAttributedString:aSubject];
        
        if ([message hasFlags:OPIsFromMeStatus]) 
        {
			from = [NSString stringWithFormat:@" (%c %@)", 2782/*Right Arrow*/, [message recipientsForDisplay]];
		} 
        else 
        {
			from = [message senderName];
			if (!from) from = @"- sender missing -";
			from = [NSString stringWithFormat:@" (%@)", from];
		}
        
        aFrom = [[NSAttributedString alloc] initWithString:from attributes: isRead ? (isAppActive ? selectedReadFromAttributes() : readFromAttributes()) : (isAppActive ? selectedUnreadFromAttributes() : unreadFromAttributes())];
        
        [result appendAttributedString:aFrom];
        
        [aSubject release];
        [aFrom release];
        
        return result;
    } 
    else if ([[aTableColumn identifier] isEqualToString: @"relevance"]) 
    {
        return [hit objectForKey:@"score"]; // the score
    }
    
    return @"";
}

@end

@implementation GIThreadListController (CommentsTree)

- (void) awakeCommentTree
/*" awakeFromNib part for the comment tree. Called from -awakeFromNib. "*/
{
    GICommentTreeCell* commentCell = [[[GICommentTreeCell alloc] init] autorelease];
    
    [commentsMatrix putCell: commentCell atRow: 0 column: 0];
    [commentsMatrix setCellClass: nil];
    [commentsMatrix setPrototype: commentCell];
    [commentsMatrix setCellSize: NSMakeSize(20,10)];
    [commentsMatrix setIntercellSpacing: NSMakeSize(0,0)]; 
    [commentsMatrix setAction: @selector(selectTreeCell:)];
    [commentsMatrix setTarget: self];
    [commentsMatrix setNextKeyView: messageTextView];
    [messageTextView setNextKeyView: commentsMatrix];
    NSAssert([messageTextView nextKeyView]==commentsMatrix, @"setNExtKeyView did not work");

}

- (void) deallocCommentTree
{
	 // Add code here to release all messages in expanded threads.
}

// fill in commentsMatrix

static NSMutableDictionary* commentsCache = nil;

NSArray* commentsForMessage(GIMessage* aMessage, GIThread* aThread)
{
    NSArray* result;
    
    result = [commentsCache objectForKey: [aMessage objectURLString]];
    
    if (! result) {
        result = [aMessage commentsInThread:aThread];
        [commentsCache setObject: result forKey: [aMessage objectURLString]];
    }
    
    return result;
}


- (void) initializeBorderToDepth: (int) aDepth
{
    int i;
    
    [border autorelease];
    border = [[NSMutableArray alloc] initWithCapacity: aDepth];
    for (i = 0; i < aDepth; i++)
        [border addObject: [NSNumber numberWithInt: -1]];
}


/*"Configures the cell for %message in the tree view.
   The cell's position is in the specified column but it's row is the row of the
   first child of the message.
   If there is no child the cell is in row %row.
   The return value is the row the message was placed in."*/
- (int) placeTreeWithRootMessage:(GIMessage*)message andSiblings:(NSArray*)siblings atOrBelowRow:(int)row inColumn:(int)column
{
    GICommentTreeCell* cell;
    
    if (row <= [[border objectAtIndex:column] intValue])
        row = [[border objectAtIndex:column] intValue] + 1;
        
    NSArray* comments = commentsForMessage(message, displayedThread);
    int commentCount = [comments count];
    
    NSEnumerator* children = [comments objectEnumerator];
    GIMessage* child;
    
    // place the children first
    if (child = [children nextObject]) {
        int nextColumn = column + 1;
        int newRow;
        
        row = newRow = [self placeTreeWithRootMessage:child andSiblings:comments atOrBelowRow:row inColumn:nextColumn];
        
        // first child
        cell = [commentsMatrix cellAtRow:newRow column:nextColumn];
        [cell addConnectionToEast];  // to child itself (me)
        [cell addConnectionToWest];  // to parent
        
        // other children
        while (child = [children nextObject]) {
            int i;
            int startRow = newRow;
            
            newRow = [self placeTreeWithRootMessage:child andSiblings:comments atOrBelowRow:newRow + 1 inColumn:nextColumn];
            
            [[commentsMatrix cellAtRow:startRow column:nextColumn] addConnectionToSouth];
            
            for (i = startRow+1; i < newRow; i++)
            {
                cell = [commentsMatrix cellAtRow:i column:nextColumn];
                [cell addConnectionToNorth];
                [cell addConnectionToSouth];
            }
            
            cell = [commentsMatrix cellAtRow:newRow column:nextColumn];
            [cell addConnectionToNorth];
            [cell addConnectionToEast];
        }
    }
    
    // update the border
    [border replaceObjectAtIndex:column withObject:[NSNumber numberWithInt:row]];
    
    
    while (row >= [commentsMatrix numberOfRows])
        [commentsMatrix addRow];
        
    // get the cell for the message second
    cell = [commentsMatrix cellAtRow:row column:column];
    
    int indexOfMessage = [siblings indexOfObject:message];
    
    // set cell's navigation info
    if (commentCount > 0)
        [cell addNavigationToEast];
    if ([message numberOfReferences] > 0)
        [cell addNavigationToWest];
    if (indexOfMessage >= 1)
        [cell addNavigationToNorth];
    if ([siblings count] > indexOfMessage + 1)
        [cell addNavigationToSouth];

    // set cell's message attributes
    [cell setRepresentedObject:message];
    [cell setSeen:[message hasFlags:OPSeenStatus]];
    [cell setIsDummyMessage:[message isDummy]];
    [cell setHasConnectionToDummyMessage:[[message reference] isDummy]];
    
    [commentsMatrix setToolTip:[message valueForKey:@"senderName"] forCell:cell];
    
    // set color
    if ([message flags] & OPIsFromMeStatus)
        [cell setColorIndex:5];  // blue
    else {
        // for testing we are coloring the messages of David Stes and John C. Randolph
        NSString* senderName = [message senderName];
        if (senderName) {
            NSRange range = [senderName rangeOfString:@"David Stes"];
            if (range.location != NSNotFound)
                [cell setColorIndex:1];  // red
            range = [senderName rangeOfString:@"John C. Randolph"];
            if (range.location != NSNotFound)
                [cell setColorIndex:4];  // green
        }
    }
    
    return row;
}

- (void) updateCommentTree:(BOOL) rebuildThread
{
    if (rebuildThread) {
        [commentsMatrix deselectAllCells];
        [commentsMatrix renewRows:1 columns:[displayedThread commentDepth]];
        
        commentsCache = [[NSMutableDictionary alloc] init];
        
        //Class cc = [commentsMatrix cellClass];
        //NSCell* aCell = [commentsMatrix cellAtRow:0 column:0];
        
        //NSLog(@"Cells %@", [commentsMatrix cells]);
        
        [[commentsMatrix cells] makeObjectsPerformSelector:@selector(reset) withObject:nil];
        
        // Usually this calls placeMessage:singleRootMessage row:0
        NSArray* rootMessages = [displayedThread rootMessages];
        NSEnumerator* me = [rootMessages objectEnumerator];
        unsigned row = 0;
        GIMessage* rootMessage;
        
        [self initializeBorderToDepth:[displayedThread commentDepth]];
        while (rootMessage = [me nextObject]) {
            row = [self placeTreeWithRootMessage:rootMessage andSiblings:rootMessages atOrBelowRow:row inColumn:0];
            
            if ([rootMessage reference]) {
                // add "broken" reference
                [[commentsMatrix cellAtRow:row column:0] addConnectionToEast];
            }
        }
        
        //[commentsMatrix selectCell:[commentsMatrix cellForRepresentedObject:displayedMessage]];
        [commentsMatrix sizeToFit];
        [commentsMatrix setNeedsDisplay:YES];
        //[commentsMatrix scrollCellToVisibleAtRow:<#(int)row#> column:<#(int)col#>]];
        
        [commentsCache release];
        commentsCache = nil;
    }
    
    int row, column;
    GICommentTreeCell* cell;
    
    cell = (GICommentTreeCell*) [commentsMatrix cellForRepresentedObject:displayedMessage];
    [cell setSeen:YES];
    
    [commentsMatrix selectCell:cell];
    
    [commentsMatrix getRow:&row column:&column ofCell:cell];
    [commentsMatrix scrollCellToVisibleAtRow:MAX(row-1, 0) column:MAX(column-1,0)];
    [commentsMatrix scrollCellToVisibleAtRow:row+1 column:column+1];
	
	// Update tree splitter view:
	if (rebuildThread) {
		NSScrollView* scrollView = [[treeBodySplitter subviews] objectAtIndex:0];
		//[scrollView setFrameSize:NSMakeSize([scrollView frame].size.width, [commentsMatrix frame].size.height+15.0)];
		//[treeBodySplitter moveSplitterBy:[commentsMatrix frame].size.height+10-[scrollView frame].size.height];
		//[scrollView setAutohidesScrollers:YES];
		BOOL hasHorzontalScroller = [commentsMatrix frame].size.width>[scrollView frame].size.width;
		float newHeight = [commentsMatrix frame].size.height + 3 + (hasHorzontalScroller * [NSScroller scrollerWidth]); // scroller width could be different
		[scrollView setHasHorizontalScroller:hasHorzontalScroller];
		if ([commentsMatrix numberOfColumns] <= 1) newHeight = 0;
		if (newHeight>200.0) {
			newHeight = 200.0;
			[scrollView setHasVerticalScroller:YES];
		} else {
			[scrollView setHasVerticalScroller:NO];
		}
		[treeBodySplitter setFirstSubviewSize:newHeight];
	}
}

- (IBAction) selectTreeCell:(id)sender
/*" Displays the corresponding message. "*/
{
    GIMessage *selectedMessage = [[sender selectedCell] representedObject];
    
    if (selectedMessage) {
        [self setDisplayedMessage:selectedMessage thread: [self displayedThread]];
    }
}

- (BOOL)matrixIsVisible
    /*" Returns YES if the comments matrix is shown and not collapsed. NO otherwise "*/
{
    return ![treeBodySplitter isSubviewCollapsed:[[treeBodySplitter subviews] objectAtIndex:0]];
}

- (BOOL)leftMostMessageIsSelected
{
    int row, col;
    
    [commentsMatrix getRow:&row column:&col ofCell:[commentsMatrix selectedCell]];
    
    return col == 0;
}

// navigation (triggered by menu and keyboard shortcuts)
- (IBAction)navigateUpInMatrix:(id)sender
/*" Displays the previous sibling message if present in the current thread. Beeps otherwise. "*/
{
    if ([self isMessageShownCurrently]) 
    {
        NSArray *comments;
        int indexOfDisplayedMessage;
        
        comments = [[[self displayedMessage] reference] commentsInThread:[self displayedThread]];
        indexOfDisplayedMessage = [comments indexOfObject:[self displayedMessage]];
        
        if ((indexOfDisplayedMessage - 1) >= 0) 
        {
            [self setDisplayedMessage:[comments objectAtIndex:indexOfDisplayedMessage - 1] thread:[self displayedThread]];
            return;
        }
        NSBeep();
    }
}

- (IBAction)navigateDownInMatrix:(id)sender
/*" Displays the next sibling message if present in the current thread. Beeps otherwise. "*/
{
    if ([self isMessageShownCurrently]) 
    {
        NSArray *comments = [[[self displayedMessage] reference] commentsInThread:[self displayedThread]];
        int indexOfDisplayedMessage = [comments indexOfObject:[self displayedMessage]];
        
        if ([comments count] > indexOfDisplayedMessage + 1) 
        {
            [self setDisplayedMessage: [comments objectAtIndex:indexOfDisplayedMessage + 1] thread:[self displayedThread]];
            return;
        }
        NSBeep();
    }
}

- (IBAction)navigateLeftInMatrix:(id)sender
/*" Displays the parent message if present in the current thread. Beeps otherwise. "*/
{
    if ([self isMessageShownCurrently]) 
    {
        if ([self leftMostMessageIsSelected] || ![self matrixIsVisible])
        {
            [tabView selectTabViewItemWithIdentifier:@"threads"];
        }
        else
        {
            GIMessage *newMessage;
            
            if ((newMessage = [[self displayedMessage] reference])) 
            {
                // check if the current thread has the reference:
                if ([[[self displayedThread] messages] containsObject:newMessage]) 
                {
                    [self setDisplayedMessage:newMessage thread:[self displayedThread]];
                    return;
                }
            }
            NSBeep();
        }
    }
}

- (IBAction)navigateRightInMatrix:(id)sender
/*" Displays the first child message if present in the current thread. Beeps otherwise. "*/
{
    if ([self isMessageShownCurrently]) 
    {
        NSArray *comments = [[self displayedMessage] commentsInThread:[self displayedThread]];
        
        if ([comments count]) 
        {
            [self setDisplayedMessage:[comments objectAtIndex:0] thread:[self displayedThread]];
            return;
        }
        NSBeep();
    }
}

//[commentsMatrix cellAtRow:y column:x]

@end

@implementation GIThreadListController (ToolbarDelegate)
/*" Toolbar delegate methods and setup and teardown. "*/

- (void)awakeToolbar
/*" Called from within -awakeFromNib. "*/
{
    NSToolbar *toolbar;
    
    toolbar = [[NSToolbar alloc] initWithIdentifier:@"GroupToolbar"];
    
    [toolbar toolbarItems:&toolbarItems defaultIdentifiers:&defaultIdentifiers forToolbarNamed:@"group"];
    
    [toolbar setDelegate:self];
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration:YES];
    
    [toolbarItems retain];
    [defaultIdentifiers retain];
    
    [window setToolbar:toolbar];
}

- (void)deallocToolbar
/*" Called within dealloc. "*/
{
    [[window toolbar] release];
    [toolbarItems release];
    [defaultIdentifiers release];
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem
{
    return [self validateSelector:[theItem action]];
}

- (NSToolbarItem*) toolbar: (NSToolbar*) toolbar itemForItemIdentifier: (NSString*) itemIdentifier willBeInsertedIntoToolbar: (BOOL) flag
{
    return [NSToolbar toolbarItemForItemIdentifier:itemIdentifier fromToolbarItemArray:toolbarItems];
}

- (NSArray*) toolbarDefaultItemIdentifiers: (NSToolbar*) toolbar
{
    return defaultIdentifiers;
}

- (NSArray*) toolbarAllowedItemIdentifiers: (NSToolbar*) toolbar
{
    static NSArray* allowedItemIdentifiers = nil;
    
    if (! allowedItemIdentifiers) {
        NSToolbarItem*  item;
        NSMutableArray* allowed = [NSMutableArray arrayWithCapacity:[toolbarItems count] + 5];
        NSEnumerator*   enumerator = [toolbarItems objectEnumerator];
		
        while (item = [enumerator nextObject]) [allowed addObject:[item itemIdentifier]];
        
        [allowed addObjectsFromArray:[NSArray arrayWithObjects:NSToolbarSeparatorItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSpaceItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, nil]];
        
        allowedItemIdentifiers = [allowed copy];
    }
    
    return allowedItemIdentifiers;
}

@end

@implementation GIThreadListController (DragNDrop)

- (BOOL)outlineView:(NSOutlineView *)anOutlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(int)index
{
    if (anOutlineView == threadsView)
    {
        // move threads from source group to destination group:
        NSArray *threadOids = [[info draggingPasteboard] propertyListForType:@"GinkoThreads"];
        GIMessageGroup *sourceGroup = [(GIThreadListController *)[[info draggingSource] delegate] group];
        GIMessageGroup *destinationGroup = [self group];
        
        [GIMessageGroup moveThreadsWithOids:threadOids fromGroup:sourceGroup toGroup:destinationGroup];
        /*
        NSEnumerator *enumerator = [threadURLs objectEnumerator];
        NSString *threadURL;
        
        while (threadURL = [enumerator nextObject])
        {
            GIThread *thread = [OPPersistentObjectContext objectWithURLString:threadURL];
            NSAssert([thread isKindOfClass: [GIThread class]], @"should be a thread");
            
            // remove thread from source group:
            [thread removeGroup:sourceGroup];
            
            // add thread to destination group:
            [thread addGroup:destinationGroup];
        }
        */
        
        // select all in dragging source:
        NSOutlineView *sourceView = [info draggingSource];        
        [sourceView selectRow:[sourceView selectedRow] byExtendingSelection:NO];
        
        [NSApp saveAction:self];
    }
    
    return NO;
}

- (NSDragOperation)outlineView:(NSOutlineView *)anOutlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)index
{
    if (anOutlineView == threadsView) 
    {
        if ([info draggingSource] != threadsView) // don't let drop on itself
        {
            NSArray *items = [[info draggingPasteboard] propertyListForType:@"GinkoThreads"];
            
            if ([items count] > 0) 
            {
                [anOutlineView setDropItem:nil dropChildIndex:-1]; 
                return NSDragOperationMove;
            }
        }
    }
    
    return NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{
    if (outlineView == threadsView) // threads list
    {
        if (! [self multipleThreadsSelected]) return NO;
        
        [pboard declareTypes:[NSArray arrayWithObject:@"GinkoThreads"] owner:self];
        
        NSArray *selectedThreads = [self selectedThreads];
        NSEnumerator *enumerator = [selectedThreads objectEnumerator];
        NSMutableArray *pbItems = [NSMutableArray arrayWithCapacity:[selectedThreads count]];
        GIThread *thread;
        
        while (thread = [enumerator nextObject])
        {
            NSNumber *oid = [NSNumber numberWithUnsignedLongLong:[thread oid]];
            [pbItems addObject:oid];
        }
        
        [pboard setPropertyList:pbItems forType:@"GinkoThreads"];
    }
    
    return YES;
}

/*
- (NSImage *)dragImageForRowsWithIndexes: (NSIndexSet*) dragRows tableColumns:(NSArray*) tableColumns event:(NSEvent*)dragEvent offset:(NSPointPointer)dragImageOffset
{
    if (outlineView == threadsView) // threads list
    {
        return nil;
    } else {
        return [super dragImageForRowsWithIndexes:dragRows tableColumns:tableColumns event:dragEvent offset:dragImageOffset];
    }
}
*/

@end

@implementation GIThreadListController (SplitViewDelegate)

- (void) splitView:(NSSplitView*)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
    NSSize newSize = [sender frame].size;
    
    NSScrollView* firstView = [[sender subviews] objectAtIndex:0];
    NSSize  firstViewSize = [firstView frame].size;
    NSScrollView* lastView = [[sender subviews] lastObject];    
    
    [firstView setFrameSize:NSMakeSize(newSize.width, firstViewSize.height)];
    [lastView setFrameSize:NSMakeSize(newSize.width, newSize.height-[sender dividerThickness]-firstViewSize.height)];
    
    [[sender window] setContentMinSize:NSMakeSize(200, 30+firstViewSize.height+[sender dividerThickness])];
}

@end

#import "NSAttributedString+MessageUtils.h"

@implementation GIThreadListController (TextViewDelegate)

- (void) textView: (NSTextView*) textView doubleClickedOnCell:(id <NSTextAttachmentCell>)cell inRect:(NSRect)cellFrame atIndex:(unsigned)charIndex
{
    NSTextAttachment *attachment;
    NSFileWrapper *fileWrapper;
    NSString *filename;
    NSRange range;
    
    attachment = [cell attachment];
    fileWrapper = [attachment fileWrapper];
    filename = [[textView textStorage] attribute:OPAttachmentPathAttribute atIndex:charIndex effectiveRange:&range];
    
    if (NSDebugEnabled) NSLog(@"double click on attachment with name %@", filename);
    
    [[NSWorkspace sharedWorkspace] openFile: filename];
}

- (void) textView: (NSTextView*) view draggedCell:(id <NSTextAttachmentCell>)cell inRect:(NSRect)rect event:(NSEvent *)event atIndex:(unsigned)charIndex
{
    NSTextAttachment *attachment;
    NSFileWrapper *fileWrapper;
    NSString *filename;
    NSRange range;
    
    attachment = [cell attachment];
    fileWrapper = [attachment fileWrapper];
    filename = [[view textStorage] attribute:OPAttachmentPathAttribute atIndex:charIndex effectiveRange:&range];
    
    if (NSDebugEnabled) NSLog(@"draggedCell %@", filename);
    
	// HTML may not contain attachment files, how do we handle D&D?
	if (filename) {
		NSPoint mouseLocation = [event locationInWindow];
		mouseLocation.x -= 16; // file icons are guaranteed to have 32 by 32 pixels (Mac OS 10.4 NSWorkspace docs)
		mouseLocation.y -= 16;
		mouseLocation = [view convertPoint:mouseLocation toView: nil];
		
		rect = NSMakeRect(mouseLocation.x, mouseLocation.y, 1, 1);
		[view dragFile:filename fromRect:rect slideBack: YES event:event];
	}
}

- (unsigned int) draggingSourceOperationMaskForLocal: (BOOL) flag
{
    return NSDragOperationCopy;
}

- (BOOL)ignoreModifierKeysWhileDragging
{
    return YES;
}

- (void)textView:(NSTextView *)textView spaceKeyPressedWithModifierFlags:(int)modifierFlags
{
    GIMessage *result = nil;
    GIMessage *candidate;
    
    NSArray *orderedMessages = [[self displayedThread] messagesByTree];
    int orderedMessageCount = [orderedMessages count];
    int iStart = [orderedMessages indexOfObject: [self displayedMessage]];
    int i = (iStart+1) % orderedMessageCount;
    while (i!=iStart) {
        if (([candidate = [orderedMessages objectAtIndex: i] flags] & OPSeenStatus) == 0) {
            result = candidate; break;
        }
        i = (i+1) % orderedMessageCount;
    } 
    if (result) {
        [self setDisplayedMessage: result thread: [self displayedThread]];
    } else NSBeep();
    return;
}

@end

@implementation GIThreadListController (WindowDelegate)

- (void) windowDidBecomeKey: (NSNotification*) aNotification
{
	recentThreadsCache = 0; // clear cache
}

@end

