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
#import "GIGroupInspectorController.h"
#import "OPPersistentObject+Extensions.h"
#import "GIMessageGroup.h"
#import "OPJobs.h"
#import "GIFulltextIndexCenter.h"
#import "GIOutlineViewWithKeyboardSupport.h"
#import "GIMessage.h"
#import "GIMessageBase.h"
#import "NSString+Extensions.h"
#import "GIMessageFilter.h"
#import "OPPersistence.h"
#import "OPObjectPair.h"

static NSString *ShowOnlyRecentThreads = @"ShowOnlyRecentThreads";

@interface GIThreadListController (CommentsTree)

- (void) awakeCommentTree;
- (void) deallocCommentTree;
- (IBAction) selectTreeCell: (id) sender;
- (void) updateCommentTree: (BOOL) rebuildThread;
- (BOOL) matrixIsVisible;

@end

@implementation GIThreadListController


- (id) init
{
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(modelChanged:) name: @"GroupContentChangedNotification" object: self];
	
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(modelChanged:) name: OPJobDidFinishNotification object: MboxImportJobName];
    
    itemRetainer = [[NSMutableSet alloc] init];
    
    return [[super init] retain]; // self retaining!
}

- (id) initWithGroup: (GIMessageGroup*) aGroup
/*" aGroup may be nil, any group will be used then. "*/
{
    if (self = [self init]) {
        
        if (! aGroup) {
            aGroup = [[GIMessageGroup allObjectsEnumerator] nextObject];
        }
		
		[NSBundle loadNibNamed: @"Group" owner: self]; // sets threadsView
		
		[self setGroup: aGroup];
    }
    
    return self;
}

static NSPoint lastTopLeftPoint = {0.0, 0.0};

- (void) awakeFromNib
{    
    [threadsView setTarget:self];
    [threadsView setDoubleAction:@selector(openSelection:)];
    [threadsView setHighlightThreads:YES];
    [threadsView registerForDraggedTypes:[NSArray arrayWithObjects: @"GinkoThreads", nil]];
    
    [searchHitsTableView setTarget:self];
    [searchHitsTableView setDoubleAction:@selector(openSelection:)];

    [self awakeToolbar];
    [self awakeCommentTree];

    lastTopLeftPoint = [window cascadeTopLeftFromPoint: lastTopLeftPoint];
    
    [window makeKeyAndOrderFront:self];    
}

- (void) dealloc
{
    NSLog(@"GIThreadListController dealloc");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [window setDelegate: nil];
    
    [self deallocCommentTree];
    [self deallocToolbar];

    [displayedMessage release];
    [displayedThread release];
    [self setGroup: nil];
    [threadCache release];
    [nonExpandableItemsCache release];
    [itemRetainer release];
    [hits release];
    
    [super dealloc];
}

- (id) valueForGroupProperty: (NSString*) prop
/*" Used for accessing user defaults for current message group. "*/
{
    NSString *key = [[self group] objectURLString];
    if (key) {
        NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
        return [[ud objectForKey:key] objectForKey:prop];
    }
    return nil;
}

- (void) setValue: (id) value forGroupProperty: (NSString*) prop 
/*" Used for accessing user defaults for current message group. "*/
{
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    NSString *key = [[self group] objectURLString];
    
    NSMutableDictionary* groupProperties = [[ud objectForKey: key] mutableCopy];
    if (!groupProperties) groupProperties = [[NSMutableDictionary alloc] init];
    
    if (value) {
        [groupProperties setObject: value forKey:prop];
    } else {
        [groupProperties removeObjectForKey:prop];
    }
    
    [ud setObject: groupProperties forKey:key];
    [groupProperties release];
}

- (void) windowWillClose: (NSNotification*) notification 
{
    lastTopLeftPoint = NSMakePoint(0.0, 0.0); // reset cascading
	[self setGroup: nil];
    [self autorelease]; // balance self-retaining
}

- (void)setDisplayedMessage:(GIMessage *)aMessage thread:(GIThread *)aThread
/*" Central method for detail viewing of a message aMessage in a thread aThread. "*/
{
    NSParameterAssert([aThread isKindOfClass:[GIThread class]]);
    
    int itemRow;
    BOOL isNewThread = ![aThread isEqual:displayedThread];
    
    [displayedMessage autorelease];
    displayedMessage = [aMessage retain];
    [displayedMessage addFlags:OPSeenStatus];
    
    if (isNewThread) 
    {
        [displayedThread autorelease];
        displayedThread = [aThread retain];
    }
    
    // make sure that thread is expanded in threads outline view:
    if (aThread && (![aThread containsSingleMessage])) 
    {
        [threadsView expandItem:aThread];
    }
    
    // select responding item in threads view:
    if ((itemRow = [threadsView rowForItem:aMessage]) < 0)// message could be from single message thread -> message is no item
    {
        itemRow = [threadsView rowForItemEqualTo:aThread startingAtRow:0];
    }
    
    [threadsView selectRow:itemRow byExtendingSelection:NO];
    [threadsView scrollRowToVisible:itemRow];
    
    // message display string:
    NSAttributedString *messageText = nil;
    
    if (showRawSource) 
    {
        NSData *transferData;
        NSString *transferString;
        
        static NSDictionary *fixedFont = nil;
        
        if (!fixedFont) 
        {
            fixedFont = [[NSDictionary alloc] initWithObjectsAndKeys:[NSFont userFixedPitchFontOfSize:10], NSFontAttributeName, nil, nil];
        }
        
        transferData = [displayedMessage transferData];
        
        // joerg: this is a quick hack (but seems sufficient here) to handle 8 bit transfer encoded messages (body) without having to do the mime parsing
        if (!(transferString = [NSString stringWithData:[displayedMessage transferData] encoding:NSUTF8StringEncoding]))
            transferString = [NSString stringWithData:[displayedMessage transferData] encoding:NSISOLatin1StringEncoding];
        
        messageText = [[[NSAttributedString alloc] initWithString:transferString attributes:fixedFont] autorelease]; 
    } 
    else 
    {
        messageText = [displayedMessage renderedMessageIncludingAllHeaders:[[NSUserDefaults standardUserDefaults] boolForKey:ShowAllHeaders]];
    }
    
    if (!messageText)
    {
        messageText = [[NSAttributedString alloc] initWithString:@"Warning: Unable to decode message. messageText == nil."];
    }
    
    [[messageTextView textStorage] setAttributedString:messageText];
    
    // set the insertion point (cursor)to 0, 0
    [messageTextView setSelectedRange:NSMakeRange(0, 0)];
    [messageTextView sizeToFit];
    // make sure that the message's header is displayed:
    [messageTextView scrollRangeToVisible:NSMakeRange(0, 0)];

    [self updateCommentTree:isNewThread];
    
    //BOOL collapseTree = [commentsMatrix numberOfColumns]<=1;
    // Hide comment tree, if trivial:
    //[treeBodySplitter setSubview: [[treeBodySplitter subviews] objectAtIndex:0] isCollapsed:collapseTree];
    //if (YES && !collapseTree){
    if (isNewThread) 
    {
        NSScrollView *scrollView = [[treeBodySplitter subviews] objectAtIndex:0];
        //[scrollView setFrameSize:NSMakeSize([scrollView frame].size.width, [commentsMatrix frame].size.height+15.0)];
        //[treeBodySplitter moveSplitterBy: [commentsMatrix frame].size.height+10-[scrollView frame].size.height];
        //[scrollView setAutohidesScrollers: YES];
        BOOL hasHorzontalScroller = [commentsMatrix frame].size.width>[scrollView frame].size.width;
        float newHeight = [commentsMatrix frame].size.height + 3 + (hasHorzontalScroller * [NSScroller scrollerWidth]); // scroller width could be different
        [scrollView setHasHorizontalScroller:hasHorzontalScroller];
        if ([commentsMatrix numberOfColumns] <= 1) newHeight = 0;
        if (newHeight>200.0) 
        {
            newHeight = 200.0;
            [scrollView setHasVerticalScroller:YES];
            //[scrollView setAutohidesScrollers: YES];
        } 
        else 
        {
            [scrollView setHasVerticalScroller:NO];
        }
        [treeBodySplitter setFirstSubviewSize:newHeight];
    }
    //}
    //[commentsMatrix scrollCellToVisibleAtRow: [commentsMatrix selectedRow] column: [commentsMatrix selectedRow]];
}

