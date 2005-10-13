//
//  $Id: G3GroupController.m,v 1.126 2005/05/17 18:34:19 mikesch Exp $
//  GinkoVoyager
//
//  Created by Axel Katerbau on 03.12.04.
//  Copyright 2004, 2005 Objectpark.org. All rights reserved.
//

#import "G3GroupController.h"
#import "GIMessage+Rendering.h"
#import "GIThread.h"
#import "G3CommentTreeCell.h"
#import <Foundation/NSDebug.h>
#import "NSToolbar+OPExtensions.h"
#import "GIMessageEditorController.h"
#import "GIProfile.h"
#import "OPCollapsingSplitView.h"
#import "GIUserDefaultsKeys.h"
#import "GIApplication.h"
#import "NSArray+Extensions.h"
#import "G3GroupInspectorController.h"
#import "OPPersistentObject+Extensions.h"
#import "GIMessageGroup.h"
#import "OPJobs.h"
#import "GIFulltextIndexCenter.h"
#import "GIOutlineViewWithKeyboardSupport.h"
#import "GIMessage.h"
#import "GIMessageBase.h"
#import "NSString+Extensions.h"
#import "GIMessageFilter.h"

static NSString *ShowOnlyRecentThreads = @"ShowOnlyRecentThreads";

@interface G3GroupController (CommentsTree)

- (void)awakeCommentTree;
- (void)deallocCommentTree;
- (IBAction)selectTreeCell:(id)sender;
- (void)updateCommentTree:(BOOL)rebuildThread;
- (BOOL)matrixIsVisible;

@end

@implementation G3GroupController

- (id)init
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(modelChanged:) name:@"GroupContentChangedNotification" object:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(modelChanged:) name:OPJobDidFinishNotification object:MboxImportJobName];
    return [[super init] retain]; // self retaining!
}

- (id)initWithGroup:(GIMessageGroup *)aGroup
{
    if (self = [self init])
    {
        [NSBundle loadNibNamed:@"Group" owner:self];
        
        if (! aGroup) {
            aGroup = [[GIMessageGroup allObjects] firstObject];
        }
        
        [self setGroup: aGroup];
    }
    
    return self;
}

- (id)initAsStandAloneBoxesWindow:(GIMessageGroup *)aGroup
{
    if (self = [self init])
    {
        [NSBundle loadNibNamed:@"Boxes" owner:self];
        [self setGroup:aGroup];
		
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(groupsChanged:) name:GIMessageGroupWasAddedNotification object:nil];
    }
    
    return self;
}

- (BOOL)isStandaloneBoxesWindow
{
    return (threadsView == nil);
}

static NSPoint lastTopLeftPoint = {0.0, 0.0};

- (void)awakeFromNib
{
    if ([GIApp isGroupsDrawerMode])
    {
        [boxesDrawer open:self]; 
    }
    
    [boxesView setTarget:self];
    [boxesView setDoubleAction:@selector(showGroupWindow:)];
    // Register to grok GinkoMessages and GinkoMessageboxes drags
    [boxesView registerForDraggedTypes:[NSArray arrayWithObjects:@"GinkoThreads", @"GinkoMessageboxes", nil]];
    [boxesView setAutosaveName:@"boxesView"];
    [boxesView setAutosaveExpandedItems:YES];
    
    [threadsView setTarget:self];
    [threadsView setDoubleAction:@selector(openSelection:)];
    [threadsView setHighlightThreads:YES];
    [threadsView registerForDraggedTypes:[NSArray arrayWithObjects:@"GinkoThreads", nil]];
    
    [self awakeToolbar];
    [self awakeCommentTree];

    lastTopLeftPoint = [window cascadeTopLeftFromPoint:lastTopLeftPoint];
    
    [window makeKeyAndOrderFront:self];    
}

- (void)dealloc
{
    NSLog(@"G3GroupController dealloc");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [window setDelegate:nil];
    
    [self deallocCommentTree];
    [self deallocToolbar];

    [displayedMessage release];
    [displayedThread release];
    [self setGroup:nil];
    [threadCache release];
    [nonExpandableItemsCache release];
    
    [super dealloc];
}

- (id)valueForGroupProperty:(NSString *)prop
/*" Used for accessing user defaults for current message group. "*/
{
    NSString *key = [[[self group] objectURL] absoluteString];
    if (key)
    {
        NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
        return [[ud objectForKey:key] objectForKey:prop];
    }
    return nil;
}

- (void)setValue:(id)value forGroupProperty:(NSString *)prop 
/*" Used for accessing user defaults for current message group. "*/
{
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    NSString *key = [[[self group] objectURL] absoluteString];
    
    NSMutableDictionary* groupProperties = [[ud objectForKey:key] mutableCopy];
    if (!groupProperties) groupProperties = [[NSMutableDictionary alloc] init];
    
    if (value)
    {
        [groupProperties setObject:value forKey:prop];
    }
    else
    {
        [groupProperties removeObjectForKey:prop];
    }
    
    [ud setObject:groupProperties forKey:key];
    [groupProperties release];
}

- (void)windowWillClose:(NSNotification *)notification 
{
    lastTopLeftPoint = NSMakePoint(0.0, 0.0); // reset cascading
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
        itemRow = [threadsView rowForItemEqualTo:[[aThread objectURL] absoluteString] startingAtRow:0];
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
            fixedFont = [[NSDictionary alloc] initWithObjectsAndKeys:[NSFont userFixedPitchFontOfSize:10], NSFontAttributeName,
                                                                     nil, nil];
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
        messageText = [[NSAttributedString alloc] initWithString:@"Warning: Unable to decode message. messageText == nil."];
    
    [[messageTextView textStorage] setAttributedString:messageText];
    
    // set the insertion point (cursor)to 0, 0
    [messageTextView setSelectedRange: NSMakeRange(0, 0)];
    [messageTextView sizeToFit];
    // make sure that the message's header is displayed:
    [messageTextView scrollRangeToVisible: NSMakeRange(0, 0)];

    [self updateCommentTree:isNewThread];
    
    //BOOL collapseTree = [commentsMatrix numberOfColumns]<=1;
    // Hide comment tree, if trivial:
    //[treeBodySplitter setSubview:[[treeBodySplitter subviews] objectAtIndex:0] isCollapsed:collapseTree];
    //if (YES && !collapseTree){
    if (isNewThread) {
        NSScrollView* scrollView = [[treeBodySplitter subviews] objectAtIndex:0];
        //[scrollView setFrameSize:NSMakeSize([scrollView frame].size.width, [commentsMatrix frame].size.height+15.0)];
        //[treeBodySplitter moveSplitterBy:[commentsMatrix frame].size.height+10-[scrollView frame].size.height];
        //[scrollView setAutohidesScrollers:YES];
        BOOL hasHorzontalScroller = [commentsMatrix frame].size.width>[scrollView frame].size.width;
        float newHeight = [commentsMatrix frame].size.height+3+(hasHorzontalScroller*[NSScroller scrollerWidth]); // scroller width could be different
        [scrollView setHasHorizontalScroller:hasHorzontalScroller];
        if ([commentsMatrix numberOfColumns]<=1)
            newHeight = 0;
        if (newHeight>200.0)
        {
            newHeight = 200.0;
            [scrollView setHasVerticalScroller:YES];
            //[scrollView setAutohidesScrollers:YES];
        } else {
            [scrollView setHasVerticalScroller:NO];
        }
        [treeBodySplitter setFirstSubviewSize:newHeight];
    }
    //}
    //[commentsMatrix scrollCellToVisibleAtRow:[commentsMatrix selectedRow] column:[commentsMatrix selectedRow]];

}

