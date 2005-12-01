//
//  GIPhraseBrowserController.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 16.11.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface GIPhraseBrowserController : NSObject 
{
    IBOutlet NSWindow *window;
    IBOutlet NSTableView *phraseTableView;
    IBOutlet NSArrayController *arrayController;
    IBOutlet NSTextField *nameField;
    IBOutlet NSTextView *phraseTextView;
    
    @private
    NSTextView *textView;
    NSArray* sortDescriptors;
}

+ (void)showPhraseBrowserForTextView:(NSTextView *)aTextView;
+ (void)setTextView:(NSTextView *)aTextView;
+ (void)invalidateTextView:(NSTextView *)aTextView;

- (IBAction)insertPhrase:(id)sender;
- (IBAction)hotkeySelected:(id)sender;

- (IBAction)addItem:(id)sender;

- (void)hotkeyPressed:(int)hotkeyNumber;

@end
