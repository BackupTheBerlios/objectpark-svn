/*
 $Id: GIContentPane.m,v 1.7 2005/03/25 23:39:34 theisen Exp $

 Copyright (c) 2002 by Dirk Theisen, Axel Katerbau. All rights reserved.

 Permission to use, copy, modify and distribute this software and its documentation
 is hereby granted, provided that both the copyright notice and this permission
 notice appear in all copies of the software, derivative works or modified versions,
 and any portions thereof, and that both notices appear in supporting documentation,
 and that credit is given to Dirk Theisen and Axel Katerbau in all documents and publicity
 pertaining to direct or indirect use of this code or its derivatives.

 THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
 SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
 "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
 DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
 OR OF ANY DERIVATIVE WORK.

 Further information can be found on the project's web pages
 at http://www.objectpark.org/Ginko.html
 */

#import <G3Message+Rendering.h>

#import "GIContentPane.h"
#import "GIUserDefaultsKeys.h"
//#import "GIApplicationDelegate.h"
//#import "GIMessageRenderer.h"
//#import <OPMessageServices/OPMessageServices.h>
//#import "NSTableView+OPCheckboxColumn.h"
#import <Foundation/NSDebug.h>

@implementation GIContentPane

- (void) updateFontDescription
/*" Updates the font description in the pref panel. "*/
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString* fontName = [userDefaults objectForKey: MessageRendererFontName];
    float     fontSize = [userDefaults integerForKey: MessageRendererFontSize];
    
    [fontDescription setStringValue: [NSString stringWithFormat:@"%@ Size: %f", fontName, fontSize]];
}

- (void) didSelect 
{    
    [self updateFontDescription];
    
    // Register to grok GinkoContentType drags
    [tableView registerForDraggedTypes: [NSArray arrayWithObject: @"GinkoContentType"]];
    
    [headersTableView reloadData];

}

//[[NSUserDefaults standardUserDefaults] setObject: newPrefs forKey: ContentTypePreferences];


/*
- (void) willUnselect 
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

    if (NSDebugEnabled) NSLog(@"[%@ %@]", [self class], NSStringFromSelector(_cmd));
               
    //[[NSApp delegate] setAdditionalHeadersForDisplay:_additionalHeaders];
}
*/

- (IBAction) restoreDefaultAction: (id) sender {

    id ud = [NSUserDefaults standardUserDefaults];
    
    [ud removeObjectForKey: ContentTypePreferences];

    //[[NSApp delegate] setAdditionalHeadersForDisplay: [NSArray array]];
    [tableView reloadData];
    [headersTableView reloadData];
    [ud removeObjectForKey: MessageRendererFontName];
    [ud removeObjectForKey: MessageRendererFontSize];
    [self updateFontDescription];

}

- (NSArray*) allAdditionalHeadersForDisplay
{
    return allAdditionalHeadersForDisplay();
}

- (NSArray*) additionalHeadersForDisplay
{
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    return [ud objectForKey: AdditionalHeadersShown];
}

- (void) setAdditionalHeadersForDisplay: (NSArray*) newHeaders
{
    NSLog(@"Setting setAdditionalHeadersForDisplay to %@", newHeaders);
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
    [ud setObject: newHeaders forKey: AdditionalHeadersShown];
}

static NSFont* font() 
{
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSString* fontName = [userDefaults objectForKey: MessageRendererFontName];
    float     fontSize = [userDefaults integerForKey: MessageRendererFontSize];
    
    return fontName ? [NSFont fontWithName:fontName size:fontSize] 
                               : [NSFont userFontOfSize:-1];    
}

- (void) changeFont: (id) sender
{
    NSFont* newFont = [sender convertFont: font()];
    //MPWDebugLog(@"changeFont: %@", newFont);
        
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:[newFont fontName]   forKey: MessageRendererFontName];
    [userDefaults setInteger:[newFont pointSize] forKey: MessageRendererFontSize];
    
    [self updateFontDescription];
}

- (IBAction) showFontPanelAction: (id) sender
{
    [[NSFontManager sharedFontManager] setSelectedFont: font() isMultiple:NO];
    [[NSFontManager sharedFontManager] orderFrontFontPanel:sender];
}