- (GIMessage *)displayedMessage
{
    return displayedMessage;
}

- (GIThread *)displayedThread
{
    return displayedThread;
}

+ (NSWindow *)windowForGroup:(GIMessageGroup *)aGroup
/*" Returns the window for the group aGroup. nil if no such window exists. "*/
{
    NSWindow *win;
    NSEnumerator *enumerator;
    
    enumerator = [[NSApp windows] objectEnumerator];
    while (win = [enumerator nextObject]) 
    {
        if ([[win delegate] isKindOfClass:self]) 
        {
            if ([[win delegate] group] == aGroup) return win;
        }
    }
    
    return nil;
}

- (NSWindow *)window 
{
    return window;
}

- (NSMutableArray *)threadCache
/* Returns an array of thread URI strings. */
{
    return threadCache;
}

- (void)setThreadCache:(NSMutableArray *)newCache
{
	/*
    [newCache retain];
    [threadCache release];
    threadCache = newCache;
	 */
}

- (NSMutableSet *)nonExpandableItemsCache
{
    return nonExpandableItemsCache;
}

- (void)setNonExpandableItemsCache:(NSMutableSet *)newCache
{
	/*
    [newCache retain];
    [nonExpandableItemsCache release];
    nonExpandableItemsCache = newCache;
	 */
}

