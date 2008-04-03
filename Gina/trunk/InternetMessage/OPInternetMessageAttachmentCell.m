//
//  OPInternetMessageAttachmentCell.m
//  OPMessageServices
//
//  Created by Axel Katerbau on Sun Jan 12 2003.
//  Copyright (c) 2003 Objectpark Development Group. All rights reserved.
//

#import "OPInternetMessageAttachmentCell.h"


@implementation OPInternetMessageAttachmentCell

- (NSSize) cellSize
{
    NSSize result = [[self image] size];
    result.height+= [[self infoString] length] ? 30.0 : 22.0;
    if (result.width<140.0) result.width = 140.0;
    return result;
}


- (NSLineBreakMode) lineBreakMode
{
    return NSLineBreakByTruncatingMiddle;
}

NSString *bytes2Display(unsigned int bytes)
{
    NSString *unit, *format;
    double result;
    
    if (bytes < 1024) {
        unit = @"Byte";
        result = bytes;
    }
    else if (bytes < 1048525) {   // 1023.95 KB
        unit = @"KB";
        result = bytes / 1024.0;
    }
    else if (bytes < 1073689395) {   // 1023.95 MB
        unit = @"MB";
        result = bytes / 1048576.0;
    }
    else {
        unit = @"GB";
        result = bytes / 1073741824.0;
    }
    
    if (result < 10.05) {
        format = @"%.2g %@";
    }
    else if (result < 100.05) {
        format = @"%.3g %@";
    }
    else if (result < 1000.05) {
        format = @"%.4g %@";
    }
    else {
        format = @"%.5g %@";
    }
    
    return [NSString stringWithFormat:format, result, unit];
}


- (NSString*) infoString
/*" Returns the attachment file size by default, but can be set to any string using -setInfoString: "*/
{	
	if (!infoString) {
		
		NSFileWrapper* aFileWrapper = [[self attachment] fileWrapper];
		
		if ([aFileWrapper isRegularFile])  {
		
			unsigned int fileSize;
			NSData *resourceForkData;
			
			fileSize = [[aFileWrapper regularFileContents] length];
			
			if (resourceForkData = [[aFileWrapper fileAttributes] objectForKey: @"OPFileResourceForkData"]) {
				// Add the size of the resource fork also
				fileSize += [resourceForkData length];
			}

			[self setInfoString: bytes2Display(fileSize)];
		} else {
			// Add support for directories?
			[self setInfoString: @"Folder"];
		}
	}
	return infoString;
}

- (NSString*) title
{	
	NSString* result = [super title];
	if (! [result length]) {
		NSFileWrapper* aFileWrapper = [[self attachment] fileWrapper];
		result = [[aFileWrapper filename] lastPathComponent];
		[self setTitle: result];
	}
	return result;
}

- (void) setInfoString: (NSString*) newInfo
{
    if (![newInfo isEqualToString: infoString]) {
        [infoString release];
        infoString = [newInfo retain];
    }
}

- (void) drawWithFrame: (NSRect) cellFrame 
                inView: (NSView*) controlView
{
    NSString* title          = [self title];
	NSString* info           = [self infoString];
    NSRect    textFrame      = NSInsetRect(cellFrame, 2.0, 2.0);
    
	NSImage*  image = [self image];
	NSRect    fullImageRect  = NSMakeRect(0,0,[image size].width, [image size].height);
	NSRect    drawImageRect  = NSOffsetRect(fullImageRect, (cellFrame.size.width-[image size].width)/2.0+cellFrame.origin.x, 5.0+cellFrame.origin.y);
	
	NSParameterAssert(image);
	
	if ([self isHighlighted]) {
		NSColor* backgroundColor = [self highlightColorWithFrame: cellFrame inView: controlView];
		[backgroundColor set];
		NSRectFill(cellFrame);
	}
	
    // Draw it flipped if we are in a flipped view, like NSMatrix:
	[image setFlipped: [controlView isFlipped]];
	
	[image drawInRect: drawImageRect          
			 fromRect: fullImageRect 
			operation: NSCompositeSourceOver 
			 fraction: 1.0];
	
	if ([info length]) {
		// We have two lines to show:
		title = [NSString stringWithFormat: @"%@\n%@", title, info];
		
		textFrame.origin.y    = NSMaxY(textFrame)-24.0;
		textFrame.size.height = 24.0;
	} else {
		textFrame.origin.y    = NSMaxY(textFrame)-14.0;
		textFrame.size.height = 14.0;
	}
    
    
    static NSDictionary* attributes = nil;
    if (!attributes) {
        NSMutableParagraphStyle* style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [style setLineBreakMode: [self lineBreakMode]];
        [style setAlignment: NSCenterTextAlignment];
        attributes = [[NSDictionary alloc] initWithObjectsAndKeys: 
            style, NSParagraphStyleAttributeName,
            [NSFont systemFontOfSize: 9], NSFontAttributeName,
            nil, nil];
    }
    
    [title drawWithRect: textFrame
                options: NSStringDrawingUsesLineFragmentOrigin 
             attributes: attributes];
    
}

- (void) setTitle: (NSString*) newTitle
{
    // Keep the image around!
    NSImage* image = [[self image] retain];
    
    [super setTitle: newTitle];
    if (image) {
        [self setImage: image];
        [image release];
    }
}

- (void) dealloc 
{
    //NSLog(@"Deallocating 0x%x od class %@", self, [self class]);;
    [infoString release];
    [super dealloc];
}

@end

