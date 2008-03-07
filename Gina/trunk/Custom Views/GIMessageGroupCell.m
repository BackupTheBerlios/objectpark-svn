//
//  GIMessageGroupCell.m
//  Gina
//
//  Created by Axel Katerbau on 13.10.07.
//  Copyright 2007 Objectpark Group. All rights reserved.
//

#import "GIMessageGroupCell.h"
#import "GIMessageGroup.h"
#import "NSBezierPath+RoundedRect.h"
#import "NSColor+ContrastingLabelExtensions.h"

@implementation GIMessageGroupCell

- (id)initTextCell:(NSString *)txt 
{
	self = [super initTextCell:txt];
	
	if (self) 
	{
		[self setImage:nil];
		[self setLineBreakMode:NSLineBreakByTruncatingMiddle];
	}
	
	return self;
}

- (id)initImageCell:(NSImage *)cellImg 
{
	self = [self initTextCell:@"Default text"];
	
	if (self) 
	{
		[self setImage:cellImg];
	}
	
	return self;
}

- (void)dealloc
{
	[super dealloc];
}

- (NSImage *)image 
{
	return image;
}

- (void)setImage:(NSImage *)newImage 
{
	image = newImage;
}

- (NSRect)expansionFrameWithFrame:(NSRect)cellFrame inView:(NSView *)view
{
	return NSZeroRect;
}

- (id)hierarchyItem
{
	return hierarchyItem;
}

- (void)setHierarchyItem:(id)anItem
{
	hierarchyItem = anItem;
}

- (NSUInteger)unreadCount
{
	id object = [self hierarchyItem];
	if ([object isKindOfClass: [GIMessageGroup class]]) {
		return [(GIMessageGroup*) object unreadMessageCount];
	}
	return 0;
}

/*" Centers the image vertically. "*/
- (NSRect)imageRectForBounds:(NSRect)bounds 
{
	NSSize imageSize = [image size];
	NSRect result = bounds;
	result.origin.x += 5;
	result.origin.y += MAX(2, bounds.size.height-imageSize.height)/2;
	result.size = imageSize;
	return result;
	//return NSMakeRect(bounds.origin.x + 5, bounds.origin.y + 1, bounds.size.height - 2, bounds.size.height - 2);
}

- (NSAttributedString *)attributedCountStringWithColor:(NSColor *)aColor
{
	unsigned unreadCount = [self unreadCount];
//	unsigned participantCountHistoric = MAX(participantCount, [[self filePool] participantCountHistoric]);
	NSString *countString = [NSString stringWithFormat:@"%d", unreadCount];
	return [[[NSAttributedString alloc] initWithString:countString attributes:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		aColor, NSForegroundColorAttributeName, 
		[NSFont boldSystemFontOfSize:11], NSFontAttributeName,
		nil]] autorelease];
}

- (NSRect)countRectForBounds:(NSRect)bounds
{
	if ([self unreadCount] == 0) return NSZeroRect;
	
	float width = MAX(25.0, [[self attributedCountStringWithColor:[NSColor blackColor]] size].width + 11.5);
	
#define PILLHEIGHT 14
	
	float padding = ((bounds.size.height - PILLHEIGHT) / 2); // - .5;
	return NSMakeRect((bounds.origin.x + bounds.size.width - width) - 5, bounds.origin.y + padding, width, PILLHEIGHT);
}

- (NSRect)titleRectForBounds:(NSRect)bounds 
{
	NSRect imageRect = [self imageRectForBounds:bounds];
	NSRect countRect = [self countRectForBounds:bounds];
//	NSSize titleSize = [[self title] sizeWithAttributes:nil];
	NSRect titleRect = bounds;
	
	titleRect.origin.y += 1;
	titleRect.origin.x += 10;
	if ([self image] != nil) 
	{
		titleRect.origin.x += /*imageRect.origin.x + */ imageRect.size.width;
		titleRect.size.width -= imageRect.size.width + 5;
		if ([self unreadCount] != 0)
		{
			titleRect.size.width -= (countRect.size.width + 8);
		}
	}
//	titleRect.origin.y = titleRect.origin.y + (bounds.size.height - titleSize.height) / 2;
	titleRect.size.width -= 5; // padding right
	
	return titleRect;
}