- (void)observeValueForKeyPath:(NSString *)keyPath 
                      ofObject:(id)object 
                        change:(NSDictionary *)change 
                       context:(void *)context
{
    if ([object isEqual:[self group]]) 
    {
        NSNotification *notification = [NSNotification notificationWithName:@"GroupContentChangedNotification" object:self];
        
        NSLog(@"observeValueForKeyPath %@", keyPath);

        [[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostWhenIdle coalesceMask:NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender forModes:nil];
    }
}

- (NSTimeInterval)nowForThreadFiltering
{
    if (![[self valueForGroupProperty:ShowOnlyRecentThreads] intValue]) return 0;
    
    if (nowForThreadFiltering == 0) 
    {
        nowForThreadFiltering = [[NSDate date] timeIntervalSinceReferenceDate] - 60 * 60 * 24 * 28;
    }
    
    return nowForThreadFiltering;
}

- (void)cacheThreadsAndExpandableItems
{
	/*
    if ([self group]) {
        NSMutableArray* results      = [NSMutableArray arrayWithCapacity: 500];
        NSMutableSet* trivialThreads = [NSMutableSet setWithCapacity: 250];
        
        [self setThreadCache: results];
        [self setNonExpandableItemsCache: trivialThreads];
        
        [[self group] fetchThreads: &results
					trivialThreads: &trivialThreads
						 newerThan: [self nowForThreadFiltering]
					   withSubject: nil
							author: nil 
			 sortedByDateAscending: YES];
    }
	 */
}

- (NSArray *)threadsByDate
/*" Returns an ordered list of all message threads of the receiver, ordered by date. "*/
{
	return [group valueForKey:@"threadsByDate"];
	
	/*
    NSMutableArray* result = [self threadCache];
    
    if (!result) {
        [self cacheThreadsAndExpandableItems];
        result = [self threadCache];
    }
    return result;
	 */
}

- (NSSet *)nonExpandableItems
{
    NSMutableSet *result = [self nonExpandableItemsCache];
    
    if (!result) 
    {
        [self cacheThreadsAndExpandableItems];
        result = [self nonExpandableItemsCache];
    }
    return result;
}

- (BOOL)threadsShownCurrently
    /*" Returns YES if the tab with the threads outline view is currently visible. NO otherwise. "*/
{
    return [[[tabView selectedTabViewItem] identifier] isEqualToString: @"threads"];
}

- (BOOL)searchHitsShownCurrently
    /*" Returns YES if the tab with the search results is currently visible. NO otherwise. "*/
{
    return (hits != nil);
}

- (BOOL)openSelection:(id)sender
{    
    if ([self threadsShownCurrently]) 
    {
        int selectedRow = [threadsView selectedRow];
        
        if (selectedRow >= 0) 
        {
            GIMessage *message = nil;
            GIThread *selectedThread = nil;
            id item = [threadsView itemAtRow:selectedRow];
            
            if ([threadsView levelForRow:selectedRow] > 0) 
            {
                // it's a message, show it:
                message = item;
                // find the thread above message:
                while ([threadsView levelForRow:--selectedRow]){}
                selectedThread = [threadsView itemAtRow:selectedRow];
            } else {
                selectedThread = item;
                
                if ([selectedThread containsSingleMessage]) {
                    message = [[selectedThread valueForKey: @"messages"] lastObject];
                } else {
                    if ([threadsView isItemExpanded: item]) {
                        [threadsView collapseItem: item];
                    } else {
                        NSEnumerator* enumerator;
                        GIMessage* message;
                        
                        [threadsView expandItem: item];                    
                        // ##TODO:select first "interesting" message of this thread
                        // perhaps the next/first unread message
                        
                        enumerator = [[selectedThread messagesByTree] objectEnumerator];
                        while (message = [enumerator nextObject]) {
                            if (! [message hasFlags: OPSeenStatus]) {
                                [threadsView selectRowIndexes: [NSIndexSet indexSetWithIndex: [threadsView rowForItem:message]] byExtendingSelection: NO];
                                break;
                            }
                        }
                        
                        if (! message) {
                            // if no message found select last one:
                            [threadsView selectRowIndexes: [NSIndexSet indexSetWithIndex: [threadsView rowForItem: [[selectedThread messagesByTree] lastObject]]] byExtendingSelection: NO];   
                        }
                        
                        // make selection visible:
                        [threadsView scrollRowToVisible: [threadsView selectedRow]];
                    }
                    return YES;
                }
            }
            
            if ([message hasFlags: OPDraftStatus] || [message hasFlags: OPQueuedStatus]) {
                if ([message hasFlags: OPInSendJobStatus]) {
                    NSLog(@"message is in send job");
                    NSBeep();
                } else {
                    [[[GIMessageEditorController alloc] initWithMessage: message] autorelease];
                }
            } else {
                [tabView selectTabViewItemWithIdentifier: @"message"];
                
                //[message addFlags: OPSeenStatus];
                
                [self setDisplayedMessage: message thread: selectedThread];
                
                if ([self matrixIsVisible]) [window makeFirstResponder: commentsMatrix];
                else [window makeFirstResponder: messageTextView];                    
            }
        }
	} 
    else if ([self searchHitsShownCurrently])
    {
        int selectedIndex = [searchHitsTableView selectedRow];
        if ((selectedIndex >= 0) && (selectedIndex < [hits count]))
        {
            OID messageOid = [(NSNumber *)[[hits objectAtIndex:selectedIndex] firstObject] unsignedLongLongValue];
            
            GIMessage *message = [[OPPersistentObjectContext threadContext] objectForOid:messageOid ofClass:[GIMessage class]];
            
            
            if ([message hasFlags: OPDraftStatus] || [message hasFlags: OPQueuedStatus]) 
            {
                if ([message hasFlags: OPInSendJobStatus]) 
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
                [tabView selectTabViewItemWithIdentifier: @"message"];
                
                //[message addFlags: OPSeenStatus];
                GIThread *thread = [message thread];
                [self setDisplayedMessage:message thread:thread];
                
                if ([self matrixIsVisible]) [window makeFirstResponder:commentsMatrix];
                else [window makeFirstResponder:messageTextView];                    
            }       
        }
    }
    else // message shown
    {
        if ([window firstResponder] == commentsMatrix) [window makeFirstResponder:messageTextView];
        else [window makeFirstResponder:commentsMatrix];
    }
    return YES;
}

- (IBAction)closeSelection:(id)sender
{
    if (sender == messageTextView) 
    {
        if ([self searchHitsShownCurrently]) [tabView selectTabViewItemWithIdentifier:@"searchresult"];
        else [tabView selectTabViewItemWithIdentifier:@"threads"];
    } 
    else 
    {
        if ([[[tabView selectedTabViewItem] identifier] isEqualToString:@"message"]) 
        {
            // from message switch back to threads:
            if ([self searchHitsShownCurrently]) [tabView selectTabViewItemWithIdentifier:@"searchresult"];
            else [tabView selectTabViewItemWithIdentifier:@"threads"];
        } 
        else 
        {
            // from threads switch back to the groups window:
            [[GIApp standaloneGroupsWindow] makeKeyAndOrderFront:sender];
            [window performClose:self];
        }
    }
}

// actions

- (void) placeSelectedTextOnQuotePasteboard
{
    NSArray* types = [messageTextView writablePasteboardTypes];
    NSPasteboard *quotePasteboard = [NSPasteboard pasteboardWithName: @"QuotePasteboard"];
    
    [quotePasteboard declareTypes:types owner: nil];
    [messageTextView writeSelectionToPasteboard:quotePasteboard types:types];
}

- (GIMessage*) selectedMessage
/*" Returns selected message, iff one message is selected. nil otherwise. "*/
{
    GIMessage *result = nil;
    id item;
    
    item = [threadsView itemAtRow: [threadsView selectedRow]];
    if ([item isKindOfClass: [GIMessage class]]) {
        result = item;
    } else {
        result = [[[OPPersistentObjectContext objectWithURLString: item] messagesByTree] lastObject];
        if (! [result isKindOfClass: [GIMessage class]]) {
            result = nil;
        }
    }    
    
    return result;
}

- (GIProfile*) profileForMessage: (GIMessage*) aMessage
/*" Return the profile to use for email replies. Tries first to guess a profile based on the replied email. If no matching profile can be found, the group default profile is chosen. May return nil in case of no group default and no match present. "*/
{
    GIProfile *result;
    
    result = [GIProfile guessedProfileForReplyingToMessage: [aMessage internetMessage]];
    
    if (!result)
    {
        result = [[self group] defaultProfile];
    }
    
    return result;
}

- (IBAction) replySender: (id) sender
{
    GIMessage* message = [self selectedMessage];
    
    [self placeSelectedTextOnQuotePasteboard];
    
    [[[GIMessageEditorController alloc] initReplyTo:message all:NO profile: [self profileForMessage:message]] autorelease];
}

- (IBAction) followup: (id) sender
{
    GIMessage *message = [self selectedMessage];
    
    [self placeSelectedTextOnQuotePasteboard];
    
    [[[GIMessageEditorController alloc] initFollowupTo:message profile: [[self group] defaultProfile]] autorelease];
}

- (IBAction) replyAll: (id) sender
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
        
    [[[GIMessageEditorController alloc] initForward:message profile:[self profileForMessage:message]] autorelease];
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
        if ([threadsView isRowSelected:i]) 
        {
            // get one of the selected threads:
            GIThread *thread = [OPPersistentObjectContext objectWithURLString: [threadsView itemAtRow: i]];
            NSAssert([thread isKindOfClass:[GIThread class]], @"assuming object is a thread");
            
            // remove selected thread from receiver's group:
            [[self group] removeValue: thread forKey: @"threadsByDate"];
            BOOL threadWasPutIntoAtLeastOneGroup = NO;
            
            @try {
                // apply sorters and filters (and readd threads that have no fit to avoid dangling threads):
                NSEnumerator* enumerator = [[thread messages] objectEnumerator];
                GIMessage* message;
                
                while (message = [enumerator nextObject]) {
                    threadWasPutIntoAtLeastOneGroup |= [GIMessageFilter filterMessage: message flags: 0];
                }
            } @catch (NSException* localException) {
                @throw;
            } @finally {
                if (!threadWasPutIntoAtLeastOneGroup) {
					[[self group] addValue: thread forKey: @"threadsByDate"];
				}
            }
        }
    }
    // commit changes:
    [NSApp saveAction: self];
    [threadsView selectRow: firstIndex byExtendingSelection: NO];
    [threadsView scrollRowToVisible: firstIndex];
}

