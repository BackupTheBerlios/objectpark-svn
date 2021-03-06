//
//  GICommentTreeView.m
//  Gina
//
//  Created by Axel Katerbau on 07.10.06.
//  Copyright 2006 Objectpark Group. All rights reserved.
//

#import "GICommentTreeView.h"
#import "GICommentTreeCell.h"
#import "GIMessage.h"
#import "GIThread.h"

@implementation GICommentTreeView

// -- binding stuff --
+ (void)initialize
{
    [self exposeBinding:@"selectedMessageOrThread"];	
}

- (Class)valueClassForBinding:(NSString *)binding
{
    return [NSObject class];	
}

- (id)observedObjectForSelectedMessageOrThread { return observedObjectForSelectedMessageOrThread; }
- (void)setObservedObjectForSelectedMessageOrThread:(id)anObservedObjectForSelectedMessageOrThread
{
    if (observedObjectForSelectedMessageOrThread != anObservedObjectForSelectedMessageOrThread) 
	{
        [observedObjectForSelectedMessageOrThread release];
        observedObjectForSelectedMessageOrThread = [anObservedObjectForSelectedMessageOrThread retain];
    }
}

- (NSString *)observedKeyPathForSelectedMessageOrThread { return observedKeyPathForSelectedMessageOrThread; }
- (void)setObservedKeyPathForSelectedMessageOrThread:(NSString *)anObservedKeyPathForSelectedMessageOrThread
{
    if (observedKeyPathForSelectedMessageOrThread != anObservedKeyPathForSelectedMessageOrThread) 
	{
        [observedKeyPathForSelectedMessageOrThread release];
        observedKeyPathForSelectedMessageOrThread = [anObservedKeyPathForSelectedMessageOrThread copy];
    }
}

- (void)bind:(NSString *)bindingName
    toObject:(id)observableController
 withKeyPath:(NSString *)keyPath
     options:(NSDictionary *)options
{	
    if ([bindingName isEqualToString:@"selectedMessageOrThread"])
    {
		// observe the controller for changes
		[observableController addObserver:self
							   forKeyPath:keyPath 
								  options:0
								  context:nil];
		
		// register what controller and what keypath are 
		// associated with this binding
		[self setObservedObjectForSelectedMessageOrThread:observableController];
		[self setObservedKeyPathForSelectedMessageOrThread:keyPath];		
    }
    	
	[super bind:bindingName
	   toObject:observableController
	withKeyPath:keyPath
		options:options];
	
	[self updateCommentTree:YES];
}

- (void)unbind:bindingName
{
    if ([bindingName isEqualToString:@"selectedMessageOrThread"])
    {
		[observedObjectForSelectedMessageOrThread removeObserver:self
									forKeyPath:observedKeyPathForSelectedMessageOrThread];
		[self setObservedObjectForSelectedMessageOrThread:nil];
		[self setObservedKeyPathForSelectedMessageOrThread:nil];
    }	

	[super unbind:bindingName];
	[self updateCommentTree:YES];
}

