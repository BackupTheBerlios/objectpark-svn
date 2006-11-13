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
@class GIMessageGroup;

@interface GIThreadsController : NSWindowController 
{
	NSArray *threads;
	GIProfile *defaultProfile;
	GIMessageGroup *group;   // optional for dragging
	
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
- (id)initWithGroup:(GIMessageGroup *)aGroup andAutosaveName:(NSString *)autosaveName;

- (void)setThreads:(NSArray *)someThreads;
- (NSArray *)threads;

- (void)setGroup:(GIMessageGroup *)aGroup;
- (GIMessageGroup *)group;

- (void)setDefaultProfile:(GIProfile *)aProfile;
- (GIProfile *)defaultProfile;

- (void)selectThread:(GIThread *)threadToSelect;

- (int)numberOfRecentThreads;

@end

extern NSString *GIThreadsControllerWillDeallocNotification;