- (IBAction)threadFilterPopUpChanged:(id)sender
{
    if (NSDebugEnabled) NSLog(@"-threadFilterPopUpChanged:");

    nowForThreadFiltering = 0;
    
    [self setValue: [NSNumber numberWithInt: [[threadFilterPopUp selectedItem] tag]] forGroupProperty:ShowOnlyRecentThreads];

    [self modelChanged: nil];
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

- (IBAction)search:(id)sender
{
    NSString *query = [sender stringValue];
    
    if ([query length])
    {
        [tabView selectTabViewItemWithIdentifier:@"searchresult"];
        
        [self setHits:[GIFulltextIndexCenter hitsForQueryString:query]];
        
        NSLog(@"hits count = %d", [hits count]);
        
        [searchHitsTableView reloadData];
    }
    else
    {
        [self setHits:nil];
        [tabView selectTabViewItemWithIdentifier:@"threads"];
    }
}

/*
- (void) moveToTrash:(id)sender
    /"Forwards command to move selected messages to trash message box."/
{
    [messageListController trashSelectedMessages:self];
}
*/

- (IBAction)showThreads: (id) sender
{
    [tabView selectFirstTabViewItem: sender];
}

- (IBAction)showRawSource: (id) sender
{
    showRawSource = !showRawSource;
    
	if (displayedMessage && displayedThread) {
        [self setDisplayedMessage: displayedMessage thread: displayedThread];
    }
}

- (NSArray*) allSelectedMessages
{
    NSMutableArray* result = [NSMutableArray array];
    NSIndexSet* selectedIndexes = [threadsView selectedRowIndexes];
    
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
            GIThread *thread = item;
            NSEnumerator *enumerator = [[thread messages] objectEnumerator];
            GIMessage *message;
            
            while (message = [enumerator nextObject])
            {
                [result addObject:message];
            }
        }
        
        i = [selectedIndexes indexGreaterThanIndex:i];
    }
    while (i != NSNotFound);
    
    return result;
}

- (BOOL) isAnySelectedItemNotHavingMessageflags: (unsigned int) flags allSelectedMessages: (NSArray**) allMessages
{
    (*allMessages) = [self allSelectedMessages];
    NSEnumerator *enumerator = [(*allMessages) objectEnumerator];
    GIMessage *message;
    
    while (message = [enumerator nextObject])
    {
        if (![message hasFlags:flags]) return YES;
    }
    
    return NO;
}

- (void)toggleFlag:(unsigned int)flag
{
    NSArray* selectedMessages;
    BOOL set = [self isAnySelectedItemNotHavingMessageflags:flag allSelectedMessages:&selectedMessages];
    NSEnumerator *enumerator = [selectedMessages objectEnumerator];
    GIMessage *message;
    
    while (message = [enumerator nextObject])
    {
        if (set) [message addFlags:flag];
        else [message removeFlags:flag];
    }
    
    // not necessary if flag changes would be recognized automatically:
    [threadsView reloadData];
}

- (IBAction)toggleReadFlag:(id)sender
{
    [self toggleFlag:OPSeenStatus];
}

- (NSArray*) selectedThreadURIs
{
    NSMutableArray* result = [NSMutableArray array];
    NSIndexSet* set = [threadsView selectedRowIndexes];
	
    if ([set count]) {
        int lastIndex = [set lastIndex];
        int i;
        for (i=[set firstIndex]; i<=lastIndex; i++) {
			
            if ([set containsIndex: i]) {
                if ([threadsView levelForRow: i]==0) {
                    NSString* nextThreadURI = [threadsView itemAtRow: i];
                    [result addObject: nextThreadURI];
                }
            }
        }
    }
    return result;
}

- (void) joinThreadsWithURIs:(NSArray*) uriArray
{
    NSEnumerator* e = [[self selectedThreadURIs] objectEnumerator];
    NSString* targetThreadURI = [e nextObject];
    GIThread* targetThread = [OPPersistentObjectContext objectWithURLString: targetThreadURI];
    [threadsView selectRow: [threadsView rowForItem: targetThreadURI] byExtendingSelection: NO];
    [[self nonExpandableItemsCache] removeObject: targetThreadURI]; 
    [threadsView expandItem: targetThreadURI];

    //NSLog(@"Merging other threads into %@", targetThread);    

    // prevent merge problems:
    //[[OPPersistentObjectContext threadContext] refreshObject: [self group] mergeChanges: YES];
    
    NSString* nextThreadURI;
    while (nextThreadURI = [e nextObject])  {
        GIThread* nextThread = [OPPersistentObjectContext objectWithURLString: nextThreadURI];
        [targetThread mergeMessagesFromThread: nextThread];
    }
    
    [GIApp saveAction: self];
}


