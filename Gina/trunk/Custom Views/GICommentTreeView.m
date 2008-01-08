//
//  GICommentTreeView.m
//  Gina
//
//  Created by Axel Katerbau on 07.10.06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "GICommentTreeView.h"
#import "GICommentTreeCell.h"
#import "GIMessage.h"
#import "GIThread.h"

NSString *CommentTreeViewDidChangeSelectionNotification = @"CommentTreeViewDidChangeSelectionNotification";

@implementation GICommentTreeView

// -- binding stuff --
+ (void)initialize
{
    [self exposeBinding:@"selectedMessage"];	
}

- (Class)valueClassForBinding:(NSString *)binding
{
    // both require numbers
    return [GIMessage class];	
}

- (id)observedObjectForSelectedMessage { return observedObjectForSelectedMessage; }
- (void)setObservedObjectForSelectedMessage:(id)anObservedObjectForSelectedMessage
{
    if (observedObjectForSelectedMessage != anObservedObjectForSelectedMessage) 
	{
        [observedObjectForSelectedMessage release];
        observedObjectForSelectedMessage = [anObservedObjectForSelectedMessage retain];
    }
}

- (NSString *)observedKeyPathForSelectedMessage { return observedKeyPathForSelectedMessage; }
- (void)setObservedKeyPathForSelectedMessage:(NSString *)anObservedKeyPathForSelectedMessage
{
    if (observedKeyPathForSelectedMessage != anObservedKeyPathForSelectedMessage) 
	{
        [observedKeyPathForSelectedMessage release];
        observedKeyPathForSelectedMessage = [anObservedKeyPathForSelectedMessage copy];
    }
}

- (void)bind:(NSString *)bindingName
    toObject:(id)observableController
 withKeyPath:(NSString *)keyPath
     options:(NSDictionary *)options
{	
    if ([bindingName isEqualToString:@"selectedMessage"])
    {
		// observe the controller for changes
		[observableController addObserver:self
							   forKeyPath:keyPath 
								  options:0
								  context:nil];
		
		// register what controller and what keypath are 
		// associated with this binding
		[self setObservedObjectForSelectedMessage:observableController];
		[self setObservedKeyPathForSelectedMessage:keyPath];		
    }
    	
	[super bind:bindingName
	   toObject:observableController
	withKeyPath:keyPath
		options:options];
	
	[self updateCommentTree:YES];
}