- (GIMessage*)displayedMessage
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
            if (! [[win delegate] isStandaloneBoxesWindow])
            {
                if ([[win delegate] group] == aGroup)
                {
                    return win;
                }
            }
        }
    }
    
    return nil;
}

/*
- (IBAction) showThreads2: (id) sender
{
    GIMessageGroup *selectedGroup = [GIMessageGroup messageGroupWithURIReferenceString:[boxesView itemAtRow:[boxesView selectedRow]]];
    
    NSLog(@"Fetching Threads via CoreData...");
    [selectedGroup threadsByDate];
    NSLog(@"Fetched Threads via CoreData.");
}
   */

- (IBAction)showGroupWindow:(id)sender
/*" Shows group in a own window if no such window exists. Otherwise brings up that window to front. "*/
{
    GIMessageGroup *selectedGroup = [GIMessageGroup messageGroupWithURIReferenceString:[boxesView itemAtRow:[boxesView selectedRow]]];
    
    if (selectedGroup && [selectedGroup isKindOfClass:[GIMessageGroup class]]) 
    {
        NSWindow *groupWindow = [[self class] windowForGroup:selectedGroup];
        
        if (groupWindow) 
        {
            [groupWindow makeKeyAndOrderFront:self];
        } 
        else 
        {
            G3GroupController *newController = [[[G3GroupController alloc] initWithGroup:selectedGroup] autorelease];
            groupWindow = [newController window];
        }
        
        [[groupWindow delegate] showThreads:sender];
    }
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
    [newCache retain];
    [threadCache release];
    threadCache = newCache;
}

- (NSMutableSet *)nonExpandableItemsCache
{
    return nonExpandableItemsCache;
}

