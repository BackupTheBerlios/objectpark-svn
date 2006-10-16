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
@class GICommentTreeView;
@class GIProfile;

@interface GIThreadsController : NSWindowController 
{
	NSArray *threads;
	GIProfile *defaultProfile;
	
	IBOutlet NSArrayController *threadsController;
	IBOutlet NSArrayController *messagesController;

	IBOutlet NSTableColumn *threadDateColumn;
	IBOutlet NSTableColumn *subjectAndAuthorColumn;
	IBOutlet NSTableColumn *messageDateColumn;
	
	IBOutlet NSTableView *threadsTableView;
	
	IBOutlet NSTextView *messageTextView;
	IBOutlet NSScrollView *messageTextScrollView;
	
	IBOutlet NSSplitView *thread_messageSplitView;
	IBOutlet NSSplitView *verticalSplitView;
	IBOutlet NSSplitView *infoSplitView;
	
	IBOutlet GICommentTreeView *commentTreeView;
}

- (id)initWithThreads:(NSArray *)someThreads andAutosaveName:(NSString *)autosaveName;

- (void)setThreads:(NSArray *)someThreads;
- (NSArray *)threads;

- (void)setDefaultProfile:(GIProfile *)aProfile;
- (GIProfile *)defaultProfile;

- (void)selectThread:(GIThread *)threadToSelect;

@end

extern NSString *GIThreadsControllerWillDeallocNotification;