- (void)unbind:bindingName
{
    if ([bindingName isEqualToString:@"selectedMessage"])
    {
		[observedObjectForSelectedMessage removeObserver:self
									forKeyPath:observedKeyPathForSelectedMessage];
		[self setObservedObjectForSelectedMessage:nil];
		[self setObservedKeyPathForSelectedMessage:nil];
    }	

	[super unbind:bindingName];
	[self updateCommentTree:YES];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
						change:(NSDictionary *)change
					   context:(void *)context
{
	// selectedMessage changed
	id newSelectedMessage = [observedObjectForSelectedMessage valueForKeyPath:observedKeyPathForSelectedMessage];
	[self setSelectedMessage:newSelectedMessage];
	
	[self updateCommentTree:YES];
}

// -- regular stuff --

- (void)setup
{
    GICommentTreeCell *commentCell = [[[GICommentTreeCell alloc] init] autorelease];
    
    [self putCell:commentCell atRow:0 column:0];
    [self setCellClass:nil];
    [self setPrototype:commentCell];
    [self setCellSize:NSMakeSize(20,10)];
    [self setIntercellSpacing:NSMakeSize(0,0)]; 
}

- (id)initWithFrame:(NSRect)frame 
{
    self = [super initWithFrame:frame];
    if (self) 
	{
		[self setup];
    }
    return self;
}

- (void)dealloc
{
	[self unbind:@"selectedMessage"];

	[commentsCache release];
	[border release];
	[thread removeObserver:self forKeyPath:@"hasUnreadMessages"];
	[thread removeObserver:self forKeyPath:@"messages"];
	[thread release];

	[super dealloc];
}

- (void)drawRect:(NSRect)rect 
{
	[super drawRect:rect];
    // Drawing code here.
}

- (void)awakeFromNib
{
	[self setup];
}

- (GIThread *)thread
{
	return thread;
}

- (void)setThread:(GIThread *)aThread
{
	NSParameterAssert(aThread == nil || [aThread isKindOfClass:[GIThread class]]);
	
	if (aThread != thread)
	{
		[thread removeObserver:self forKeyPath:@"hasUnreadMessages"];
		[thread removeObserver:self forKeyPath:@"messages"];
		[thread autorelease];
		thread = [aThread retain];
		[thread addObserver:self forKeyPath:@"hasUnreadMessages" options:0 context:NULL];
		[thread addObserver:self forKeyPath:@"messages" options:0 context:NULL];
		[self updateCommentTree:YES];
	}
}

- (GIMessage *)selectedMessage
{
	return [[self selectedCell] representedObject];
}

- (void)setSelectedMessage:(GIMessage *)aMessage
{
	if (! [aMessage isKindOfClass:[GIMessage class]])
	{
		[self setThread:nil];
		[self deselectAllCells];
		return;
	}
	
	if ([self thread] != [aMessage thread])
	{
		[self setThread:[aMessage thread]];
	}
	
	if (aMessage)
	{
		[self selectCell:[self cellForRepresentedObject:aMessage]];
	}
	else
	{
		[self deselectAllCells];
	}
}

- (NSArray *)commentsForMessage:(GIMessage *)aMessage inThread:(GIThread *)aThread
{
    NSArray *result = [commentsCache objectForKey:[aMessage objectURLString]];
    
    if (! result) 
	{
        result = [aMessage commentsInThread:aThread];
        [commentsCache setObject:result forKey:[aMessage objectURLString]];
    }
    
    return result;
}

- (void)initializeBorderToDepth:(int)aDepth
{
    int i;
    
    [border autorelease];
    border = [[NSMutableArray alloc] initWithCapacity:aDepth];
    for (i = 0; i < aDepth; i++)
	{
        [border addObject:[NSNumber numberWithInt:-1]];
	}
}

/*"Configures the cell for %message in the tree view.
The cell's position is in the specified column but it's row is the row of the
first child of the message.
If there is no child the cell is in row %row.
The return value is the row the message was placed in."*/
- (int)placeTreeWithRootMessage:(GIMessage *)message andSiblings:(NSArray *)siblings atOrBelowRow:(int)row inColumn:(int)column
{
    GICommentTreeCell *cell;
    
    if (row <= [[border objectAtIndex:column] intValue])
	{
        row = [[border objectAtIndex:column] intValue] + 1;
	}
	
    NSArray *comments = [self commentsForMessage:message inThread:[self thread]];
    int commentCount = [comments count];
    
    NSEnumerator *children = [comments objectEnumerator];
    GIMessage *child;
    
    // place the children first
    if (child = [children nextObject]) 
	{
        int nextColumn = column + 1;
        int newRow;
        
        row = newRow = [self placeTreeWithRootMessage:child andSiblings:comments atOrBelowRow:row inColumn:nextColumn];
        
        // first child
        cell = [self cellAtRow:newRow column:nextColumn];
        [cell addConnectionToEast];  // to child itself (me)
        [cell addConnectionToWest];  // to parent
        
        // other children
        while (child = [children nextObject]) 
		{
            int i;
            int startRow = newRow;
            
            newRow = [self placeTreeWithRootMessage:child andSiblings:comments atOrBelowRow:newRow + 1 inColumn:nextColumn];
            
            [[self cellAtRow:startRow column:nextColumn] addConnectionToSouth];
            
            for (i = startRow+1; i < newRow; i++)
            {
                cell = [self cellAtRow:i column:nextColumn];
                [cell addConnectionToNorth];
                [cell addConnectionToSouth];
            }
            
            cell = [self cellAtRow:newRow column:nextColumn];
            [cell addConnectionToNorth];
            [cell addConnectionToEast];
        }
    }
    
    // update the border
    [border replaceObjectAtIndex:column withObject:[NSNumber numberWithInt:row]];
    
    
    while (row >= [self numberOfRows])
	{
        [self addRow];
	}
	
    // get the cell for the message second
    cell = [self cellAtRow:row column:column];
    
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
    
    [self setToolTip:[message valueForKey:@"senderName"] forCell:cell];
    
    // set color
    if ([message flags] & OPIsFromMeStatus)
	{
        [cell setColorIndex:5];  // blue
	}
    else 
	{
        // for testing we are coloring the messages of David Stes and John C. Randolph
        NSString *senderName = [message senderName];
        if (senderName) 
		{
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

- (void)updateCommentTree:(BOOL)rebuildThread
{
    if (rebuildThread) 
	{
        [self deselectAllCells];
        [self renewRows:1 columns:[[self thread] commentDepth]];
        
        commentsCache = [[NSMutableDictionary alloc] init];
                
        [[self cells] makeObjectsPerformSelector:@selector(reset) withObject:nil];
        
        // Usually this calls placeMessage:singleRootMessage row:0
        NSArray *rootMessages = [[self thread] rootMessages];
        NSEnumerator *me = [rootMessages objectEnumerator];
        unsigned row = 0;
        GIMessage *rootMessage;
        
        [self initializeBorderToDepth:[[self thread] commentDepth]];
		
        while (rootMessage = [me nextObject]) 
		{
            row = [self placeTreeWithRootMessage:rootMessage andSiblings:rootMessages atOrBelowRow:row inColumn:0];
            
            if ([rootMessage reference]) 
			{
                // add "broken" reference
                [[self cellAtRow:row column:0] addConnectionToEast];
            }
        }
        
        [self sizeToFit];
        [self setNeedsDisplay:YES];
        
        [commentsCache release];
        commentsCache = nil;
    }
    
    int row, column;
    GICommentTreeCell *cell;
    
    cell = (GICommentTreeCell *)[self cellForRepresentedObject:[self selectedMessage]];
//    [cell setSeen:YES];
    
    [self selectCell:cell];
    
    [self getRow:&row column:&column ofCell:cell];
    [self scrollCellToVisibleAtRow:MAX(row-1, 0) column:MAX(column-1,0)];
    [self scrollCellToVisibleAtRow:row+1 column:column+1];	
}

- (BOOL)leftMostMessageIsSelected
{
    int row, col;
    
    [self getRow:&row column:&col ofCell:[self selectedCell]];
    
    return col == 0;
}

// navigation (triggered by menu and keyboard shortcuts)
- (IBAction)navigateUpInMatrix:(id)sender
/*" Displays the previous sibling message if present in the current thread. Beeps otherwise. "*/
{
	NSArray *comments;
	int indexOfSelectedMessage;
	
	comments = [[[self selectedMessage] reference] commentsInThread:[self thread]];
	indexOfSelectedMessage = [comments indexOfObject:[self selectedMessage]];
	
	if ((indexOfSelectedMessage - 1) >= 0) 
	{
		[self setSelectedMessage:[comments objectAtIndex:indexOfSelectedMessage - 1]];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:CommentTreeViewDidChangeSelectionNotification object:self];
		return;
	}
	NSBeep();
}

- (IBAction)navigateDownInMatrix:(id)sender
/*" Displays the next sibling message if present in the current thread. Beeps otherwise. "*/
{
	NSArray *comments = [[[self selectedMessage] reference] commentsInThread:[self thread]];
	int indexOfSelectedMessage = [comments indexOfObject:[self selectedMessage]];
	
	if ([comments count] > indexOfSelectedMessage + 1) 
	{
		[self setSelectedMessage:[comments objectAtIndex:indexOfSelectedMessage + 1]];
		[[NSNotificationCenter defaultCenter] postNotificationName:CommentTreeViewDidChangeSelectionNotification object:self];
		return;
	}
	NSBeep();
}

- (IBAction)navigateLeftInMatrix:(id)sender
	/*" Displays the parent message if present in the current thread. Beeps otherwise. "*/
{
	GIMessage *newMessage;
	
	if (newMessage = [[self selectedMessage] reference])
	{
		// check if the current thread has the reference:
		if ([[[self thread] messages] containsObject:newMessage]) 
		{
			[self setSelectedMessage:newMessage];
			[[NSNotificationCenter defaultCenter] postNotificationName:CommentTreeViewDidChangeSelectionNotification object:self];
			return;
		}
	}
	NSBeep();
}

- (IBAction)navigateRightInMatrix:(id)sender
	/*" Displays the first child message if present in the current thread. Beeps otherwise. "*/
{
        NSArray *comments = [[self selectedMessage] commentsInThread:[self thread]];
        
        if ([comments count]) 
        {
            [self setSelectedMessage:[comments objectAtIndex:0]];
			[[NSNotificationCenter defaultCenter] postNotificationName:CommentTreeViewDidChangeSelectionNotification object:self];	
            return;
        }
        NSBeep();
}

@end