- (void)setNonExpandableItemsCache:(NSMutableSet *)newCache
{
    [newCache retain];
    [nonExpandableItemsCache release];
    nonExpandableItemsCache = newCache;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([object isEqual:[self group]]) 
    {
        NSNotification *notification;
        
        NSLog(@"observeValueForKeyPath %@", keyPath);
//        [self modelChanged:nil];
        notification = [NSNotification notificationWithName:@"GroupContentChangedNotification" object:self];
        
        [[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostWhenIdle coalesceMask:NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender forModes:nil];
    }
    // the same change
    //    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
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

- (void) cacheThreadsAndExpandableItems
{
    if ([self group]) {
        NSMutableArray* results         = [NSMutableArray arrayWithCapacity: 500];
        NSMutableSet* trivialThreadURIs = [NSMutableSet setWithCapacity: 250];
        
        [self setThreadCache: results];
        [self setNonExpandableItemsCache: trivialThreadURIs];
        
        [[self group] fetchThreadURIs: &results
                       trivialThreads: &trivialThreadURIs
                            newerThan: [self nowForThreadFiltering]
                          withSubject: nil
                               author: nil 
                sortedByDateAscending: YES];
    }
}

- (NSArray*) threadIdsByDate
/*" Returns an ordered list of all message threads of the receiver, ordered by date. "*/
{
    NSMutableArray* result = [self threadCache];
    
    if (!result) {
        [self cacheThreadsAndExpandableItems];
        result = [self threadCache];
    }
    return result;
}

- (NSSet*) nonExpandableItems
{
    NSMutableSet* result = [self nonExpandableItemsCache];
    
    if (!result) {
        [self cacheThreadsAndExpandableItems];
        result = [self nonExpandableItemsCache];
    }
    return result;
}

- (BOOL)openSelection:(id)sender
{    
    if (sender == boxesView)
    {
        // open group window:
        [self showGroupWindow:sender];
        return YES;
    }
    
    if ([self threadsShownCurrently])
    {
        int selectedRow = [threadsView selectedRow];
        
        if (selectedRow >= 0)
        {
            GIMessage *message = nil;
            GIThread *selectedThread = nil;
            id item;
            
            item = [threadsView itemAtRow:selectedRow];
            
            if ([threadsView levelForRow:selectedRow] > 0)
            {
                // it's a message, show it:
                message = item;
                // find the thread above message:
                while ([threadsView levelForRow:--selectedRow]){}
                selectedThread = [OPPersistentObjectContext objectWithURIString:[threadsView itemAtRow:selectedRow]];
            }
            else 
            {
                selectedThread = [OPPersistentObjectContext objectWithURIString: item];
                
                if ([selectedThread containsSingleMessage]) 
                {
                    message = [[selectedThread valueForKey:@"messages"] anyObject];
                } 
                else 
                {
                    if ([threadsView isItemExpanded:item])  
                    {
                        [threadsView collapseItem:item];
                    } 
                    else 
                    {
                        NSEnumerator *enumerator;
                        GIMessage *message;
                        
                        [threadsView expandItem:item];                    
                        // ##TODO:select first "interesting" message of this thread
                        // perhaps the next/first unread message
                        
                        enumerator = [[selectedThread messagesByTree] objectEnumerator];
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
                    }
                    return YES;
                }
            }
            
            if ([message hasFlags:OPDraftStatus] || [message hasFlags:OPQueuedStatus])
            {
                if ([message hasFlags:OPInSendJobStatus])
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
                
                [message addFlags:OPSeenStatus];
                
                [self setDisplayedMessage:message thread:selectedThread];
                
                if ([self matrixIsVisible])
                {
                    [window makeFirstResponder:commentsMatrix];
                } else {
                    [window makeFirstResponder:messageTextView];                    
                }
            }
        }
        
    } else {
        // message shown
        if ([window firstResponder] == commentsMatrix)
        {
            [window makeFirstResponder:messageTextView];
        }
    }
    return YES;
}

- (IBAction)closeSelection:(id)sender
{
    if (sender == messageTextView)
    {
        if ([self matrixIsVisible])
        {
            [window makeFirstResponder:commentsMatrix];
        }
        else
        {
            [tabView selectFirstTabViewItem:sender];
        }
    } 
    else 
    {
        if ([[[tabView selectedTabViewItem] identifier] isEqualToString:@"message"])
        {
            if ([window firstResponder] == messageTextView)
            {
                if ([self matrixIsVisible])
                {
                    [window makeFirstResponder:commentsMatrix];
                }
                else
                {
                    [tabView selectFirstTabViewItem:sender];
                }
            } 
            else 
            {
                 // from message switch back to threads:
                [tabView selectFirstTabViewItem:sender];
            }
        } 
        else 
        {
            if (![self isStandaloneBoxesWindow])
            {
            // from threads switch back to the groups window:
                [[GIApp standaloneGroupsWindow] makeKeyAndOrderFront:sender];
            }
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
    GIMessage *result = nil;
    id item;
    
    item = [threadsView itemAtRow:[threadsView selectedRow]];
    if ([item isKindOfClass:[GIMessage class]])
    {
        result = item;
    }
    else
    {
        result = [[[OPPersistentObjectContext objectWithURIString: item] messagesByTree] lastObject];
        if (! [result isKindOfClass:[GIMessage class]])
        {
            result = nil;
        }
    }    
    
    return result;
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
    GIMessage *message = [self selectedMessage];
    
    [self placeSelectedTextOnQuotePasteboard];
    
    [[[GIMessageEditorController alloc] initReplyTo:message all:NO profile:[self profileForMessage:message]] autorelease];
}

- (IBAction)followup:(id)sender
{
    GIMessage *message = [self selectedMessage];
    
    [self placeSelectedTextOnQuotePasteboard];
    
    [[[GIMessageEditorController alloc] initFollowupTo:message profile:[[self group] defaultProfile]] autorelease];
}

- (IBAction)replyAll:(id)sender
{
    GIMessage *message = [self selectedMessage];
    
    [self placeSelectedTextOnQuotePasteboard];
    
    [[[GIMessageEditorController alloc] initReplyTo:message all:YES profile:[self profileForMessage:message]] autorelease];
}

- (IBAction)replyDefault:(id)sender
{
    GIMessage *message = [self selectedMessage];

    if ([message isListMessage] || [message isUsenetMessage])
    {
        [self followup:sender];
    }
    else
    {
        [self replySender:sender];
    }
}

- (IBAction)forward:(id)sender
{
    GIMessage *message = [self selectedMessage];
        
    [[[GIMessageEditorController alloc] initForward:message profile:[self profileForMessage:message]] autorelease];
}

- (IBAction)rename:(id)sender
/*" Renames the selected item (folder or group). "*/
{
    int lastSelectedRow;
    
    if ( (lastSelectedRow = [boxesView selectedRow]) != -1)
    {
        [boxesView editColumn:0 row:lastSelectedRow withEvent:nil select:YES];
    }
}

- (IBAction)addFolder:(id)sender
{
    int selectedRow = [boxesView selectedRow];
    [boxesView setAutosaveName:nil];
    [GIMessageGroup addNewHierarchyNodeAfterEntry:[boxesView itemAtRow:selectedRow]];
    [boxesView reloadData];
    [boxesView setAutosaveName:@"boxesView"];
    
    [boxesView selectRow:selectedRow + 1 byExtendingSelection:NO];
    [self rename:self];
}

- (IBAction)addMessageGroup:(id)sender
{
    int selectedRow = [boxesView selectedRow];
    id item = [boxesView itemAtRow:selectedRow];
    NSMutableArray *node = nil;
    int index;
    
    if ([item isKindOfClass:[NSMutableArray class]])
    {
        node = item;
        index = 0;
        [boxesView expandItem:item];
    }
    else
    {
        node = [GIMessageGroup findHierarchyNodeForEntry:item startingWithHierarchyNode:[GIMessageGroup hierarchyRootNode]];
        
        if (node)
        {
            index = [node indexOfObject:item]; // +1 correction already in!
        }
        else
        {
            node = [GIMessageGroup hierarchyRootNode];
            index = 0;
        }
    }
    
    [GIMessageGroup newMessageGroupWithName:nil atHierarchyNode:node atIndex:index];
    
    [boxesView reloadData];
    
    [boxesView setAutosaveName:@"boxesView"];
    [boxesView selectRow:selectedRow + 1 byExtendingSelection:NO];
    [self rename:self];
}

- (IBAction)removeFolderMessageGroup:(id)sender
{
    NSLog(@"-removeFolderMessageGroup: needs to be implemented");
}

- (IBAction)applySortingAndFiltering:(id)sender
/*" Applies sorting and filtering to the selected threads. The selected threads are removed from the receivers group and only added again if they fit in no group defined by sorting and filtering. "*/
{
    NSIndexSet *selectedIndexes = [threadsView selectedRowIndexes];
    int lastIndex  = [selectedIndexes lastIndex];
    int firstIndex = [selectedIndexes firstIndex];
    int i;
    for (i = firstIndex; i <= lastIndex; i++)
    {
        if ([threadsView isRowSelected:i])
        {
            // get one of the selected threads:
            GIThread *thread = [OPPersistentObjectContext objectWithURIString:[threadsView itemAtRow:i]];
            NSAssert([thread isKindOfClass:[GIThread class]], @"assuming object is a thread");
            
            // remove selected thread from receiver's group:
            [[self group] removeThread:thread];
            BOOL threadWasPutIntoAtLeastOneGroup = NO;
            
            @try
            {
                // apply sorters and filters (and readd threads that have no fit to avoid dangling threads):
                NSEnumerator *enumerator = [[thread messages] objectEnumerator];
                GIMessage *message;
                
                while (message = [enumerator nextObject])
                {
                    threadWasPutIntoAtLeastOneGroup |= [GIMessageFilter filterMessage:message flags:0];
                }
            }
            @catch (NSException *localException)
            {
                @throw;
            }
            @finally
            {
                if (!threadWasPutIntoAtLeastOneGroup) [[self group] addThread:thread];
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
    
    [self setValue:[NSNumber numberWithInt:[[threadFilterPopUp selectedItem] tag]] forGroupProperty:ShowOnlyRecentThreads];

    [self modelChanged:nil];
}

/*
- (void)moveToTrash:(id)sender
    /"Forwards command to move selected messages to trash message box."/
{
    [messageListController trashSelectedMessages:self];
}
*/

- (IBAction)showGroupInspector:(id)sender
{
    if ([self isStandaloneBoxesWindow])
    {
        GIMessageGroup *selectedGroup = [boxesView itemAtRow:[boxesView selectedRow]];
        
        if ([selectedGroup isKindOfClass:[GIMessageGroup class]])
        {
            [G3GroupInspectorController groupInspectorForGroup:selectedGroup];
        }
    }
    else
    {
        [G3GroupInspectorController groupInspectorForGroup:[self group]];
    }
}

- (BOOL)threadsShownCurrently
/*" Returns YES if the tab with the threads outline view is currently visible. NO otherwise. "*/
{
    return [[[tabView selectedTabViewItem] identifier] isEqualToString:@"threads"];
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

- (NSArray *)selectedThreadURIs
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

- (void)joinThreadsWithURIs:(NSArray *)uriArray
{
    NSEnumerator *e = [[self selectedThreadURIs] objectEnumerator];
    NSString *targetThreadURI = [e nextObject];
    GIThread *targetThread = [OPPersistentObjectContext objectWithURIString: targetThreadURI];
    [threadsView selectRow: [threadsView rowForItem: targetThreadURI] byExtendingSelection: NO];
    [[self nonExpandableItemsCache] removeObject: targetThreadURI]; 
    [threadsView expandItem: targetThreadURI];

    //NSLog(@"Merging other threads into %@", targetThread);    

    // prevent merge problems:
    //[[OPPersistentObjectContext threadContext] refreshObject: [self group] mergeChanges: YES];
    
    NSString* nextThreadURI;
    while (nextThreadURI = [e nextObject]) 
    {
        GIThread* nextThread = [OPPersistentObjectContext objectWithURIString: nextThreadURI];
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
        GIThread* thread = [OPPersistentObjectContext objectWithURIString: uri];
        NSString* subject = [thread valueForKey: @"subject"];
        if (subject) {
            // query database
            NSMutableArray* result = [NSMutableArray array];
            
            [[self group] fetchThreadURIs: &result 
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

- (IBAction)moveSelectionToTrash:(id)sender
{
    int rowBefore = [[threadsView selectedRowIndexes] firstIndex] - 1;
    NSEnumerator *enumerator = [[self selectedThreadURIs] objectEnumerator];
    NSString *uriString;
    BOOL trashedAtLeastOne = NO;
    
    // Make sure we have a fresh group object and prevent merge problems:
    //[[NSManagedObjectContext threadContext] refreshObject:[self group] mergeChanges:YES];
    
    while (uriString = [enumerator nextObject]) 
    {
        GIThread *thread = [OPPersistentObjectContext objectWithURIString:uriString];
        NSAssert([thread isKindOfClass:[GIThread class]], @"got non-thread object");
        
       // [thread removeFromAllGroups];
        [[self group] removeThread:thread];
        [GIMessageBase addTrashThread:thread];
        trashedAtLeastOne = YES;
    }
    
    if (trashedAtLeastOne) 
    {
        [NSApp saveAction:self];
        if (rowBefore >= 0)
        {
            [threadsView selectRow:rowBefore byExtendingSelection:NO];
        }
    }
    
    else NSBeep();
}

- (void) updateWindowTitle
{
    if (! [self isStandaloneBoxesWindow]) {
        [window setTitle:[NSString stringWithFormat:@"%@", [group valueForKey: @"name"]]];
    }
}

- (void)updateGroupInfoTextField
{
    if (![self isStandaloneBoxesWindow])
    {
//        NSNumber *messageCount = [group valueForKeyPath:@"threads.@sum.messages.@count"];
//        NSNumber *messageCount = [NSNumber numberWithInt:0];
        
        [groupInfoTextField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%u threads", "group info text template"), [[self threadIdsByDate] count]]];
    }    
}

- (void)modelChanged:(NSNotification *)aNotification
{
    // Re-query all threads keeping the selection, if possible.
    NSArray* selectedItems = [threadsView selectedItems];
    if (NSDebugEnabled) NSLog(@"GroupController detected a model change. Cache cleared, OutlineView reloaded, group info text updated.");
    [self setThreadCache:nil];
    [self setNonExpandableItemsCache:nil];
    [self updateGroupInfoTextField];
    [threadsView deselectAll:nil];
//#warning Is this clever? Maybe!
/*    if ([self group])
    {
        [[OPPersistentObjectContext threadContext] refreshObject:[self group] mergeChanges:NO];
    }
    */
    [threadsView reloadData];
    //NSLog(@"Re-Selecting items %@", selectedItems);
    [threadsView selectItems:selectedItems ordered:YES];
}

- (GIMessageGroup *)group
{
    return group;
}

- (void)setGroup:(GIMessageGroup *)aGroup
{
    if (aGroup != group)
    {
        //NSLog(@"Setting group for controller: %@", [aGroup description]);
        
        // key value observing:
        if (![self isStandaloneBoxesWindow])
        {
            [group removeObserver:self forKeyPath:@"threads"];
            [aGroup addObserver:self forKeyPath:@"threads" options:NSKeyValueObservingOptionNew context:NULL];
        }
        
        [group autorelease];
        group = [aGroup retain];
        
        // thread filter popup:
        [threadFilterPopUp selectItemWithTag:[[self valueForGroupProperty:ShowOnlyRecentThreads] intValue]];
        
        [self updateWindowTitle];
        [self updateGroupInfoTextField];
        
        int boxRow = [boxesView rowForItem:group];
        [boxesView selectRow:boxRow byExtendingSelection:NO];
        [boxesView scrollRowToVisible:boxRow];
        
        [threadsView reloadData];
        
        [threadsView setAutosaveName:[@"ThreadsOutline" stringByAppendingString:[[group objectURL] description] ? [[group objectURL] description] : @"nil"]];
        [threadsView setAutosaveTableColumns:YES];
        [threadsView setAutosaveExpandedItems:NO];
        
        // Show last selected item:
        NSString *itemURI = [self valueForGroupProperty:@"LastSelectedMessageItem"];
        
        if (itemURI)
        {
            id item = [OPPersistentObjectContext objectWithURIString:itemURI];
            if (item)
            {
                GIMessage *message = nil;
                GIThread *thread = nil;
                
                if ([item isKindOfClass:[GIThread class]])
                {
                    thread = item;
                }
                else
                {
                    message = item;
                    thread = [message thread];
                }
                
                int itemRow = [threadsView rowForItemEqualTo:[[thread objectURL] absoluteString] startingAtRow:0];
                
                if (itemRow >= 0) 
                {
                    [threadsView selectRow:itemRow byExtendingSelection:NO];
                    
                    if (![thread containsSingleMessage])
                    {
                        [self openSelection:self];
                    }
                    [threadsView scrollRowToVisible:itemRow];
                }
            }
        }
    }
}

static BOOL isThreadItem(id item)
{
    return [item isKindOfClass:[NSString class]];
}

// validation

- (BOOL)isOnlyThreadsSelected
{
    // true when only threads are selected; false otherwise
    NSIndexSet *selectedIndexes;
    
    selectedIndexes = [threadsView selectedRowIndexes];
    if ((! [self isStandaloneBoxesWindow]) && ([selectedIndexes count] > 0))
    {
        int i, lastIndex;
        
        lastIndex = [selectedIndexes lastIndex];
        
        for (i = [selectedIndexes firstIndex]; i <= lastIndex; i++)
        {
            if ([threadsView isRowSelected:i])
            {
                if (!isThreadItem([threadsView itemAtRow:i])) return NO;
            }
        }
        
        return YES;
    }
    
    return NO;        
}

- (BOOL)validateSelector:(SEL)aSelector
{
    if ( (aSelector == @selector(replyDefault:))
         || (aSelector == @selector(replySender:))
         || (aSelector == @selector(replyAll:))
         || (aSelector == @selector(forward:))
         || (aSelector == @selector(followup:))
         //|| (aSelector == @selector(showTransferData:))
         )
    {
        NSIndexSet *selectedIndexes;
        
        selectedIndexes = [threadsView selectedRowIndexes];
        if ((! [self isStandaloneBoxesWindow])&& ([selectedIndexes count] == 1))
        {
            id item = [threadsView itemAtRow:[selectedIndexes firstIndex]];
            if (([item isKindOfClass:[GIMessage class]]) || ([[OPPersistentObjectContext objectWithURIString: item] containsSingleMessage]))
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
        return ![self threadsShownCurrently];
    }
    else
    {
        return [self validateSelector:[menuItem action]];
    }
}

@end

@implementation G3GroupController (OutlineViewDataSource)

- (void)groupsChanged:(NSNotification *)aNotification
{
    [boxesView reloadData];
}

- (void)outlineViewSelectionDidChange:(NSNotification*)notification
{
    if ([notification object] == boxesView)
    {
        id item = [boxesView itemAtRow:[boxesView selectedRow]];
        
        if ([item isKindOfClass:[NSString class]])
        {
            [self setGroup:[GIMessageGroup messageGroupWithURIReferenceString:item]];
        }
    }
    else if ([notification object] == threadsView)
    {
        id item = [threadsView itemAtRow:[threadsView selectedRow]];
        
        if ([item isKindOfClass: [OPPersistentObject class]]) {
            item = [[item objectURL] absoluteString];
        }
        
        [self setValue:item forGroupProperty:@"LastSelectedMessageItem"];
    }
}

- (BOOL)outlineView:(NSOutlineView*)outlineView shouldExpandItem:(id)item
/*" Remembers last expanded thread for opening the next time. "*/
{
    if (outlineView == threadsView) // subjects list
    {
        [tabView selectFirstTabViewItem:self];
    }
    
    return YES;
}

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if (outlineView == threadsView)// subjects list
    {
        if (! item) 
        {
            return [[self threadIdsByDate] count];
        } 
        else 
        {
            GIThread *thread = [OPPersistentObjectContext objectWithURIString: item];
            
            return [[thread messages] count];
        }
    } 
    else // boxes list
    {
        if (! item) 
        {
            return [[GIMessageGroup hierarchyRootNode] count] - 1;
        }
        else if ([item isKindOfClass:[NSMutableArray class]])
        {
            return [item count] - 1;
        }
    }
    return 0;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    if (outlineView == threadsView) 
    {
        // subjects list
        if ([item isKindOfClass:[NSString class]])
        {
            //NSLog(@"isItemExpandable");
            return ![[self nonExpandableItems] containsObject:item];
            /*
            GIThread *thread = threadForItem(item);
#warning this might be a performance killer as thread fault objects will be fired
            return ![thread containsSingleMessage];
             */
        }
    }
    else // boxes list
    {
        return [item isKindOfClass:[NSMutableArray class]];
    }
    
    return NO;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
    if (outlineView == threadsView) // subjects list
    {
        if (! item) 
        {
            return [[self threadIdsByDate] objectAtIndex:index];
        } 
        else 
        {
            GIThread *thread = [OPPersistentObjectContext objectWithURIString: item];
            
            return [[thread messagesByTree] objectAtIndex:index];
        }
    } 
    else // boxes list
    {
        if (!item) 
        {
            item = [GIMessageGroup hierarchyRootNode];
        }
        
        return [item objectAtIndex:index + 1];
    }
    
    return nil;
}

// diverse attributes
NSDictionary *unreadAttributes()
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

NSDictionary *readAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes)
    {
        attributes = [[NSDictionary alloc] initWithObjectsAndKeys:
            [NSFont systemFontOfSize:12], NSFontAttributeName,
            [[NSColor blackColor] highlightWithLevel:0.15], NSForegroundColorAttributeName, nil];
    }
    
    return attributes;
}

NSDictionary *selectedReadAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes)
    {
        attributes = [[readAttributes()mutableCopy] autorelease];
        [(NSMutableDictionary *)attributes setObject:[[NSColor selectedMenuItemTextColor] shadowWithLevel:0.15] forKey:NSForegroundColorAttributeName];
        attributes = [attributes copy];
    }
    
    return attributes;
}

NSDictionary *fromAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes)
    {
        attributes = [[readAttributes()mutableCopy] autorelease];
        [(NSMutableDictionary *)attributes setObject:[[NSColor darkGrayColor] shadowWithLevel:0.3] forKey:NSForegroundColorAttributeName];

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
        [(NSMutableDictionary *)attributes setObject:[[NSColor selectedMenuItemTextColor] shadowWithLevel:0.15] forKey:NSForegroundColorAttributeName];
        attributes = [attributes copy];
    }
    
    return attributes;
}

NSDictionary *readFromAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes)
    {
        attributes = [[fromAttributes()mutableCopy] autorelease];
        [(NSMutableDictionary *)attributes addEntriesFromDictionary:readAttributes()];
        [(NSMutableDictionary *)attributes setObject:[[NSColor darkGrayColor] highlightWithLevel:0.25] forKey:NSForegroundColorAttributeName];
        attributes = [attributes copy];
    }
    
    return attributes;
}

NSDictionary *selectedReadFromAttributes()
{
    static NSDictionary *attributes = nil;
    
    if (! attributes)
    {
        attributes = [[readFromAttributes()mutableCopy] autorelease];
        [(NSMutableDictionary *)attributes setObject:[[NSColor selectedMenuItemTextColor] shadowWithLevel:0.15] forKey:NSForegroundColorAttributeName];
        attributes = [attributes copy];
    }
    
    return attributes;
}

static NSAttributedString* spacer()
/*" String for inserting for message inset. "*/
{
    static NSAttributedString *spacer = nil;
    if (! spacer){
        spacer = [[NSAttributedString alloc] initWithString:@"   "];
    }
    return spacer;
}

static NSAttributedString* spacer2()
/*" String for inserting for messages which are to deep to display insetted. "*/
{
    static NSAttributedString *spacer = nil;
    if (! spacer){
        spacer = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%C ", 0x21e5]];
    }
    return spacer;
}

#define MAX_INDENTATION 4

- (BOOL)isInSelection:(id)item
{
    return [[threadsView selectedRowIndexes] containsIndex:[threadsView rowForItem:item]];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    BOOL inSelectionAndAppActive = ([self isInSelection:item] && [NSApp isActive] && [window isMainWindow]);
    
    if (outlineView == threadsView)// subjects list
    {
        if ([[tableColumn identifier] isEqualToString:@"date"])
        {
            if ([item isKindOfClass:[NSString class]])
            {
                item = [OPPersistentObjectContext objectWithURIString: item];
            }

            BOOL isRead = ([item isKindOfClass:[GIThread class]])? ![(GIThread *)item hasUnreadMessages] :[(GIMessage *)item hasFlags:OPSeenStatus];
            
            NSCalendarDate *date = [item valueForKey:@"date"];
            
//            NSAssert1([date isKindOfClass:[NSCalendarDate class]], @"NSCalendarDate expected but got %@", NSStringFromClass([date class]));
            
            NSString *dateString = [date descriptionWithCalendarFormat:[[NSUserDefaults standardUserDefaults] objectForKey: NSShortTimeDateFormatString] timeZone:[NSTimeZone localTimeZone] locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
                            
            return [[[NSAttributedString alloc] initWithString:dateString attributes:isRead ? (inSelectionAndAppActive ? selectedReadFromAttributes():readFromAttributes()):unreadAttributes()] autorelease];
        }
        
        if ([[tableColumn identifier] isEqualToString:@"subject"])
        {
            NSMutableAttributedString *result = nil;
            int i, level;
            
            result = [[[NSMutableAttributedString alloc] init] autorelease];
            level = [outlineView levelForItem: item];
            
            if (level == 0) 
            {
		// it's a thread:		
                GIThread *thread = [OPPersistentObjectContext objectWithURIString: item];
                
                if ([thread containsSingleMessage]) 
                {
                    NSString *from;
                    NSAttributedString *aFrom;
                    
                    GIMessage *message = [[thread valueForKey:@"messages"] anyObject];
                    
                    if (message) 
                    {
                        BOOL isRead  = [message hasFlags:OPSeenStatus];
                        NSString *subject = [message valueForKey:@"subject"];
                        
                        if (!subject) subject = @"";
                        
                        NSAttributedString *aSubject = [[NSAttributedString alloc] initWithString:subject attributes:isRead ? (inSelectionAndAppActive ? selectedReadAttributes(): readAttributes()): unreadAttributes()];
                        
                        [result appendAttributedString: aSubject];
                        
                        from = [message senderName];
                        from = from ? from : @"- sender missing -";
                        
                        from = [NSString stringWithFormat:@" (%@)", from];
                        
                        aFrom = [[NSAttributedString alloc] initWithString:from attributes: isRead ? (inSelectionAndAppActive ? selectedReadFromAttributes():readFromAttributes()):(inSelectionAndAppActive ? selectedUnreadFromAttributes():unreadFromAttributes())];
                        
                        [result appendAttributedString:aFrom];
                        
                        [aSubject release];
                        [aFrom release];
                    }
                }
                else // contains more than one message
                {
                    return [[[NSAttributedString alloc] initWithString:[thread valueForKey:@"subject"] attributes:[thread hasUnreadMessages] ? unreadAttributes():(inSelectionAndAppActive ? selectedReadAttributes():readAttributes())] autorelease];
                }
            }
            else // a message, not a thread
            {
                NSString *from;
                unsigned indentation = [(GIMessage *)item numberOfReferences];
                
                [result appendAttributedString: spacer()];
                
                for (i = MIN(MAX_INDENTATION, indentation); i > 0; i--)
                {
                    [result appendAttributedString: spacer()];
                }
                
                [result appendAttributedString: (indentation > MAX_INDENTATION)? spacer2():spacer()];
                
                from = [item senderName];
                from = from ? from :@"- sender missing -";
                
                [result appendAttributedString:[[NSAttributedString alloc] initWithString:from attributes:[(GIMessage *)item hasFlags:OPSeenStatus] ? (inSelectionAndAppActive ? selectedReadFromAttributes():readFromAttributes()):(inSelectionAndAppActive ? selectedUnreadFromAttributes():unreadFromAttributes())]];
            }
            
            return result;
        }
    }
    else // boxes list
    {
        if ([[tableColumn identifier] isEqualToString:@"box"]) 
        {
            if ([item isKindOfClass:[NSMutableArray class]])
            {
                return [[item objectAtIndex:0] valueForKey:@"name"];
            }
            else if (item)
            {
                return [[GIMessageGroup messageGroupWithURIReferenceString:item] name];
            }
        }
        if ([[tableColumn identifier] isEqualToString:@"info"])
        {
            if (![item isKindOfClass:[NSMutableArray class]])
            {
                GIMessageGroup *g = [GIMessageGroup messageGroupWithURIReferenceString:item];
                NSMutableArray *threadURIs = [NSMutableArray array];
                NSCalendarDate *date = [[NSCalendarDate date] dateByAddingYears:0 months:0 days:-1 hours:0 minutes:0 seconds:0];
                
                [g fetchThreadURIs:&threadURIs
                    trivialThreads:NULL
                         newerThan:[date timeIntervalSinceReferenceDate]
                       withSubject:nil
                            author:nil
             sortedByDateAscending:YES];
                return [NSNumber numberWithInt:[threadURIs count]];
            }
        }
    }
    
    return @"";
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    if (outlineView == boxesView)
    {
        if ([item isKindOfClass:[NSMutableArray class]]) // folder
        {
            [[item objectAtIndex:0] setObject:object forKey:@"name"];
            [GIMessageGroup commitChanges];
            //[outlineView selectRow:[outlineView rowForItem:item]+1 byExtendingSelection:NO];
            //[[outlineView window] endEditingFor:outlineView];
        }
        else // message group
        {
            [(GIMessageGroup *)[GIMessageGroup messageGroupWithURIReferenceString:item] setValue:object forKey:@"name"];
            [NSApp saveAction:self];
        }
    }
}

- (id)outlineView:(NSOutlineView *)outlineView itemForPersistentObject:(id)object
{
    if (outlineView == boxesView)
    {
        return [GIMessageGroup hierarchyNodeForUid:object];
    }
    
    return nil;
}

- (id)outlineView:(NSOutlineView *)outlineView persistentObjectForItem:(id)item
{
    if (outlineView == boxesView)
    {
        if ([item isKindOfClass:[NSMutableArray class]])
        {
            return [[item objectAtIndex:0] objectForKey:@"uid"];
        }
    }
    
    return nil;
}

@end

@implementation G3GroupController (CommentsTree)

- (void)awakeCommentTree
/*" awakeFromNib part for the comment tree. Called from -awakeFromNib. "*/
{
    G3CommentTreeCell* commentCell = [[[G3CommentTreeCell alloc] init] autorelease];
    
    [commentsMatrix putCell:commentCell atRow:0 column:0];
    [commentsMatrix setCellClass:nil];
    [commentsMatrix setPrototype:commentCell];
    [commentsMatrix setCellSize:NSMakeSize(20,10)];
    [commentsMatrix setIntercellSpacing:NSMakeSize(0,0)]; 
    [commentsMatrix setAction:@selector(selectTreeCell:)];
    [commentsMatrix setTarget:self];
    [commentsMatrix setNextKeyView:messageTextView];
    [messageTextView setNextKeyView:commentsMatrix];
    NSAssert([messageTextView nextKeyView]==commentsMatrix, @"setNExtKeyView did not work");

}

- (void)deallocCommentTree
{
}

// fill in commentsMatrix

static NSMutableDictionary *commentsCache = nil;

NSArray *commentsForMessage(GIMessage *aMessage, GIThread *aThread)
{
    NSArray *result;
    
    result = [commentsCache objectForKey:[aMessage objectURL]];
    
    if (! result)
    {
        result = [aMessage commentsInThread:aThread];
        [commentsCache setObject:result forKey:[aMessage objectURL]];
    }
    
    return result;
}

NSMutableArray* border = nil;

- (void)initializeBorderToDepth:(int)aDepth
{
    int i;
    
    [border autorelease];
    border = [[NSMutableArray alloc] initWithCapacity:aDepth];
    for (i = 0; i < aDepth; i++)
        [border addObject:[NSNumber numberWithInt:-1]];
}

- (int)placeTreeWithRootMessage:(GIMessage*)message atOrBelowRow:(int)row inColumn:(int)column
{
    G3CommentTreeCell* cell;
    
    if (row <= [[border objectAtIndex:column] intValue])
        row = [[border objectAtIndex:column] intValue] + 1;
        
    NSArray* comments = commentsForMessage(message, displayedThread);
    int commentCount = [comments count];
    
    NSEnumerator* children = [comments objectEnumerator];
    GIMessage* child;
    
    if (child = [children nextObject])
    {
        int nextColumn = column + 1;
        int newRow;
        
        row = newRow = [self placeTreeWithRootMessage:child atOrBelowRow:row inColumn:nextColumn];
        
        cell = [commentsMatrix cellAtRow:newRow column:nextColumn];
        [cell addConnectionToEast];
        [cell addConnectionToWest];
        
        while (child = [children nextObject])
            {
            int i;
            int startRow = newRow;
            BOOL messageHasDummyParent = [[message reference] isDummy];
            
            newRow = [self placeTreeWithRootMessage:child atOrBelowRow:newRow + 1 inColumn:nextColumn];
            
            [[commentsMatrix cellAtRow:startRow column:nextColumn] addConnectionToSouth];
            
            for (i = startRow+1; i < newRow; i++)
            {
                cell = [commentsMatrix cellAtRow:i column:nextColumn];
                [cell addConnectionToNorth];
                [cell addConnectionToSouth];
                [cell setHasConnectionToDummyMessage:messageHasDummyParent];
            }
            
            cell = [commentsMatrix cellAtRow:newRow column:nextColumn];
            [cell addConnectionToNorth];
            [cell addConnectionToEast];
            [cell setHasConnectionToDummyMessage:messageHasDummyParent];
        }
    }
    
    // update the border
    [border replaceObjectAtIndex:column withObject:[NSNumber numberWithInt:row]];
    
    
    while (row >= [commentsMatrix numberOfRows])
        [commentsMatrix addRow];
    
    cell = [commentsMatrix cellAtRow:row column:column];
    
    
    
    NSArray* siblings = [[message reference] commentsInThread:[self displayedThread]];
    int indexOfMessage = [siblings indexOfObject:message];
        
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
    [cell setIsDummyMessage: [message isDummy]];
    [cell setHasConnectionToDummyMessage: [[message reference] isDummy]];
    
    [commentsMatrix setToolTip:[message valueForKey:@"author"] forCell:cell];
        
    // for testing we are coloring the messages of David Stes and John C. Randolph
    NSString* senderName = [message senderName];
    if (senderName)
    {
        NSRange range = [senderName rangeOfString:@"David Stes"];
        if (range.location != NSNotFound)
            [cell setColorIndex:1];  // red
        range = [senderName rangeOfString:@"John C. Randolph"];
        if (range.location != NSNotFound)
            [cell setColorIndex:4];  // green
    }
    
    return row;
}

- (void)updateCommentTree:(BOOL)rebuildThread
{
    if (rebuildThread)
    {
        [commentsMatrix deselectAllCells];
        [commentsMatrix renewRows:1 columns:[displayedThread commentDepth]];
        
        commentsCache = [[NSMutableDictionary alloc] init];
        
        //Class cc = [commentsMatrix cellClass];
        //NSCell* aCell = [commentsMatrix cellAtRow:0 column:0];
        
        //NSLog(@"Cells %@", [commentsMatrix cells]);
        
        [[commentsMatrix cells] makeObjectsPerformSelector:@selector(reset)withObject:nil];
        
        // Usually this calls placeMessage:singleRootMessage row:0
        NSEnumerator* me = [[displayedThread rootMessages] objectEnumerator];
        unsigned row = 0;
        GIMessage* rootMessage;
        
        [self initializeBorderToDepth:[displayedThread commentDepth]];
        while (rootMessage = [me nextObject])
            row = [self placeTreeWithRootMessage:rootMessage atOrBelowRow:row inColumn:0];
        
        //[commentsMatrix selectCell:[commentsMatrix cellForRepresentedObject:displayedMessage]];
        [commentsMatrix sizeToFit];
        [commentsMatrix setNeedsDisplay:YES];
        //[commentsMatrix scrollCellToVisibleAtRow:<#(int)row#> column:<#(int)col#>]];
        
        [commentsCache release];
        commentsCache = nil;
    }
    
    int row, column;
    G3CommentTreeCell *cell;
    
    cell = (G3CommentTreeCell *)[commentsMatrix cellForRepresentedObject:displayedMessage];
    [cell setSeen:YES];
    
    [commentsMatrix selectCell:cell];
    
    [commentsMatrix getRow:&row column:&column ofCell:cell];
    [commentsMatrix scrollCellToVisibleAtRow:MAX(row-1, 0)column:MAX(column-1,0)];
    [commentsMatrix scrollCellToVisibleAtRow:row+1 column:column+1];
}

- (IBAction)selectTreeCell:(id)sender
/*" Displays the corresponding message. "*/
{
    GIMessage *selectedMessage = [[sender selectedCell] representedObject];
    
    if (selectedMessage)
    {
        [self setDisplayedMessage:selectedMessage thread:[self displayedThread]];
    }
}

// navigation (triggered by menu and keyboard shortcuts)
- (IBAction)navigateUpInMatrix:(id)sender
/*" Displays the previous sibling message if present in the current thread. Beeps otherwise. "*/
{
    if (![self threadsShownCurrently])
    {
        NSArray *comments;
        int indexOfDisplayedMessage;
        
        comments = [[[self displayedMessage] reference] commentsInThread:[self displayedThread]];
        indexOfDisplayedMessage = [comments indexOfObject:[self displayedMessage]];
        
        if ((indexOfDisplayedMessage - 1)>= 0)
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
    if (![self threadsShownCurrently])
    {
        NSArray *comments;
        int indexOfDisplayedMessage;
        
        comments = [[[self displayedMessage] reference] commentsInThread:[self displayedThread]];
        indexOfDisplayedMessage = [comments indexOfObject:[self displayedMessage]];
        
        if ([comments count] > indexOfDisplayedMessage + 1)
        {
            [self setDisplayedMessage:[comments objectAtIndex:indexOfDisplayedMessage + 1] thread:[self displayedThread]];
            return;
        }
        NSBeep();
    }
}

- (IBAction)navigateLeftInMatrix:(id)sender
/*" Displays the parent message if present in the current thread. Beeps otherwise. "*/
{
    if (![self threadsShownCurrently])
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

- (IBAction)navigateRightInMatrix:(id)sender
/*" Displays the first child message if present in the current thread. Beeps otherwise. "*/
{
    if (![self threadsShownCurrently])
    {
        NSArray *comments;
        
        comments = [[self displayedMessage] commentsInThread:[self displayedThread]];
        
        if ([comments count])
        {
            [self setDisplayedMessage:[comments objectAtIndex:0] thread:[self displayedThread]];
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

@implementation G3GroupController (ToolbarDelegate)
/*" Toolbar delegate methods and setup and teardown. "*/

- (void)awakeToolbar
/*" Called from within -awakeFromNib. "*/
{
    if (![self isStandaloneBoxesWindow])
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

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    return [NSToolbar toolbarItemForItemIdentifier:itemIdentifier fromToolbarItemArray:toolbarItems];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return defaultIdentifiers;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    static NSArray *allowedItemIdentifiers = nil;
    
    if (! allowedItemIdentifiers)
    {
        NSEnumerator *enumerator;
        NSToolbarItem *item;
        NSMutableArray *allowed;
        
        allowed = [NSMutableArray arrayWithCapacity:[toolbarItems count] + 5];
        
        enumerator = [toolbarItems objectEnumerator];
        while (item = [enumerator nextObject])
        {
            [allowed addObject:[item itemIdentifier]];
        }
        
        [allowed addObjectsFromArray:[NSArray arrayWithObjects:NSToolbarSeparatorItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSpaceItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, nil]];
        
        allowedItemIdentifiers = [allowed copy];
    }
    
    return allowedItemIdentifiers;
}

@end

@implementation G3GroupController (DragNDrop)

- (void)moveThreadsWithURI:(NSArray *)threadURIs 
                 fromGroup:(GIMessageGroup *)sourceGroup 
                   toGroup:(GIMessageGroup *)destinationGroup
{
    NSEnumerator *enumerator = [threadURIs objectEnumerator];
    NSString *threadURI;
    
    // Prevent merge problems:
    //[[NSManagedObjectContext threadContext] refreshObject: [self group] mergeChanges: YES];
    
    while (threadURI = [enumerator nextObject]) 
    {
        GIThread *thread = [OPPersistentObjectContext objectWithURIString:threadURI];
        NSAssert([thread isKindOfClass:[GIThread class]], @"should be a thread");
        
        // remove thread from source group:
        [thread removeFromGroups:sourceGroup];
        
        // add thread to destination group:
        [thread addToGroups:destinationGroup];
    }
}

- (BOOL)outlineView:(NSOutlineView *)anOutlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(int)index
{
    if (anOutlineView == boxesView) // Message Groups list
    {
        NSArray *items;
        
        if (! item) item = [GIMessageGroup hierarchyRootNode];
        
        items = [[info draggingPasteboard] propertyListForType:@"GinkoMessageboxes"];
        if ([items count] == 1) // only single selection supported at this time!
        {
            // Hack (part 1)! Why is this necessary to archive almost 'normal' behavior?
            [boxesView setAutosaveName:nil];
            
            [GIMessageGroup moveEntry:[items lastObject] toHierarchyNode:item atIndex:index testOnly:NO];
            
            [anOutlineView reloadData];
            
            // Hack (part 2)! Why is this necessary to archive almost 'normal' behavior?
            [boxesView setAutosaveName:@"boxesView"];
            
            return YES;
        }
        
        NSArray *threadURLs = [[info draggingPasteboard] propertyListForType:@"GinkoThreads"];
        if ([threadURLs count])
        {
            GIMessageGroup *sourceGroup = [(G3GroupController *)[[info draggingSource] delegate] group];
            GIMessageGroup *destinationGroup = [OPPersistentObjectContext objectWithURIString:item];
            
            [self moveThreadsWithURI:threadURLs fromGroup:sourceGroup toGroup:destinationGroup];
            
            // select all in dragging source:
            NSOutlineView *sourceView = [info draggingSource];        
            [sourceView selectRow:[sourceView selectedRow] byExtendingSelection:NO];
            
            [NSApp saveAction:self];
        }
    }
    else if (anOutlineView == threadsView)
    {
        // move threads from source group to destination group:
        NSArray *threadURLs = [[info draggingPasteboard] propertyListForType:@"GinkoThreads"];
        GIMessageGroup *sourceGroup = [(G3GroupController *)[[info draggingSource] delegate] group];
        GIMessageGroup *destinationGroup = [self group];
        
        [self moveThreadsWithURI:threadURLs fromGroup:sourceGroup toGroup:destinationGroup];
        /*
        NSEnumerator *enumerator = [threadURLs objectEnumerator];
        NSString *threadURL;
        
        while (threadURL = [enumerator nextObject])
        {
            GIThread *thread = [OPPersistentObjectContext objectWithURIString:threadURL];
            NSAssert([thread isKindOfClass:[GIThread class]], @"should be a thread");
            
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
    if (anOutlineView == boxesView) // Message Groups
    {
        NSArray *items = [[info draggingPasteboard] propertyListForType:@"GinkoMessageboxes"];
        
        if ([items count] == 1) 
        {
            if (index != NSOutlineViewDropOnItemIndex) // accept only when no on item
            {
                if ([GIMessageGroup moveEntry:[items lastObject] toHierarchyNode:item atIndex:index testOnly:YES])
                {
                    [anOutlineView setDropItem:item dropChildIndex:index]; 
                    
                    return NSDragOperationMove;
                }
            }
        }
        
        NSArray *threadURLs = [[info draggingPasteboard] propertyListForType:@"GinkoThreads"];
        if ([threadURLs count])
        {
            if (index == NSOutlineViewDropOnItemIndex)
            {
                return NSDragOperationMove;
            }
        }
        
        return NSDragOperationNone;
    }
    else if (anOutlineView == threadsView)
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
    if (outlineView == boxesView) // Message Groups list
    {
        // ##WARNING works only for single selections. Not for multi selection!
        
        [pboard declareTypes:[NSArray arrayWithObject:@"GinkoMessageboxes"] owner:self];    
        [pboard setPropertyList:items forType:@"GinkoMessageboxes"];
    }
    else if (outlineView == threadsView) // threads list
    {
        if (! [self isOnlyThreadsSelected]) return NO;
        
        [pboard declareTypes:[NSArray arrayWithObject:@"GinkoThreads"] owner:self];
        [pboard setPropertyList:items forType:@"GinkoThreads"];
    }
    
    return YES;
}

/*
- (NSImage *)dragImageForRowsWithIndexes:(NSIndexSet *)dragRows tableColumns:(NSArray *)tableColumns event:(NSEvent*)dragEvent offset:(NSPointPointer)dragImageOffset
{
    if (outlineView == threadsView) // threads list
    {
        return nil;
    }
    else
    {
        return [super dragImageForRowsWithIndexes:dragRows tableColumns:tableColumns event:dragEvent offset:dragImageOffset];
    }
}
*/

@end

@implementation G3GroupController (SplitViewDelegate)

- (void)splitView:(NSSplitView*)sender resizeSubviewsWithOldSize:(NSSize)oldSize
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

@implementation G3GroupController (TextViewDelegate)

- (void)textView:(NSTextView *)textView doubleClickedOnCell:(id <NSTextAttachmentCell>)cell inRect:(NSRect)cellFrame atIndex:(unsigned)charIndex
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

- (void)textView:(NSTextView *)view draggedCell:(id <NSTextAttachmentCell>)cell inRect:(NSRect)rect event:(NSEvent *)event atIndex:(unsigned)charIndex
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
    mouseLocation = [view convertPoint:mouseLocation toView:nil];
     
    rect = NSMakeRect(mouseLocation.x, mouseLocation.y, 1, 1);
    [view dragFile:filename fromRect:rect slideBack:YES event:event];
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