- (IBAction) reloadHeaderData: (id) sender 
{
    [headersTableView reloadData];
}

@end

@implementation GIContentPane (TableDataSource)


- (int) numberOfRowsInTableView: (NSTableView*) aTableView 
{
    NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];

    if (aTableView==tableView)
        return [[ud objectForKey: ContentTypePreferences] count];

    if (aTableView==headersTableView) {
        return [[self allAdditionalHeadersForDisplay] count];
    }
    return 0;
}



- (id) tableView: (NSTableView*) aTableView objectValueForTableColumn: (NSTableColumn*) aTableColumn row: (int) rowIndex 
{

    if (aTableView==tableView) {
        NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];

        NSString* contentType = [[ud objectForKey: ContentTypePreferences] objectAtIndex:rowIndex];
        return contentType;
    }
    if (aTableView==headersTableView) {
        if ([[aTableColumn identifier] isEqualToString: @"enabled"]) {
            return [NSNumber numberWithBool: [[self additionalHeadersForDisplay] containsObject: [[self allAdditionalHeadersForDisplay] objectAtIndex: rowIndex]]]; // slow, but who cares
        } else {
            return [[self allAdditionalHeadersForDisplay] objectAtIndex: rowIndex];
        }
    }
    return nil;
}


- (void) tableView: (NSTableView*) tv setObjectValue: (id) object forTableColumn: (NSTableColumn*) aTableColumn row: (int) inRow
{
    NSString* header = [[self allAdditionalHeadersForDisplay] objectAtIndex: inRow];
    NSMutableArray* headers = [[[self additionalHeadersForDisplay] mutableCopy] autorelease];
    //NSLog(@"Setting checkbox value.");
    if ([object intValue]) {
        if (![headers containsObject: header])
            [headers addObject: header];
    } else {
        [headers removeObject: header];
    }
    [self setAdditionalHeadersForDisplay: headers];
    //[headersTableView reloadData];
}


// drag and drop

- (BOOL) tableView: (NSTableView*) aTableView acceptDrop: (id <NSDraggingInfo>) info row: (int) row dropOperation: (NSTableViewDropOperation) operation
{
    if (aTableView==tableView) {
        
        NSUserDefaults* ud = [NSUserDefaults standardUserDefaults];
        NSString* contentType = [[[NSString alloc] initWithData: [[info draggingPasteboard] dataForType: @"GinkoContentType"] encoding: NSUTF8StringEncoding] autorelease];

        // Remove content type from list:
        NSMutableArray *preferredContentTypes = [NSMutableArray arrayWithArray: [ud objectForKey: ContentTypePreferences]];

        int index = [preferredContentTypes indexOfObject: contentType];

        if (row != index) {
            int diff = (index < row) ? -1 : 0;
            
            [preferredContentTypes removeObject: contentType];
            [preferredContentTypes insertObject: contentType atIndex: row + diff];
            [ud setObject: preferredContentTypes forKey: ContentTypePreferences];
            [aTableView reloadData];
            
            return YES;
        }
    }
    return NO;
}


- (NSDragOperation)tableView:(NSTableView*)aTableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{
    if (aTableView==tableView) {
        [tableView setDropRow:row dropOperation:NSTableViewDropAbove];
        return [info draggingSourceOperationMask];
    }
    return NSDragOperationNone;
}

- (BOOL) tableView:(NSTableView *)aTableView writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard
{
    if (aTableView==tableView) {

        [pboard declareTypes:[NSArray arrayWithObject:@"GinkoContentType"] owner:self];

        // Only write the first row:
        int rowNumber = [[[rows objectEnumerator] nextObject] intValue];

        NSString* contentType = [[[NSUserDefaults standardUserDefaults] objectForKey: ContentTypePreferences] objectAtIndex: rowNumber];

        [pboard setData: [contentType dataUsingEncoding: NSUTF8StringEncoding]
                forType: @"GinkoContentType"];

        return YES;
    }
    return NO;
}


- (BOOL) tableView: (NSTableView*) aTableView shouldSelectRow: (int) rowIndex 
{
    //if (tableView==aTableView) return NO;
    return NO;
}

@end

@implementation GIContentPane (TableViewDelegate)



@end