- (NSColor *)pillColor
{
	static NSColor *pillColor = nil;
	if (!pillColor) 
	{
		pillColor = [[NSColor colorWithCalibratedRed:0.5859 green:0.6641 blue:0.7773 alpha:1.0] retain];
	}
	return pillColor;
}

- (void)drawTextWithFrame:(NSRect)frame inView:(NSView *)controlView
{	
	NSColor *contrastingLabelColor = nil;
	
	if ([self isHighlighted]) contrastingLabelColor = [[NSColor alternateSelectedControlColor] contrastingLabelColor];
	
	/*
	static NSDictionary *statusLineAttributes = nil;
	if (!statusLineAttributes)
	{
		NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [style setLineBreakMode:NSLineBreakByTruncatingMiddle];
		
		statusLineAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:
			[NSFont systemFontOfSize:9.0], NSFontAttributeName,
			style, NSParagraphStyleAttributeName,
			nil, nil];
		[style release];
	}
	
	static NSMutableDictionary *greenStatusLineAttributes = nil;
	
	if (!greenStatusLineAttributes)
	{
		greenStatusLineAttributes = [[NSMutableDictionary alloc] initWithDictionary:statusLineAttributes];
		[greenStatusLineAttributes setObject:[[NSColor greenColor] shadowWithLevel:0.6] forKey:NSForegroundColorAttributeName];
	}
    
	static NSMutableDictionary *redStatusLineAttributes = nil;
	
	if (!redStatusLineAttributes)
	{
		redStatusLineAttributes = [[NSMutableDictionary alloc] initWithDictionary:statusLineAttributes];
		[redStatusLineAttributes setObject:[NSColor redColor] forKey:NSForegroundColorAttributeName];
	}
	
	static NSMutableDictionary *unsubscribedPoolLineAttributes = nil;
	
	if (!unsubscribedPoolLineAttributes)
	{
		unsubscribedPoolLineAttributes = [[NSMutableDictionary alloc] init];
		NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [style setLineBreakMode:NSLineBreakByTruncatingMiddle];
		
		[unsubscribedPoolLineAttributes setObject:style forKey:NSParagraphStyleAttributeName];
		
		[style release];
		
		[unsubscribedPoolLineAttributes setObject:[NSFont systemFontOfSize:12] forKey:NSFontAttributeName];
	}
	
	static NSMutableDictionary *subscribedPoolLineAttributes = nil;
	
	if (!subscribedPoolLineAttributes)
	{
		subscribedPoolLineAttributes = [[NSMutableDictionary alloc] initWithDictionary:unsubscribedPoolLineAttributes];
		
		[subscribedPoolLineAttributes setObject:[NSFont boldSystemFontOfSize:12] forKey:NSFontAttributeName];
	}
	*/
	
	static NSMutableDictionary *textAttributes = nil;
	
	if (!textAttributes)
	{
		textAttributes = [[NSMutableDictionary alloc] init];
		NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [style setLineBreakMode:NSLineBreakByTruncatingMiddle];
		
		[textAttributes setObject:style forKey:NSParagraphStyleAttributeName];
		
		[style release];
		
		[textAttributes setObject:[NSFont systemFontOfSize:12] forKey:NSFontAttributeName];
	}
	
	NSMutableDictionary *attributes = [[textAttributes mutableCopy] autorelease];
	
	if ([self isHighlighted])
	{
		[attributes setObject:contrastingLabelColor forKey:NSForegroundColorAttributeName];
	}
	
	NSString *name = [[self hierarchyItem] valueForKey:@"name"];
	if (!name) name = @"<unknown>";
	NSMutableAttributedString *nameString = [[[NSMutableAttributedString alloc] initWithString:name attributes:attributes] autorelease];
	//NSMutableAttributedString *nameString = [[[NSMutableAttributedString alloc] initWithString:@"just testing" attributes:attributes] autorelease];
	
	NSRect poolNameRect = frame;
	[nameString drawInRect:poolNameRect];
	
	//NSAttributedString *statusLine = nil;
	
	/*
	if ([pool isActive])
	{
		unsigned int conflictCount = [[pool conflictingFiles] count];
		
		if (conflictCount == 0)
		{
			attributes = [[greenStatusLineAttributes mutableCopy] autorelease];
			
			if ([self isHighlighted])
			{
				[attributes setObject:contrastingLabelColor forKey:NSForegroundColorAttributeName];
			}
			
			statusLine = [[[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"No Conflicts", @"folder status line") attributes:attributes] autorelease];
		}
		else
		{
			NSString *conflictStatus = [NSString stringWithFormat:conflictCount == 1 ? NSLocalizedString(@"1 Conflict", @"") : NSLocalizedString(@"%u Conflicts", @""), conflictCount];
			
			attributes = [[redStatusLineAttributes mutableCopy] autorelease];
			
			if ([self isHighlighted])
			{
				[attributes setObject:contrastingLabelColor forKey:NSForegroundColorAttributeName];
			}
			
			statusLine = [[[NSMutableAttributedString alloc] initWithString:conflictStatus attributes:attributes] autorelease];
		}
	}
	else
	{
		attributes = [[statusLineAttributes mutableCopy] autorelease];
		
		if ([self isHighlighted])
		{
			[attributes setObject:contrastingLabelColor forKey:NSForegroundColorAttributeName];
		}
		
		statusLine = [[[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"Unsubscribed", @"Pool status") attributes:attributes] autorelease];
	}
	
	NSRect statusLineRect = poolNameRect;
	statusLineRect.origin.y += [poolName size].height;
	[statusLine drawInRect:statusLineRect];
	 */
}

