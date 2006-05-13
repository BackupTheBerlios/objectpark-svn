//
//  $Id: GICommentTreeCell.m,v 1.27 2005/04/05 09:11:38 theisen Exp $
//  GinkoVoyager
//
//  Created by Dirk Theisen on 13.12.04.
//  Copyright 2004, 2005 Objectpark.org. All rights reserved.
//

#import "GICommentTreeCell.h"
//#import "NSView+FirstResponder.h"


#define veryLightGray  0.75


@implementation GICommentTreeCell


// these globals and related stuff should be part of the view, so move them there...
float cellWidth  = 33.0;
float cellHeight = 33.0;

float crossingCenterX = 10;
float crossingCenterY = 10;
float crossingRadius = 10;

float setCircleDiameter = 10;
float circleDiameter = 10;

float setLineWidth = 2.0;
float lineWidth = 2.0;

NSArray* messageColors;


void ensureIntegrity()
{
    circleDiameter  = MIN(setCircleDiameter, MIN(cellWidth/2, cellHeight) - lineWidth);
    lineWidth       = MIN(setLineWidth, circleDiameter/3);
    crossingCenterX = (cellWidth - circleDiameter*1.72) / 2;  // the 1.72 reflects the additional size for the arrows
    crossingCenterY = cellHeight / 2;
    crossingRadius  = MIN(crossingCenterX, crossingCenterY);
}


+ (void) setLineWidth:(float) aWidth
{
    setLineWidth = aWidth;
    
    ensureIntegrity();
}

+ (void) setCircleDiameter:(float) aDiameter
{
    setCircleDiameter = aDiameter;
    
    ensureIntegrity();
}

+ (void) setCellWidth:(float) aWidth andHeight:(float) aHeight
{
    cellWidth = aWidth;
    cellHeight = aHeight;
    
    ensureIntegrity();
}


+ (void) initialize
{
    // set some default values
    [GICommentTreeCell setCircleDiameter:11];
    [GICommentTreeCell setLineWidth:2];
    [GICommentTreeCell setCellWidth:33 andHeight:20];
    
    messageColors = [[NSArray alloc] initWithObjects:[NSColor colorWithCalibratedRed:255.0/255.0 green:255.0/255.0 blue:255.0/255.0 alpha:1.0],  // 0: white
                                                     [NSColor colorWithCalibratedRed:255.0/255.0 green:180.0/255.0 blue:180.0/255.0 alpha:1.0],  // 1: pastel red
                                                     [NSColor colorWithCalibratedRed:255.0/255.0 green:230.0/255.0 blue:127.0/255.0 alpha:1.0],  // 2: pastel orange
                                                     [NSColor colorWithCalibratedRed:255.0/255.0 green:255.0/255.0 blue:166.0/255.0 alpha:1.0],  // 3: pastel yellow
                                                     [NSColor colorWithCalibratedRed:180.0/255.0 green:255.0/255.0 blue:180.0/255.0 alpha:1.0],  // 4: pastel green
                                                     [NSColor colorWithCalibratedRed:160.0/255.0 green:220.0/255.0 blue:255.0/255.0 alpha:1.0],  // 5: pastel blue
                                                     [NSColor colorWithCalibratedRed:230.0/255.0 green:200.0/255.0 blue:255.0/255.0 alpha:1.0],  // 6: pastel purple
                                                     [NSColor colorWithCalibratedRed:205.0/255.0 green:205.0/255.0 blue:205.0/255.0 alpha:1.0],  // 7: pastel gray
                                                     nil];
}
// end of stuff to move to the view


- (id) init
{
    if (self = [super init]) {
        //representedObject = nil;
        [self setBordered: NO];
        
        [self reset];
        [self setFocusRingType: NSFocusRingTypeNone];

    }
    return self;
}


- (void) reset
{
    [self setRepresentedObject: nil];
    
    flags.isSeen = 0;
    flags.isDummyMessage = 0;
    flags.hasConnectionToDummyMessage = 0;
    flags.color = 0;
    
    connections.north = 0;
    connections.south = 0;
    connections.east = 0;
    connections.west = 0;
    
    navigation.north = 0;
    navigation.south = 0;
    navigation.east = 0;
    navigation.west = 0;
}


