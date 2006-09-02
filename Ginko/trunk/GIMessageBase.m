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
#import "GIMessageGroup.h"
#import "OPMBoxFile.h"
#import "OPPersistentObject+Extensions.h"
#import "GIUserDefaultsKeys.h"
#import "GIFulltextIndex.h"
#import "NSData+MessageUtils.h"
#import "OPJob.h"
#import "GIMessageFilter.h"
#import "OPPOP3Session.h"
#import "NSApplication+OPExtensions.h"
#import <OPDebug/OPLog.h>

#define IMPORT OPL_DOMAIN @"Import"
#define TRANSFERDATA OPL_ASPECT 0x01
#define FLAGS OPL_ASPECT 0x02


@implementation GIMessageBase

- (void)addMessage:(GIMessage *)aMessage
{
	[[self class] addMessage:aMessage];
}

+ (void)addMessage:(GIMessage *)aMessage
{
	if (aMessage) 
	{;
		// Adding a message should be an atomic operation:
		@synchronized([aMessage context]) 
		{
			if (![GIMessageFilter filterMessage:aMessage flags:0]) 
			{
				[self addMessage:aMessage toMessageGroup:[GIMessageGroup defaultMessageGroup] suppressThreading:NO];
			}
			
			if ([aMessage hasFlags:OPIsFromMeStatus]) 
			{
				[self addMessage:aMessage toMessageGroup:[GIMessageGroup sentMessageGroup] suppressThreading:NO];
			}
			
			NSAssert([[[aMessage valueForKey:@"thread"] valueForKey:@"groups"] count] > 0, @"message without group found");
		}
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
	@catch (id localException) 
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
	//if (![[aGroup valueForKey: @"threadsByDate"] containsObject: thread]) {
	//	[aGroup addValue:thread forKey: @"threadsByDate"];
	//}
	[thread addToGroups_Manually:aGroup];
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
    [[GIMessageGroup draftMessageGroup] removeValue:thread forKey: @"threadsByDate"];
    [[GIMessageGroup queuedMessageGroup] removeValue:thread forKey: @"threadsByDate"];
    
    [[GIMessageGroup trashMessageGroup] addValue:thread forKey: @"threadsByDate"];
}

+ (void)removeDraftMessage:(GIMessage *)aMessage
/*" Removes group and message from aMessage's thread. "*/
{
    GIThread *thread = [aMessage thread];
    NSAssert(thread != nil, @"draft message without thread: %@");
    
    [thread removeValue:[GIMessageGroup draftMessageGroup] forKey:@"groups"];
    [thread removeValue:aMessage forKey:@"messages"];
}

+ (NSSet *)defaultGroupsForMessage:(GIMessage *)aMessage
/*" Returns an array of GIMessageGroup objects where the given message should go into per the user's filter setting. "*/
{
    // TODO: just a dummy here!
    return [NSSet setWithObjects:[GIMessageGroup defaultMessageGroup], nil];
}

NSString* MboxImportJobName = @"mbox import";

- (void) importMessagesFromMboxFileJob: (NSMutableDictionary*) arguments
/*" Adds messages from the given mbox file (dictionary @"mboxFilename") to the message database applying filters/sorters. 

    Should run as job (#{see OPJobs})."*/
{
    NSString* mboxFilePath = [arguments objectForKey:@"mboxFilename"];
    NSParameterAssert(mboxFilePath != nil);
    BOOL shouldCopyOnly = [[arguments objectForKey:@"copyOnly"] boolValue];
    int percentComplete = -1;
    NSDate* lastProgressSet = [[NSDate alloc] init];
    
    // Create mbox file object for enumerating the contained messages:
    OPMBoxFile* mboxFile;
	BOOL isFolder = NO;
	
	if ([[NSFileManager defaultManager] fileExistsAtPath: mboxFilePath 
											 isDirectory: &isFolder]) {
		if (isFolder) {
			mboxFilePath = [mboxFilePath stringByAppendingPathComponent: @"mbox"];
		} 
		mboxFile = [OPMBoxFile mboxWithPath: mboxFilePath];

	} else {
		// Error handling here
	}

	
    NSAssert1(mboxFile != nil, @"mbox file at path %@ could not be opened.", mboxFilePath);
    unsigned int mboxFileSize = [mboxFile mboxFileSize];
    
    // Get our own context for this job/thread but use the same store coordinator
    // as the main thread because this job/threads works for the main thread.
    OPPersistentObjectContext* context = [OPPersistentObjectContext threadContext];  
    
    NSEnumerator* enumerator = [mboxFile messageDataEnumerator];
    NSData* mboxData;

    BOOL messagesWereAdded = NO;
    unsigned mboxDataCount = 0;
    unsigned addedMessageCount = 0;
        
	OPJob *job = [OPJob job];
	
    [job setProgressInfo:[job progressInfoWithMinValue:0 
											  maxValue:mboxFileSize 
										  currentValue:[enumerator offsetOfNextObject] 
										   description:@""]];
    NSAutoreleasePool *pool = nil;
    @try 
	{
        pool = [[NSAutoreleasePool alloc] init];
        
        while ((mboxData = [enumerator nextObject]) && ![job shouldTerminate]) {
            //NSLog(@"Found mbox data of length %d", [mboxData length]);
            NSData *transferData = [mboxData transferDataFromMboxData];
            
            if (transferData) {
                @try {
                    NSString* flags = nil;
                    unsigned int length = [transferData length];
                    const char* bytes = [transferData bytes];
                    
                    if (! strncasecmp("X-Ginko-Flags:", bytes, strlen("X-Ginko-Flags:"))) {
                        const char *pos = bytes;
                        while ((pos < bytes+length) && (*pos++ != 0x0A))
                            ;
                            
                        flags = [[NSString stringWithCString:bytes+strlen("X-Ginko-Flags:") length:pos - (bytes + strlen("X-Ginko-Flags:") + 2)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                        OPDebugLog(IMPORT, FLAGS, @"Flags: '%@'", flags);
                        
                        transferData = [NSData dataWithBytes:pos length:bytes+length-pos];
                        OPDebugLog(IMPORT, TRANSFERDATA, @"transferData: %@", transferData);
                    }
                    
                    
                    //NSMutableArray* args = [NSMutableArray arrayWithObject: transferData];
					
                    // Moved addition to background thread:
					GIMessage *persistentMessage = [GIMessage messageWithTransferData: transferData];
	
					                    
                    //if (persistentMessage == (GIMessage *)[NSNull null]) persistentMessage = nil;
                    
                    if (persistentMessage) {
						
						[self addMessage:persistentMessage];

                        if (flags) [persistentMessage addFlagsFromString:flags];
                        
                        messagesWereAdded = YES;
                        ++addedMessageCount;
                    }
                    
                    [persistentMessage flushInternetMessageCache]; // free some memory
                    
                    if ((++mboxDataCount % 100) == 99) {
                        if (messagesWereAdded) {
                            OPDebugLog(OPPERSISTENCE, OPINFO, @"*** Committing changes (added %u messages)...", addedMessageCount);
                            
                            [context saveChanges];
                            
                            messagesWereAdded = NO;
                        }
                        [pool release]; pool = [[NSAutoreleasePool alloc] init];                            
                    }
                } @catch (id localException) {
					@throw;
                }
            }
            
			// Avoid division by zero:
            if (mboxFileSize > 0) {
                int newPercentComplete = (int) floor(((float)[enumerator offsetOfNextObject] / (float) mboxFileSize) * 100.0);
                NSDate *now = [[NSDate alloc] init];
                BOOL timeIsRipe = [now timeIntervalSinceDate:lastProgressSet] > 1.5;
                
				// Report only when percentage changes:
                if (timeIsRipe || (newPercentComplete > percentComplete)) {
                    [job setProgressInfo:[job progressInfoWithMinValue:0 maxValue:mboxFileSize currentValue:[enumerator offsetOfNextObject] description:[mboxFilePath lastPathComponent]]];
                    
                    percentComplete = newPercentComplete;
                    [lastProgressSet release];
                    lastProgressSet = [now retain];
                }
                
                [now release];
            }     
            
        }
        
        if (NSDebugEnabled) NSLog(@"*** Added %d messages.", addedMessageCount);
        
        [context saveChanges];
        //NSAssert1(!error, @"Fatal Error. Committing of added messages failed (%@).", error);    
		
    } 
    @catch (id localException) 
    {
        if (NSDebugEnabled) NSLog(@"Exception while adding messages in background: %@", localException);
        @throw;
    } 
    @finally 
    {
        [lastProgressSet release];
    }

	[pool release];

    if ([job shouldTerminate])
        return;
        
    // move imported mbox to imported boxes:
    NSString* importedMboxesDirectory = [[NSApp applicationSupportPath] stringByAppendingPathComponent:@"imported mboxes"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:importedMboxesDirectory])
    {
        NSAssert1([[NSFileManager defaultManager] createDirectoryAtPath:importedMboxesDirectory attributes: nil], @"Could not create directory %@", importedMboxesDirectory);
    }
    
    NSString* destinationPath = [importedMboxesDirectory stringByAppendingPathComponent:[mboxFilePath lastPathComponent]];
    
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
