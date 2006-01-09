//
//  GIMessageBase.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 06.04.05.
//  Copyright 2005 Objectpark Group. All rights reserved.
//

#import "GIMessageBase.h"
#import "GIMessage.h"
#import "GIThread.h"
#import "G3Account.h"
#import "GIMessageGroup.h"
#import "OPMBoxFile.h"
#import "OPPersistentObject+Extensions.h"
#import "GIUserDefaultsKeys.h"
#import "GIFulltextIndexCenter.h"
#import "NSData+MessageUtils.h"
#import "OPJobs.h"
#import "GIMessageFilter.h"
#import "OPPOP3Session.h"
#import "NSApplication+OPExtensions.h"
#import <OPDebug/OPLog.h>

@implementation GIMessageBase

- (void)addMessage:(GIMessage *)aMessage
{
	[[self class] addMessage:aMessage];
}

+ (void)addMessage:(GIMessage *)aMessage
{
	if (aMessage) 
    {
		if (![GIMessageFilter filterMessage:aMessage flags:0]) 
        {
			[[self class] addMessage:aMessage toMessageGroup:[GIMessageGroup defaultMessageGroup] suppressThreading:NO];
		}
		
		if ([aMessage hasFlags:OPIsFromMeStatus]) 
        {
			[[self class] addMessage:aMessage toMessageGroup:[GIMessageGroup sentMessageGroup] suppressThreading:NO];
		}
		
		// add message to index
		//GIFulltextIndexCenter* indexCenter = [GIFulltextIndexCenter defaultIndexCenter];
		//[indexCenter addMessage:message];
		NSLog(@"adding message... '%@'", [[aMessage internetMessage] subject]);
	} 	
}

- (void)addMessageInMainThreadWithTransferData:(NSMutableArray *)parameters
{
    @try 
    {
        GIMessage *message = [GIMessage messageWithTransferData:[parameters objectAtIndex:0]];
		if (message)
		{
			[self addMessage:message];
			[parameters addObject:message]; // out param
		}
    } 
    @catch (NSException *localException) 
    {
        NSLog(@"Exception while adding message in main thread: %@", [localException reason]);
    } 
    @finally 
    {
        while ([parameters count] < 2) [parameters addObject:[NSNull null]];
    }
}

+ (void)addMessage:(GIMessage *)aMessage toMessageGroup:(GIMessageGroup *)aGroup suppressThreading:(BOOL)suppressThreading
{
    NSParameterAssert(aMessage != nil);
    
	GIThread *thread = [aMessage assignThreadUseExisting:!suppressThreading];
    
	// Add the thread to the group, if not already present:
	if (![[aGroup valueForKey:@"threadsByDate"] containsObject:thread]) 
    {
		[aGroup addValue:thread forKey:@"threadsByDate"];
	}
}

/*
+ (void)addSentMessage:(GIMessage *)aMessage
{
    [GIMessageFilter filterMessage:aMessage flags:0]; // put the message where it belongs
    [self addMessage:aMessage toMessageGroup:[GIMessageGroup sentMessageGroup] suppressThreading:NO];
}
*/

+ (void)addDraftMessage:(GIMessage *)aMessage
{
    GIThread *thread = [aMessage thread];
    if (thread) [[GIMessageGroup queuedMessageGroup] removeValue:thread forKey:@"threadsByDate"];
    [self addMessage:aMessage toMessageGroup:[GIMessageGroup draftMessageGroup] suppressThreading:YES];
}

+ (void)addQueuedMessage:(GIMessage *)aMessage
{
    GIThread *thread = [aMessage thread];
    if (thread) [[GIMessageGroup draftMessageGroup] removeValue:thread forKey:@"threadsByDate"];
    [self addMessage:aMessage toMessageGroup:[GIMessageGroup queuedMessageGroup] suppressThreading:YES];
}

+ (void)addTrashThread:(GIThread *)thread
{
    [[GIMessageGroup draftMessageGroup] removeValue:thread forKey:@"threadsByDate"];
    [[GIMessageGroup queuedMessageGroup] removeValue:thread forKey:@"threadsByDate"];
    
    [[GIMessageGroup trashMessageGroup] addValue:thread forKey:@"threadsByDate"];
}

+ (void)removeDraftMessage:(GIMessage *)aMessage
/*" Removes group and message from aMessage's thread. "*/
{
    GIThread *thread = [aMessage thread];
    NSAssert(thread != nil, @"draft message without thread");
    
    [thread removeValue:[GIMessageGroup draftMessageGroup] forKey:@"groups"];
    [thread removeValue:aMessage forKey:@"messages"];
}

+ (NSSet *)defaultGroupsForMessage:(GIMessage *)aMessage
/*" Returns an array of GIMessageGroup objects where the given message should go into per the user's filter setting. "*/
{
    // TODO: just a dummy here!
    return [NSSet setWithObjects:[GIMessageGroup defaultMessageGroup], nil];
}

NSString *MboxImportJobName = @"mbox import";