- (IBAction) selectThreadsWithCurrentSubject: (id) sender
    /*" Joins all threads with the subject of the selected thread. "*/
{
    NSArray* uriStrings = [self selectedThreadURIs];
    if ([uriStrings count]) {
        NSString* uri = [uriStrings objectAtIndex: 0];
        GIThread* thread = [OPPersistentObjectContext objectWithURLString: uri];
        NSString* subject = [thread valueForKey: @"subject"];
        if (subject) {
            // query database
            NSMutableArray* result = [NSMutableArray array];
            
            [[self group] fetchThreads: &result 
						trivialThreads: NULL 
							 newerThan: [self nowForThreadFiltering]
						   withSubject: subject
								author: nil 
				 sortedByDateAscending: YES];

            [threadsView selectItems: result ordered: YES];
        }
    }
}

- (IBAction) joinThreads: (id) sender
/*" Joins the selected threads into one. "*/
{
    [self joinThreadsWithURIs: [self selectedThreadURIs]];
}

- (IBAction) extractThread: (id) sender
/*" Creates a new thread for the selected messages. "*/
{
    NSLog(@"Should extractThread here.");
    
}

- (IBAction) moveSelectionToTrash: (id) sender
{
    int rowBefore = [[threadsView selectedRowIndexes] firstIndex] - 1;
    NSEnumerator* enumerator = [[self selectedThreadURIs] objectEnumerator];
    NSString* uriString;
    BOOL trashedAtLeastOne = NO;
    
    // Make sure we have a fresh group object and prevent merge problems:
    //[[NSManagedObjectContext threadContext] refreshObject: [self group] mergeChanges: YES];
    
    while (uriString = [enumerator nextObject]) {
        GIThread *thread = [OPPersistentObjectContext objectWithURLString:uriString];
        NSAssert([thread isKindOfClass: [GIThread class]], @"got non-thread object");
        
       // [thread removeFromAllGroups];
        [[self group] removeValue: thread forKey: @"threadsByDate"];
        [GIMessageBase addTrashThread: thread];
        trashedAtLeastOne = YES;
    }
    
    if (trashedAtLeastOne) {
        [NSApp saveAction:self];
        if (rowBefore >= 0) {
            [threadsView selectRow:rowBefore byExtendingSelection: NO];
        }
    }
    
    else NSBeep();
}

- (void)updateWindowTitle
{
    [window setTitle:[NSString stringWithFormat:@"%@", [group valueForKey:@"name"]]];
}