- (void) setIsDummyMessage:(BOOL) aBool
{
    flags.isDummyMessage = aBool;
}


- (void) setHasConnectionToDummyMessage:(BOOL) aBool
{
    flags.hasConnectionToDummyMessage = aBool;
}


- (void) setSeen:(BOOL) aBool
{
    flags.isSeen = aBool;
}


- (void) setColorIndex:(unsigned int) anIndex
{
    flags.color = anIndex;
}


- (BOOL) hasConnection
{
    return connections.north || connections.south || connections.east || connections.west;
}


- (void) addConnectionToNorth;
{
    connections.north = 1;
}

- (void) addConnectionToSouth;
{
    connections.south = 1;
}

- (void) addConnectionToEast;
{
    connections.east = 1;
}

- (void) addConnectionToWest;
{
    connections.west = 1;
}



- (void) addNavigationToNorth;
{
    navigation.north = 1;
}

- (void) addNavigationToSouth;
{
    navigation.south = 1;
}

- (void) addNavigationToEast;
{
    navigation.east = 1;
}

- (void) addNavigationToWest;
{
    navigation.west = 1;
}



/*
- (BOOL) isBordered
{
    return NO;
}
*/


- (NSSize) cellSize
{
    return NSMakeSize(cellWidth, cellHeight);
}


- (void) drawNavigationHelpInCellFrame:(NSRect) cellFrame inView:(NSView*) controlView
{
    float circleX = cellFrame.origin.x + cellWidth - circleDiameter*(0.5 + 0.36);
    float circleY = cellFrame.origin.y + crossingCenterY;
    float cathetus =  sin(pi/4) * (circleDiameter)/2;
    float radius = circleDiameter/2;
    cathetus = radius/2;
    
    [NSBezierPath setDefaultLineWidth:2.0];
    
    [[NSColor blackColor] set];
    
    [NSBezierPath setDefaultLineCapStyle:NSRoundLineCapStyle];
    [NSBezierPath setDefaultLineJoinStyle:NSRoundLineJoinStyle];
    
    NSBezierPath* path = [NSBezierPath bezierPath];
    
    if (navigation.north)
    {
        [path moveToPoint:NSMakePoint(circleX + cathetus, circleY - radius           )];
        [path lineToPoint:NSMakePoint(circleX           , circleY - radius - cathetus)];
        [path lineToPoint:NSMakePoint(circleX - cathetus, circleY - radius           )];
        [path lineToPoint:NSMakePoint(circleX + cathetus, circleY - radius           )];
    }
    if (navigation.south)
    {
        [path moveToPoint:NSMakePoint(circleX - cathetus, circleY + radius           )];
        [path lineToPoint:NSMakePoint(circleX + cathetus, circleY + radius           )];
        [path lineToPoint:NSMakePoint(circleX           , circleY + radius + cathetus)];
        [path lineToPoint:NSMakePoint(circleX - cathetus, circleY + radius           )];
    }
    if (navigation.east)
    {
        [path moveToPoint:NSMakePoint(circleX + radius           , circleY + cathetus)];
        [path lineToPoint:NSMakePoint(circleX + radius           , circleY - cathetus)];
        [path lineToPoint:NSMakePoint(circleX + radius + cathetus, circleY           )];
        [path lineToPoint:NSMakePoint(circleX + radius           , circleY + cathetus)];
    }
    if (navigation.west)
    {
        [path moveToPoint:NSMakePoint(circleX - radius           , circleY - cathetus)];
        [path lineToPoint:NSMakePoint(circleX - radius - cathetus, circleY           )];
        [path lineToPoint:NSMakePoint(circleX - radius           , circleY + cathetus)];
        [path lineToPoint:NSMakePoint(circleX - radius           , circleY - cathetus)];
    }
    
    [[NSColor whiteColor] setFill];
    [path stroke];
    [path fill];
}