- (void)importMessagesFromMboxFileJob:(NSMutableDictionary *)arguments
/*" Adds messages from the given mbox file (dictionary @"mboxFilename") to the message database applying filters/sorters. 

    Should run as job (#{see OPJobs})."*/
{
    NSString *mboxFilePath = [arguments objectForKey:@"mboxFilename"];
    NSParameterAssert(mboxFilePath != nil);
    //NSManagedObjectContext *parentContext = [arguments objectForKey:@"parentContext"];
    //NSParameterAssert(parentContext != nil);
    BOOL shouldCopyOnly = [[arguments objectForKey:@"copyOnly"] boolValue];
    int percentComplete = -1;
    NSDate *lastProgressSet = [[NSDate alloc] init];
    
    // Create mbox file object for enumerating the contained messages:
    OPMBoxFile *mboxFile = [OPMBoxFile mboxWithPath:mboxFilePath];
    NSAssert1(mboxFile != nil, @"mbox file at path %@ could not be opened.", mboxFilePath);
    unsigned int mboxFileSize = [mboxFile mboxFileSize];
    
    // Get our own context for this job/thread but use the same store coordinator
    // as the main thread because this job/threads works for the main thread.
    OPPersistentObjectContext *context = [OPPersistentObjectContext threadContext];  
    
    NSEnumerator *enumerator = [mboxFile messageDataEnumerator];
    NSData *mboxData;

    BOOL messagesWereAdded = NO;
    unsigned mboxDataCount = 0;
    unsigned addedMessageCount = 0;
    
//    [[context undoManager] disableUndoRegistration];
    
    [OPJobs setProgressInfo:[OPJobs progressInfoWithMinValue:0 maxValue:mboxFileSize currentValue:[enumerator offsetOfNextObject] description:@""]];
    
    NSAutoreleasePool *pool = nil;
    
    @try {
        pool = [[NSAutoreleasePool alloc] init];
        
        while (mboxData = [enumerator nextObject]) {
            //NSLog(@"Found mbox data of length %d", [mboxData length]);
            NSData *transferData = [mboxData transferDataFromMboxData];
            
            if (transferData) 
            {
                @try {
                    NSMutableArray *args = [NSMutableArray arrayWithObject:transferData];
                    [self performSelectorOnMainThread:@selector(addMessageInMainThreadWithTransferData:) withObject:args waitUntilDone:YES];
                    
                    GIMessage *persistentMessage = [args objectAtIndex:1];
                    
                    if (persistentMessage == (GIMessage *)[NSNull null]) persistentMessage = nil;
                    
                    if (persistentMessage) 
                    {
                        messagesWereAdded = YES;
                        ++addedMessageCount;
                    }
                    
                    [persistentMessage flushInternetMessageCache]; // free some memory
                    
                    if ((++mboxDataCount % 100) == 0) 
                    {
                        if (messagesWereAdded) 
                        {
                            OPDebugLog(OPPERSISTENCE, OPINFO, @"*** Committing changes (added %u messages)...", addedMessageCount);
                            
                            [context saveChanges];
                            
                            messagesWereAdded = NO;
                        }
                        
                        [pool release]; pool = [[NSAutoreleasePool alloc] init];                            
                    }
					
                } 
                @catch (NSException *localException) {
                    [localException retain]; [localException autorelease]; // Try to avoid zombie exception object
                    [localException raise];
                }
            }
            
			// Avoid division by zero:
            if (mboxFileSize > 0) 
            {
                int newPercentComplete = (int) floor(((float)[enumerator offsetOfNextObject] / (float) mboxFileSize) * 100.0);
                NSDate *now = [[NSDate alloc] init];
                BOOL timeIsRipe = [now timeIntervalSinceDate:lastProgressSet] > 1.5;
                
                if (timeIsRipe || (newPercentComplete > percentComplete)) // report only when percentage changes
                {
                    [OPJobs setProgressInfo:[OPJobs progressInfoWithMinValue:0 maxValue:mboxFileSize currentValue:[enumerator offsetOfNextObject] description:[mboxFilePath lastPathComponent]]];
                    
                    percentComplete = newPercentComplete;
                    [lastProgressSet release];
                    lastProgressSet = [now retain];
                }
                
                [now release];
            }     
            
        }
        
        if (NSDebugEnabled) NSLog(@"*** Added %d messages.", addedMessageCount);
        
        //[NSApp performSelectorOnMainThread:@selector(saveAction:) withObject:self waitUntilDone: YES];
        [context saveChanges];
        //NSAssert1(!error, @"Fatal Error. Committing of added messages failed (%@).", error);    
		
    } 
    @catch (NSException* localException) 
    {
        if (NSDebugEnabled) NSLog(@"Exception while adding messages in background: %@", localException);
        [[localException retain] autorelease];
        @throw;
    } 
    @finally 
    {
        [lastProgressSet release];
        [pool release];
    }
    
    // move imported mbox to imported boxes:
    NSString *importedMboxesDirectory = [[NSApp applicationSupportPath] stringByAppendingPathComponent:@"imported mboxes"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:importedMboxesDirectory])
    {
        NSAssert1([[NSFileManager defaultManager] createDirectoryAtPath:importedMboxesDirectory attributes: nil], @"Could not create directory %@", importedMboxesDirectory);
    }
    
    NSString *destinationPath = [importedMboxesDirectory stringByAppendingPathComponent:[mboxFilePath lastPathComponent]];
    
    // only move if not already there:
    if (![[NSFileManager defaultManager] fileExistsAtPath:destinationPath])
    {
        if (shouldCopyOnly)
        {
            NSAssert2([[NSFileManager defaultManager] copyPath:mboxFilePath toPath:destinationPath handler: NULL], @"Could not copy imported mbox at path %@ to directory %@", mboxFilePath, destinationPath);
        }
        else
        {
            NSAssert2([[NSFileManager defaultManager] movePath:mboxFilePath toPath:destinationPath handler: NULL], @"Could not move imported mbox at path %@ to directory %@", mboxFilePath, destinationPath);
        }
    }
}

@end