- (void) updateGroupInfoTextField
{
    [groupInfoTextField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%u threads", "group info text template"), [[self threadsByDate] count]]];
}

- (void) modelChanged
{
    // Re-query all threads keeping the selection, if possible.
    NSArray* selectedItems = [threadsView selectedItems];
    if (NSDebugEnabled) NSLog(@"GroupController detected a model change. Cache cleared, OutlineView reloaded, group info text updated.");
    //[self setThreadCache: nil];
    //[self setNonExpandableItemsCache: nil];
    [self updateGroupInfoTextField];
    [threadsView deselectAll: nil];
	
    [threadsView reloadData];
    //NSLog(@"Re-Selecting items %@", selectedItems);
    [threadsView selectItems: selectedItems ordered: YES];
}

- (void) modelChanged: (NSNotification*) aNotification
{
	[self modelChanged];
}

- (GIMessageGroup *)group
{
    return group;
}

- (void) setGroup: (GIMessageGroup*) aGroup
{
    if (aGroup != group) {
        //NSLog(@"Setting group for controller: %@", [aGroup description]);
        
		[group removeObserver: self forKeyPath: @"threadsByDate"];
		
		[aGroup addObserver: self 
				 forKeyPath: @"threadsByDate" 
					options: NSKeyValueObservingOptionNew 
					context: NULL];
        
        [group autorelease];
        group = [aGroup retain];
		
		//#########
		//[aGroup refault]; // just for testing!!
        //#########
        // thread filter popup:
        [threadFilterPopUp selectItemWithTag: [[self valueForGroupProperty:ShowOnlyRecentThreads] intValue]];
        
        [self updateWindowTitle];
        [self updateGroupInfoTextField];
		[threadsView reloadData];
    }
}

static BOOL isThreadItem(id item)
{
    return [item isKindOfClass: [GIThread class]];
}

// validation

- (BOOL) isOnlyThreadsSelected
{
    // true when only threads are selected; false otherwise
    NSIndexSet *selectedIndexes;
    
    selectedIndexes = [threadsView selectedRowIndexes];
    if ([selectedIndexes count] > 0) {
		
        int i;
        int lastIndex = [selectedIndexes lastIndex];
        
        for (i = [selectedIndexes firstIndex]; i <= lastIndex; i++) {
            if ([threadsView isRowSelected:i]) {
                if (!isThreadItem([threadsView itemAtRow: i])) return NO;
            }
        }
        return YES;
    }
    return NO;        
}

- (BOOL) validateSelector: (SEL) aSelector
{
    if ( (aSelector == @selector(replyDefault:))
         || (aSelector == @selector(replySender:))
         || (aSelector == @selector(replyAll:))
         || (aSelector == @selector(forward:))
         || (aSelector == @selector(followup:))
         //|| (aSelector == @selector(showTransferData:))
         )
    {
        NSIndexSet *selectedIndexes = [threadsView selectedRowIndexes];
        
        if ([selectedIndexes count] == 1)
        {
            id item = [threadsView itemAtRow:[selectedIndexes firstIndex]];
            if (([item isKindOfClass:[GIMessage class]]) || ([item containsSingleMessage]))
            {
                return YES;
            }
        }
        return NO;
    }
    else if (aSelector == @selector(applySortingAndFiltering:))
    {
        return [self isOnlyThreadsSelected];
    }
    else if (aSelector == @selector(toggleReadFlag:))
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
    if ([menuItem action] == @selector(showRawSource:)) {
		
        [menuItem setState: showRawSource ? NSOnState : NSOffState];
        return ![self threadsShownCurrently];
		
    } else if ([menuItem action] == @selector(toggleReadFlag:)) {
		
        if ([self validateSelector: [menuItem action]]) {
            NSArray* selectedMessages;
            
            if ([self isAnySelectedItemNotHavingMessageflags: OPSeenStatus allSelectedMessages: &selectedMessages]) {
                [menuItem setTitle: NSLocalizedString(@"As Read", @"Menu title for toggling messages to read")];
            } else {
                [menuItem setTitle: NSLocalizedString(@"As Unread", @"Menu title for toggling messages to read")];
            }
            return YES;
        } else return NO;
    } else {
        return [self validateSelector: [menuItem action]];
    }
}

@end

@implementation GIThreadListController (OutlineViewDataSource)

- (void) outlineViewSelectionDidChange: (NSNotification*) notification
{
  if ([notification object] == threadsView) {
	  
        id item = [threadsView itemAtRow: [threadsView selectedRow]];
        
        if ([item isKindOfClass: [OPPersistentObject class]]) {
            item = [item objectURLString];
			[self setValue:item forGroupProperty: @"LastSelectedMessageItem"];
        }
    }
}

- (BOOL) outlineView: (NSOutlineView*) outlineView shouldExpandItem: (id) item
/*" Remembers last expanded thread for opening the next time. "*/
{
    /* hack obsoleted by workaround with itemRetainer
    if (outlineView == threadsView) {
        [tabView selectFirstTabViewItem: self];
		// Retain all messages in thread item:
		[[item messages] makeObjectsPerformSelector: @selector(retain)];
    }
     */
    
    return YES;
}

- (int) outlineView: (NSOutlineView*) outlineView numberOfChildrenOfItem: (id) item
{
    if (outlineView == threadsView) {
		// thread list
        if (! item) {
            return [[self threadsByDate] count];
        } else  {        
			// item should be a thread
            return [[item messages] count];
        }
    } else {
		// boxes list
        if (! item) {
            return [[GIMessageGroup hierarchyRootNode] count] - 1;
        } else if ([item isKindOfClass: [NSMutableArray class]]) {
            return [item count] - 1;
        }
    }
    return 0;
}

- (BOOL) outlineView: (NSOutlineView*) outlineView isItemExpandable: (id) item
{
	// thread list
	if ([item isKindOfClass: [GIThread class]]) {
		//NSLog(@"isItemExpandable");
		return [item messageCount]>1;
		//return ![[self nonExpandableItems] containsObject: item];
	}
    return NO;
}

- (id) outlineView: (NSOutlineView*) outlineView child: (int) index ofItem: (id) item
{
    id result = nil;
	if (! item) {
		result = [[self threadsByDate] objectAtIndex: index];
	} else {            
		result = [[item messagesByTree] objectAtIndex: index];
	}
    [itemRetainer addObject: result];
    return result;
}



- (BOOL) outlineView: (NSOutlineView*) outlineView shouldCollapseItem: (id) item;
{
    /* hack obsoleted by itemRetainer workaround :-)
	if (threadsView == outlineView) {
        // Retain all messages in thread item:
		NSLog(@"Should release opened messages.");
		[[item messages] makeObjectsPerformSelector: @selector(autorelease)]; // could be too early!?
	}
     */
	return YES;
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
    BOOL inSelectionAndAppActive = ([[threadsView selectedItems] containsObject: item] && [NSApp isActive] && [window isMainWindow]);
    
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
            int level = [outlineView levelForItem: item]; // really needed? may be slow!
            
            if (level == 0) {
	        	// it's a thread:		
                GIThread* thread = item;
                
                if ([thread containsSingleMessage]) {
                    NSString* from;
                    NSAttributedString* aFrom;
                    GIMessage* message = [[thread valueForKey: @"messages"] lastObject];
                    
                    if (message) {
                        BOOL isRead  = [message hasFlags: OPSeenStatus];
                        NSString* subject = [message valueForKey: @"subject"];
                        
                        if (!subject) subject = @"";
                        
                        NSAttributedString* aSubject = [[NSAttributedString alloc] initWithString: subject attributes: isRead ? (inSelectionAndAppActive ? selectedReadAttributes() : readAttributes()) : unreadAttributes()];
                        
                        [result appendAttributedString: aSubject];
                        
                        from = [message senderName];
                        from = from ? from : @"- sender missing -";
                        
                        from = [NSString stringWithFormat: @" (%@)", from];
                        
                        aFrom = [[NSAttributedString alloc] initWithString:from attributes: isRead ? (inSelectionAndAppActive ? selectedReadFromAttributes() : readFromAttributes()) : (inSelectionAndAppActive ? selectedUnreadFromAttributes() : unreadFromAttributes())];
                        
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
                NSString* from;
                unsigned indentation = [(GIMessage*) item numberOfReferences];
                
                [result appendAttributedString: spacer()];
                
                for (i = MIN(MAX_INDENTATION, indentation); i > 0; i--) {
                    [result appendAttributedString: spacer()];
                }
                
                [result appendAttributedString: (indentation > MAX_INDENTATION)? spacer2() : spacer()];
                
                from = [item senderName];
                from = from ? from : @"- sender missing -";
                
                [result appendAttributedString: [[NSAttributedString alloc] initWithString: from attributes: [(GIMessage *)item hasFlags: OPSeenStatus] ? (inSelectionAndAppActive ? selectedReadFromAttributes():readFromAttributes()):(inSelectionAndAppActive ? selectedUnreadFromAttributes():unreadFromAttributes())]];
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
    OPObjectPair *hit = [hits objectAtIndex:rowIndex];
    OID oid = [(NSNumber *)[hit firstObject] unsignedLongLongValue];
    GIMessage *message = [[OPPersistentObjectContext threadContext] objectForOid:oid ofClass:[GIMessage class]];
    BOOL isAppActive = YES; // ([NSApp isActive] && [window isMainWindow]);

    if ([[aTableColumn identifier] isEqualToString:@"date"])
    {
        BOOL isRead = [message hasFlags:OPSeenStatus];
        NSCalendarDate *date = [message valueForKey:@"date"];
                
        NSString *dateString = [date descriptionWithCalendarFormat:[[NSUserDefaults standardUserDefaults] objectForKey:NSShortTimeDateFormatString] timeZone:[NSTimeZone localTimeZone] locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
        
        return [[[NSAttributedString alloc] initWithString:dateString attributes:isRead ? (isAppActive ? selectedReadFromAttributes() : readFromAttributes()) : unreadAttributes()] autorelease];
    }
    else if ([[aTableColumn identifier] isEqualToString:@"subjectauthor"])
    {
        NSString *from;
        NSAttributedString *aFrom;
        NSMutableAttributedString* result = [[[NSMutableAttributedString alloc] init] autorelease];
        
        BOOL isRead  = [message hasFlags:OPSeenStatus];
        NSString *subject = [message valueForKey: @"subject"];
        
        if (!subject) subject = @"";
        
        NSAttributedString *aSubject = [[NSAttributedString alloc] initWithString:subject attributes:isRead ? (isAppActive ? selectedReadAttributes() : readAttributes()) : unreadAttributes()];
        
        [result appendAttributedString:aSubject];
        
        from = [message senderName];
        from = from ? from : @"- sender missing -";
        
        from = [NSString stringWithFormat: @" (%@)", from];
        
        aFrom = [[NSAttributedString alloc] initWithString:from attributes: isRead ? (isAppActive ? selectedReadFromAttributes() : readFromAttributes()) : (isAppActive ? selectedUnreadFromAttributes() : unreadFromAttributes())];
        
        [result appendAttributedString:aFrom];
        
        [aSubject release];
        [aFrom release];
        
        return result;
    }
    else if ([[aTableColumn identifier] isEqualToString:@"relevance"])
    {
        return [(OPObjectPair *)hit secondObject]; // the score
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

static NSMutableDictionary *commentsCache = nil;

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

NSMutableArray* border = nil;

- (void) initializeBorderToDepth: (int) aDepth
{
    int i;
    
    [border autorelease];
    border = [[NSMutableArray alloc] initWithCapacity: aDepth];
    for (i = 0; i < aDepth; i++)
        [border addObject: [NSNumber numberWithInt: -1]];
}

- (int) placeTreeWithRootMessage: (GIMessage*) message atOrBelowRow: (int) row inColumn: (int) column
{
    GICommentTreeCell* cell;
    
    if (row <= [[border objectAtIndex:column] intValue])
        row = [[border objectAtIndex:column] intValue] + 1;
        
    NSArray* comments = commentsForMessage(message, displayedThread);
    int commentCount = [comments count];
    
    NSEnumerator* children = [comments objectEnumerator];
    GIMessage* child;
    
    if (child = [children nextObject]) {
        int nextColumn = column + 1;
        int newRow;
        
        row = newRow = [self placeTreeWithRootMessage: child atOrBelowRow: row inColumn: nextColumn];
        
        cell = [commentsMatrix cellAtRow: newRow column: nextColumn];
        [cell addConnectionToEast];
        [cell addConnectionToWest];
        
        while (child = [children nextObject]) {
            int i;
            int startRow = newRow;
            BOOL messageHasDummyParent = [[message reference] isDummy];
            
            newRow = [self placeTreeWithRootMessage: child atOrBelowRow: newRow + 1 inColumn: nextColumn];
            
            [[commentsMatrix cellAtRow: startRow column: nextColumn] addConnectionToSouth];
            
            for (i = startRow+1; i < newRow; i++)
            {
                cell = [commentsMatrix cellAtRow: i column: nextColumn];
                [cell addConnectionToNorth];
                [cell addConnectionToSouth];
                [cell setHasConnectionToDummyMessage: messageHasDummyParent];
            }
            
            cell = [commentsMatrix cellAtRow: newRow column: nextColumn];
            [cell addConnectionToNorth];
            [cell addConnectionToEast];
            [cell setHasConnectionToDummyMessage: messageHasDummyParent];
        }
    }
    
    // update the border
    [border replaceObjectAtIndex: column withObject: [NSNumber numberWithInt: row]];
    
    
    while (row >= [commentsMatrix numberOfRows])
        [commentsMatrix addRow];
    
    cell = [commentsMatrix cellAtRow: row column: column];
    
    
    
    NSArray* siblings = [[message reference] commentsInThread: [self displayedThread]];
    int indexOfMessage = [siblings indexOfObject: message];
        
    if (commentCount > 0)
        [cell addNavigationToEast];
    if ([message numberOfReferences] > 0)
        [cell addNavigationToWest];
    if (indexOfMessage >= 1)
        [cell addNavigationToNorth];
    if ([siblings count] > indexOfMessage + 1)
        [cell addNavigationToSouth];

    // set cell's message attributes
    [cell setRepresentedObject: message];
    [cell setSeen: [message hasFlags: OPSeenStatus]];
    [cell setIsDummyMessage: [message isDummy]];
    [cell setHasConnectionToDummyMessage: [[message reference] isDummy]];
    
    [commentsMatrix setToolTip: [message valueForKey: @"senderName"] forCell:cell];
        
    // for testing we are coloring the messages of David Stes and John C. Randolph
    NSString* senderName = [message senderName];
    if (senderName) {
        NSRange range = [senderName rangeOfString: @"David Stes"];
        if (range.location != NSNotFound)
            [cell setColorIndex:1];  // red
        range = [senderName rangeOfString: @"John C. Randolph"];
        if (range.location != NSNotFound)
            [cell setColorIndex:4];  // green
    }
    
    return row;
}

- (void) updateCommentTree: (BOOL) rebuildThread
{
    if (rebuildThread) {
        [commentsMatrix deselectAllCells];
        [commentsMatrix renewRows: 1 columns: [displayedThread commentDepth]];
        
        commentsCache = [[NSMutableDictionary alloc] init];
        
        //Class cc = [commentsMatrix cellClass];
        //NSCell* aCell = [commentsMatrix cellAtRow:0 column:0];
        
        //NSLog(@"Cells %@", [commentsMatrix cells]);
        
        [[commentsMatrix cells] makeObjectsPerformSelector: @selector(reset)withObject: nil];
        
        // Usually this calls placeMessage:singleRootMessage row:0
        NSEnumerator* me = [[displayedThread rootMessages] objectEnumerator];
        unsigned row = 0;
        GIMessage* rootMessage;
        
        [self initializeBorderToDepth: [displayedThread commentDepth]];
        while (rootMessage = [me nextObject])
            row = [self placeTreeWithRootMessage: rootMessage atOrBelowRow: row inColumn: 0];
        
        //[commentsMatrix selectCell: [commentsMatrix cellForRepresentedObject:displayedMessage]];
        [commentsMatrix sizeToFit];
        [commentsMatrix setNeedsDisplay: YES];
        //[commentsMatrix scrollCellToVisibleAtRow:<#(int)row#> column:<#(int)col#>]];
        
        [commentsCache release];
        commentsCache = nil;
    }
    
    int row, column;
    GICommentTreeCell* cell;
    
    cell = (GICommentTreeCell*) [commentsMatrix cellForRepresentedObject: displayedMessage];
    [cell setSeen: YES];
    
    [commentsMatrix selectCell: cell];
    
    [commentsMatrix getRow: &row column: &column ofCell: cell];
    [commentsMatrix scrollCellToVisibleAtRow: MAX(row-1, 0)column: MAX(column-1,0)];
    [commentsMatrix scrollCellToVisibleAtRow: row+1 column: column+1];
}

- (IBAction)selectTreeCell:(id)sender
/*" Displays the corresponding message. "*/
{
    GIMessage *selectedMessage = [[sender selectedCell] representedObject];
    
    if (selectedMessage) {
        [self setDisplayedMessage:selectedMessage thread: [self displayedThread]];
    }
}

// navigation (triggered by menu and keyboard shortcuts)
- (IBAction) navigateUpInMatrix: (id) sender
/*" Displays the previous sibling message if present in the current thread. Beeps otherwise. "*/
{
    if (![self threadsShownCurrently]) {
        NSArray* comments;
        int indexOfDisplayedMessage;
        
        comments = [[[self displayedMessage] reference] commentsInThread: [self displayedThread]];
        indexOfDisplayedMessage = [comments indexOfObject: [self displayedMessage]];
        
        if ((indexOfDisplayedMessage - 1)>= 0) {
            [self setDisplayedMessage: [comments objectAtIndex: indexOfDisplayedMessage - 1] thread: [self displayedThread]];
            return;
        }
        NSBeep();
    }
}

- (IBAction) navigateDownInMatrix: (id) sender
/*" Displays the next sibling message if present in the current thread. Beeps otherwise. "*/
{
    if (![self threadsShownCurrently]) {
        
        NSArray* comments = [[[self displayedMessage] reference] commentsInThread: [self displayedThread]];
        int indexOfDisplayedMessage = [comments indexOfObject: [self displayedMessage]];
        
        if ([comments count] > indexOfDisplayedMessage + 1) {
            [self setDisplayedMessage: [comments objectAtIndex: indexOfDisplayedMessage + 1] thread: [self displayedThread]];
            return;
        }
        NSBeep();
    }
}

- (IBAction)navigateLeftInMatrix: (id) sender
/*" Displays the parent message if present in the current thread. Beeps otherwise. "*/
{
    if (![self threadsShownCurrently]) {
        GIMessage *newMessage;
        
        if ((newMessage = [[self displayedMessage] reference])) {
            // check if the current thread has the reference:
            if ([[[self displayedThread] messages] containsObject:newMessage]) {
                [self setDisplayedMessage:newMessage thread: [self displayedThread]];
                return;
            }
        }
        NSBeep();
    }
}

- (IBAction) navigateRightInMatrix: (id) sender
/*" Displays the first child message if present in the current thread. Beeps otherwise. "*/
{
    if (![self threadsShownCurrently])
    {
        NSArray* comments = [[self displayedMessage] commentsInThread: [self displayedThread]];
        
        if ([comments count]) {
            [self setDisplayedMessage: [comments objectAtIndex:0] thread: [self displayedThread]];
            return;
        }
        NSBeep();
    }
}

- (BOOL)matrixIsVisible
/*" Returns YES if the comments matrix is shown and not collapsed. NO otherwise "*/
{
    return ![treeBodySplitter isSubviewCollapsed: [[treeBodySplitter subviews] objectAtIndex:0]];
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

- (void) moveThreadsWithURI:(NSArray *)threadURIs fromGroup:(GIMessageGroup *)sourceGroup toGroup:(GIMessageGroup *)destinationGroup
{
    NSEnumerator *enumerator = [threadURIs objectEnumerator];
    NSString *threadURI;
        
    while (threadURI = [enumerator nextObject]) 
    {
        GIThread *thread = [OPPersistentObjectContext objectWithURLString:threadURI];
        NSAssert([thread isKindOfClass:[GIThread class]], @"should be a thread");
        
        // remove thread from source group:
        [thread removeValue: sourceGroup forKey: @"groups"];
        
        // add thread to destination group:
        [thread addValue: destinationGroup forKey: @"groups"];
    }
}

- (BOOL)outlineView:(NSOutlineView *)anOutlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(int)index
{
    if (anOutlineView == threadsView)
    {
        // move threads from source group to destination group:
        NSArray *threadURLs = [[info draggingPasteboard] propertyListForType:@"GinkoThreads"];
        GIMessageGroup *sourceGroup = [(GIThreadListController *)[[info draggingSource] delegate] group];
        GIMessageGroup *destinationGroup = [self group];
        
        [self moveThreadsWithURI:threadURLs fromGroup:sourceGroup toGroup:destinationGroup];
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
        if (! [self isOnlyThreadsSelected]) return NO;
        
        [pboard declareTypes:[NSArray arrayWithObject:@"GinkoThreads"] owner:self];
        [pboard setPropertyList:items forType:@"GinkoThreads"];
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
    
    [[NSWorkspace sharedWorkspace] openFile:filename];
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
    
    NSPoint mouseLocation = [event locationInWindow];
    mouseLocation.x -= 16; // file icons are guaranteed to have 32 by 32 pixels (Mac OS 10.4 NSWorkspace docs)
    mouseLocation.y -= 16;
    mouseLocation = [view convertPoint:mouseLocation toView: nil];
     
    rect = NSMakeRect(mouseLocation.x, mouseLocation.y, 1, 1);
    [view dragFile:filename fromRect:rect slideBack: YES event:event];
}

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag
{
    return NSDragOperationCopy;
}

- (BOOL)ignoreModifierKeysWhileDragging
{
    return YES;
}

- (void) textView: (NSTextView*) textView spaceKeyPressedWithModifierFlags: (int) modifierFlags
{
    if (NSDebugEnabled) NSLog(@"spaceKeyPressedWithModifierFlags");

    GIMessage* result = nil;
    GIMessage* candidate;
    
    NSArray* orderedMessages = [[self displayedThread] messagesByTree];
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