- (void)refreshFlags
{
	for (GIMessage *message in self.thread.messages)
	{
		GICommentTreeCell *cell = (GICommentTreeCell *)[self cellForRepresentedObject:message];
		BOOL messageIsSeen = message.isSeen;
		if ([cell seen] != messageIsSeen)
		{
			[cell setSeen:messageIsSeen];
			[self setNeedsDisplay:YES];
		}
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
						change:(NSDictionary *)change
					   context:(void *)context
{
	if ([keyPath isEqualToString:observedKeyPathForSelectedMessageOrThread])
	{
		// SelectedMessageOrThread changed
		id newSelectedMessageOrThread = [observedObjectForSelectedMessageOrThread valueForKeyPath:observedKeyPathForSelectedMessageOrThread];
		[self setSelectedMessageOrThread:newSelectedMessageOrThread];
	}
	else if ([keyPath isEqualToString:@"isSeen"])
	{
		[self refreshFlags];
	}
	else if ([keyPath isEqualToString:@"messages"])
	{
		[self updateCommentTree:YES];
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
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
	[self unbind:@"selectedMessageOrThread"];

	[commentsCache release];
	[border release];
	[thread removeObserver:self forKeyPath:@"isSeen"];
	[thread removeObserver:self forKeyPath:@"messages"];
	[thread release];

	[super dealloc];
}

/*
- (void)drawRow:(NSInteger)row clipRect:(NSRect)clipRect
{
	[super drawRow: row clipRect: clipRect];
}
*/

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
		[thread removeObserver:self forKeyPath:@"isSeen"];
		[thread removeObserver:self forKeyPath:@"messages"];
		[thread autorelease];
		thread = [aThread retain];
		[thread addObserver:self forKeyPath:@"isSeen" options:0 context:NULL];
		[thread addObserver:self forKeyPath:@"messages" options:0 context:NULL];
		
		[self updateCommentTree:YES];
	}
}

- (GIMessage *)selectedMessage
{
	return [[self selectedCell] representedObject];
}

- (void)setSelectedMessageOrThread:(id)anObject
{
	GIMessage *message = [anObject isKindOfClass:[GIMessage class]] ? anObject : nil;
	GIThread *theThread = message ? message.thread : anObject;
	
	if (![theThread isKindOfClass:[GIThread class]] || [theThread.messages count] <= 1) 
	{
		[self setThread:nil];
		[self deselectAllCells];
		[selectedMessageOrThread release]; selectedMessageOrThread = nil;
		return;
	}
	
	selectedMessageOrThread = [anObject retain];
	
	[self setThread:theThread];
	
	if (message)
	{
		NSCell *cell = [self cellForRepresentedObject:message];
		[self selectCell:cell];
		[self updateCommentTree:NO];
//		NSLog(@"selecting message: %@", message);
	}
	else
	{
		[self deselectAllCells];
	}
}

- (id)selectedMessageOrThread;
{
	return selectedMessageOrThread;
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
    
	// TODO: add message date also with right formatter
	NSString *toolTip = message.senderName;
    [self setToolTip:toolTip forCell:cell];
    
    // set color
    if (message.flags & OPIsFromMeStatus) {
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
//    NSLog(@"Selecting cell: %@", cell);
	
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

/*" Displays the previous sibling message if present in the current thread. Beeps otherwise. "*/
- (IBAction)navigateUpInMatrix:(id)sender
{
	NSArray *comments;
	int indexOfSelectedMessage;
	
	comments = [[[self selectedMessage] reference] commentsInThread:[self thread]];
	indexOfSelectedMessage = [comments indexOfObject:[self selectedMessage]];
	
	if ((indexOfSelectedMessage - 1) >= 0) 
	{
		[self setSelectedMessageOrThread:[comments objectAtIndex:indexOfSelectedMessage - 1]];
		if (self.target && self.action)
		{
			[self.target performSelector:self.action withObject:nil];
		}
		return;
	}
	NSBeep();
}

/*" Displays the next sibling message if present in the current thread. Beeps otherwise. "*/
- (IBAction)navigateDownInMatrix:(id)sender
{
	NSArray *comments = [[[self selectedMessage] reference] commentsInThread:[self thread]];
	int indexOfSelectedMessage = [comments indexOfObject:[self selectedMessage]];
	
	if ([comments count] > indexOfSelectedMessage + 1) 
	{
		[self setSelectedMessageOrThread:[comments objectAtIndex:indexOfSelectedMessage + 1]];
		if (self.target && self.action)
		{
			[self.target performSelector:self.action withObject:nil];
		}
		return;
	}
	NSBeep();
}

/*" Displays the parent message if present in the current thread. Beeps otherwise. "*/
- (IBAction)navigateLeftInMatrix:(id)sender
{
	GIMessage *newMessage;
	
	if (newMessage = [[self selectedMessage] reference])
	{
		// check if the current thread has the reference:
		if ([[[self thread] messages] containsObject:newMessage]) 
		{
			[self setSelectedMessageOrThread:newMessage];
			if (self.target && self.action)
			{
				[self.target performSelector:self.action withObject:nil];
			}
			return;
		}
	}
	NSBeep();
}

/*" Displays the first child message if present in the current thread. Beeps otherwise. "*/
- (IBAction)navigateRightInMatrix:(id)sender
{
        NSArray *comments = [[self selectedMessage] commentsInThread:[self thread]];
        
        if ([comments count]) 
        {
            [self setSelectedMessageOrThread:[comments objectAtIndex:0]];
			if (self.target && self.action)
			{
				[self.target performSelector:self.action withObject:nil];
			}
            return;
        }
        NSBeep();
}

- (BOOL)acceptsFirstResponder
{
	return NO;
}

@end