- (void)drawWithFrame:(NSRect)frame inView:(NSView *)controlView 
{		
	// draw the text:
	[self drawTextWithFrame:[self titleRectForBounds:frame] inView:controlView];
	
	// draw the image if given:
	if ([self image] != nil)  
	{
		[[self image] setFlipped:YES];
		[[self image] setSize:[self imageRectForBounds:frame].size];
		[[self image] setScalesWhenResized:NO];
		
		[[self image] drawInRect:[self imageRectForBounds:frame] fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	}
	
	// draw participant count:
	if ([self unreadCount] > 0) 
 	{
		NSAttributedString *attributedCountString = [self attributedCountStringWithColor:[self isHighlighted] ? [NSColor blackColor] : [NSColor whiteColor]];
		NSSize stringSize = [attributedCountString size];
		
		NSColor *color = [self isHighlighted] ? [NSColor whiteColor] : [self pillColor];
		[color set];
		NSRect countRect = [self countRectForBounds:frame];
		[[NSBezierPath bezierPathWithRoundRectInRect:countRect radius:8.0] fill];
		
		NSPoint point;
		
		point.x = NSMaxX(countRect) - ((NSMaxX(countRect) - NSMinX(countRect)) / 2);
		point.y = (NSMaxY(countRect) - NSMinY(countRect)) / 2;
		
		point.x = point.x - (stringSize.width / 2);
		if ([self unreadCount] < 10)
		{
			point.x += 1.0;
		}
		point.y = point.y - (stringSize.height / 2);
		
		NSRect numberRect = NSMakeRect(point.x , point.y + NSMinY(countRect), stringSize.width, stringSize.height);
		
		[attributedCountString drawInRect:numberRect];
	}
}

// BUG in AppKit: gets never called - this is why selectWithFrame is implemented because that is called on editing. Strange!
- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent
{
	[super editWithFrame:[self titleRectForBounds:aRect] inView:controlView editor:textObj delegate:anObject event:theEvent];
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength
{
	[super selectWithFrame:[self titleRectForBounds:aRect] inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

@end
