//
//  GIPhraseBrowserController.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 16.11.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "GIPhraseBrowserController.h"


@implementation GIPhraseBrowserController

static GIPhraseBrowserController *sharedPhraseBrowserController = nil;

+ (GIPhraseBrowserController *)sharedPhraseBrowserController
{
    if (!sharedPhraseBrowserController) sharedPhraseBrowserController = [[GIPhraseBrowserController alloc] init];
    return sharedPhraseBrowserController;
}

+ (void)showPhraseBrowserForTextView:(NSTextView *)aTextView
{
    GIPhraseBrowserController *controller = [self sharedPhraseBrowserController];
    controller->textView = aTextView;
    [controller->window makeFirstResponder:controller->phraseTableView];
    [controller->window makeKeyAndOrderFront:self];
}

- (id)init
{
    self = [super init];
    [NSBundle loadNibNamed:@"PhraseBrowser" owner:self];   
    return self;
}

- (NSMutableArray *)hotkeysInUse
{
    NSMutableArray *result = [NSMutableArray array];
    NSArray *phrasesArray = [[NSUserDefaults standardUserDefaults] objectForKey:@"phrases"];
    NSEnumerator *enumerator = [phrasesArray objectEnumerator];
    NSDictionary *phraseDict;
    
    while (phraseDict = [enumerator nextObject])
    {
        id hotkey = [phraseDict objectForKey:@"hotkey"];
        
        if (hotkey)
        {
            if (![hotkey isKindOfClass:[NSString class]]) hotkey = [hotkey stringValue];
            NSAssert([hotkey isKindOfClass:[NSString class]], @"should be a string");
            [result addObject:hotkey];
        }
    }
    
    return result;
}

- (NSArray *)hotkeys
{
    static NSArray *hotkeys = nil;
    
    if (!hotkeys) hotkeys = [[NSArray alloc] initWithObjects:@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"0", nil];

    NSMutableArray *result = [[hotkeys mutableCopy] autorelease];
    
    //NSLog(@"hotkeysinuse: %@", [self hotkeysInUse]);
    NSMutableArray *inUse = [self hotkeysInUse];
    
    [result removeObjectsInArray:inUse];
        
    return result;
}

- (IBAction)addItem:(id)sender
{
    // Note that in Tiger, we cannot use insert: anymore. This is because in Tiger, the default behavior is to run
    // action methods asynchronously, so we cannot rely on insert: to immediately insert the object. This is required,
    // however, because several GUI elements are bound to be enabled only after the insertion of the new object.
    // Therefore, we must use insertObject:atArrangedObjectIndex: instead of insert:.
    
    id arrayObject = [NSMutableDictionary dictionaryWithCapacity:2];
    
    [arrayController insertObject:arrayObject atArrangedObjectIndex:0];		
    [arrayController setSelectionIndex:0];
    [window makeFirstResponder:nameField];
}

- (IBAction)insertPhrase:(id)sender
{
    [textView insertText:[NSUnarchiver unarchiveObjectWithData:[[[arrayController selectedObjects] lastObject] objectForKey:@"phrasedata"]]];
}

- (IBAction)hotkeySelected:(id)sender
{
    [self willChangeValueForKey:@"hotkeys"];
    [self didChangeValueForKey:@"hotkeys"];
}

@end