- (void) drawInteriorWithFrame: (NSRect) cellFrame 
                        inView: (NSView*) controlView;
{
    NSPoint borderNorth = NSMakePoint(cellFrame.origin.x + crossingCenterX,                        cellFrame.origin.y + 0);
    NSPoint borderSouth = NSMakePoint(cellFrame.origin.x + crossingCenterX,                        cellFrame.origin.y + cellHeight);
    NSPoint borderWest  = NSMakePoint(cellFrame.origin.x + 0,                                      cellFrame.origin.y + crossingCenterY);
    NSPoint borderEast  = NSMakePoint(cellFrame.origin.x + cellWidth - circleDiameter + lineWidth, cellFrame.origin.y + crossingCenterY);
    
    NSPoint crossingNorth = NSMakePoint(cellFrame.origin.x + crossingCenterX,                  cellFrame.origin.y + crossingCenterY - crossingRadius);
    NSPoint crossingSouth = NSMakePoint(cellFrame.origin.x + crossingCenterX,                  cellFrame.origin.y + crossingCenterY + crossingRadius);
    NSPoint crossingWest  = NSMakePoint(cellFrame.origin.x + crossingCenterX - crossingRadius, cellFrame.origin.y + crossingCenterY);
    NSPoint crossingEast  = NSMakePoint(cellFrame.origin.x + crossingCenterX + crossingRadius, cellFrame.origin.y + crossingCenterY);
    
    NSPoint crossingNorthEast = NSMakePoint(cellFrame.origin.x + crossingCenterX + crossingRadius, cellFrame.origin.y + crossingCenterY - crossingRadius);
    NSPoint crossingSouthWest = NSMakePoint(cellFrame.origin.x + crossingCenterX - crossingRadius, cellFrame.origin.y + crossingCenterY + crossingRadius);
    
    NSPoint cellEast = NSMakePoint(cellFrame.origin.x + cellFrame.size.width, cellFrame.origin.y + crossingCenterY);
    
    
    [NSBezierPath setDefaultLineCapStyle:NSButtLineCapStyle];
    [NSBezierPath setDefaultLineWidth:lineWidth];
    
    
    if (flags.hasConnectionToDummyMessage)
        [[NSColor colorWithCalibratedWhite:veryLightGray alpha:1.0] set];
    else
        [[NSColor grayColor] set];
    
    NSBezierPath* rootLine = [NSBezierPath bezierPath];
    
    // draw the crossing
    if (connections.north && connections.east) {
        [rootLine moveToPoint:crossingNorth];
        [rootLine appendBezierPathWithArcWithCenter:crossingNorthEast radius:crossingRadius startAngle:(float)180.0 endAngle:90.0 clockwise: YES];
    }

    if (connections.south && connections.west) {
        [rootLine moveToPoint:crossingSouth];
        [rootLine appendBezierPathWithArcWithCenter:crossingSouthWest radius:crossingRadius startAngle:(float)0.0 endAngle:270.0 clockwise: YES];
    }
    
    if (connections.north && connections.south) {
        [rootLine moveToPoint:crossingNorth];
        [rootLine lineToPoint:crossingSouth];
    }
    
    if (connections.east && connections.west) {
        [rootLine moveToPoint:crossingEast];
        [rootLine lineToPoint:crossingWest];
    }
    
    // draw the "broken" reference
    if (connections.east && !(connections.west || connections.north || connections.south)) {
        [rootLine moveToPoint:NSMakePoint(cellFrame.origin.x + crossingCenterX + crossingRadius*6/8, cellFrame.origin.y + crossingCenterY)];
        [rootLine lineToPoint:NSMakePoint(cellFrame.origin.x + crossingCenterX + crossingRadius*4/8, cellFrame.origin.y + crossingCenterY)];
        [rootLine moveToPoint:NSMakePoint(cellFrame.origin.x + crossingCenterX + crossingRadius*2/8, cellFrame.origin.y + crossingCenterY)];
        [rootLine lineToPoint:NSMakePoint(cellFrame.origin.x + crossingCenterX + crossingRadius*1/8, cellFrame.origin.y + crossingCenterY)];
    }
    
    // draw the outer "roads"
    if (connections.north) {
        [rootLine moveToPoint:borderNorth];
        [rootLine lineToPoint:crossingNorth];
    }
    
    if (connections.south) {
        [rootLine moveToPoint:borderSouth];
        [rootLine lineToPoint:crossingSouth];
    }
    
    if (connections.east) {
        [rootLine moveToPoint:borderEast];
        [rootLine lineToPoint:crossingEast];
    }
    
    if (connections.west) {
        [rootLine moveToPoint:borderWest];
        [rootLine lineToPoint:crossingWest];
    }
    
    [rootLine stroke];
    
    // prevent graphics glitch by "connecting" to the east cell
    if (navigation.east) {
        rootLine = [NSBezierPath bezierPath];
        
        if (flags.isDummyMessage)
            [[NSColor colorWithCalibratedWhite:veryLightGray alpha:1.0] set];
        else
            [[NSColor grayColor] set];
        
        [rootLine moveToPoint:borderEast];
        [rootLine lineToPoint:cellEast];
        
        [rootLine stroke];
    }
    
    
    if ([self representedObject]) {
        NSRect circleRect;
        NSBezierPath *circle;
        
        if ([self state] == NSOnState)
            [self drawNavigationHelpInCellFrame:cellFrame inView:controlView];
            
        [NSBezierPath setDefaultLineWidth:0.0];
        
        // draw the ring
        circleRect = NSMakeRect(cellFrame.origin.x + cellWidth - circleDiameter*1.36,  // the 1.36 reflects the size of one arrow
                                cellFrame.origin.y + (cellHeight - circleDiameter)/2,
                                circleDiameter,
                                circleDiameter);
        circle = [NSBezierPath bezierPathWithOvalInRect: circleRect];
        
        if (flags.isDummyMessage)
            [[NSColor colorWithCalibratedWhite:veryLightGray alpha:1.0] set];
        else if (flags.isSeen)
            [[NSColor grayColor] set];
        else
            [[NSColor colorWithCalibratedRed:51.0/255.0 green:51.0/255.0 blue:51.0/255.0 alpha:1.0] set];
             
        if ([self state] == NSOnState) {
            [NSGraphicsContext saveGraphicsState];
            NSSetFocusRingStyle(NSFocusRingBelow);
            [circle fill];
            [NSGraphicsContext restoreGraphicsState];
        } else [circle fill];

     
        
        
        // draw the interior
        circleRect = NSMakeRect(cellFrame.origin.x + cellWidth - circleDiameter*1.36 + lineWidth,  // the 1.36 reflects the size of one arrow
                                cellFrame.origin.y + (cellHeight - circleDiameter)/2 + lineWidth,
                                circleDiameter - 2*lineWidth,
                                circleDiameter - 2*lineWidth);
        circle = [NSBezierPath bezierPathWithOvalInRect: circleRect];
        
//         if ([self state] == NSOnState)
//             [[NSColor blackColor] set];
//         else
            [[messageColors objectAtIndex:flags.color] set];
            
        [circle fill];
        
    }
}


//- (id) representedObject
//{
//    return representedObject;
//}


- (void) setRepresentedObject: (id) newObj
{
    //[representedObject autorelease];
    //representedObject = [newObj retain];
	[super setRepresentedObject: newObj];
    [self setEnabled: newObj != nil];
}


//- (void) dealloc
//{
    //[representedObject release];
//    [super dealloc];
//}


@end




@implementation NSMatrix (G3Extensions)

- (NSCell*) cellForRepresentedObject: (id) object
{
    NSArray* cells = [self cells];
    int i;
    for (i=[cells count]-1; i>=0; i--) {
        id cell = [cells objectAtIndex: i];
        if ([cell representedObject]==object) return cell; 
    }
    return nil;
}

@end
