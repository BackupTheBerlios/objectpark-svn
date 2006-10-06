//
//  GIThreadsController.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 04.10.06.
//  Copyright 2006 Objectpark Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class GIMessage;
@class GIThread;

@interface GIThreadsController : NSWindowController 
{
	NSArray *threads;
	GIMessage *viewedMessage;
	
	IBOutlet NSArrayController *threadsController;
	IBOutlet NSArrayController *messagesController;

	IBOutlet NSTableColumn *threadDateColumn;
	IBOutlet NSTableColumn *messageDateColumn;
	
	IBOutlet NSTextView *messageTextView;
}

- (id)initWithThreads:(NSArray *)someThreads;

- (void)setThreads:(NSArray *)someThreads;
- (NSArray *)threads;

- (void)selectThread:(GIThread *)threadToSelect;

@end
