//
//  GIMessageBase.m
//  Gina
//
//  Created by Dirk Theisen on 03.01.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "GIMessageBase.h"
#import "GIMessage.h"
#import "GIThread.h"
#import "GIMessageGroup.h"
#import "GIMessageFilter.h"
#import <Foundation/NSDebug.h>
#import "OPMBoxFile.h"
#import "NSData+MessageUtils.h"
#import "NSApplication+OPExtensions.h"
#import "OPInternetMessage.h"


@implementation OPPersistentObjectContext (GIMessageBase)

- (NSMutableDictionary*) messagesByMessageId
{	
	OPPersistentStringDictionary* globalIndex = nil;
	
	if (!globalIndex) {
		globalIndex = [[self rootObjectForKey: @"MessagesById"] retain];
		if (!globalIndex) {
			globalIndex = [[OPPersistentStringDictionary alloc] init]; 
			[self setRootObject: globalIndex forKey: @"MessagesById"];
		} else {
			//NSLog(@"Reusing messageId Index 0x%x", globalIndex);
		}
	}
	return globalIndex;
}

- (GIMessage*) messageForMessageId: (NSString*) messageId;
/*" Returns either nil or the message specified by its messageId. "*/
{
	if (! messageId.length) return nil;
	GIMessage* result = [[self messagesByMessageId] objectForKey: messageId];
	return result;
}

- (void) addMessage: (GIMessage*) aMessage 
	 toMessageGroup: (GIMessageGroup*) aGroup 
  suppressThreading: (BOOL) suppressThreading
{
    NSParameterAssert(aMessage != nil);
    
	GIThread* thread = aMessage.thread;
	
	if (! [thread.messageGroups containsObject: aGroup]) {
		[[thread mutableArrayValueForKey: @"messageGroups"] addObject: aGroup];
	}
}

- (void) addMessage: (GIMessage*) aMessage
{
	if (aMessage) {
		// Adding a message should be an atomic operation:
		//if (![GIMessageFilter filterMessage:aMessage flags:0]) {
			[self addMessage:aMessage toMessageGroup:[GIMessageGroup defaultMessageGroup] suppressThreading: NO];
		//}
		
		if ([aMessage hasFlags:OPIsFromMeStatus]) 
		{
			[self addMessage:aMessage toMessageGroup:[GIMessageGroup sentMessageGroup] suppressThreading: NO];
		}
		
		NSAssert(aMessage.thread.messageGroups.count > 0, @"message without group found");
	} 	
}

- (void) addDraftMessage: (GIMessage*) aMessage
{
    GIThread *thread = aMessage.thread;
	// Remove it from the queued message box (if there):
    if (thread) {
		[[[GIMessageGroup queuedMessageGroup] mutableSetValueForKey: @"threads"] removeObject: thread];
	}
    [self addMessage:aMessage toMessageGroup:[GIMessageGroup draftMessageGroup] suppressThreading: YES];
}

- (void) addQueuedMessage: (GIMessage*) aMessage
{
    GIThread *thread = aMessage.thread;
	// Remove it from the queued message box (if there):
    if (thread) {
		[[[GIMessageGroup draftMessageGroup] mutableSetValueForKey: @"threads"] removeObject: thread];
	}
    [self addMessage:aMessage toMessageGroup:[GIMessageGroup queuedMessageGroup] suppressThreading: YES];
}


NSString* MboxImportJobName = @"mbox import";

- (void) importMessagesFromMboxFileWithArguments: (NSDictionary*) arguments
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
    
    NSEnumerator* enumerator = [mboxFile messageDataEnumerator];
    NSData* mboxData;
	
    BOOL messagesWereAdded = NO;
    unsigned mboxDataCount = 0;
    unsigned addedMessageCount = 0;
	
	NSOperation* operation = nil;
//	OPJob *job = [OPJob job];
//	
//    [job setProgressInfo:[job progressInfoWithMinValue:0 
//											  maxValue:mboxFileSize 
//										  currentValue:[enumerator offsetOfNextObject] 
//										   description:@""]];
	
	NSDate *startDate = [NSDate date];
	
    NSAutoreleasePool *pool = nil;
    @try 
	{
        pool = [[NSAutoreleasePool alloc] init];
        
		NSDate *lastLapDate = nil;
		unsigned lastLapCount = 0;
		
        while ((mboxData = [enumerator nextObject]) && ![operation isCancelled]) {
            //NSLog(@"Found mbox data of length %d", [mboxData length]);
            NSData *transferData = [mboxData transferDataFromMboxData];
            
            if (transferData) {
                @try {
                    NSString* flags = nil;
                    unsigned int length = [transferData length];
                    const char* bytes = [transferData bytes];
                    
					// See, if we can find a Gina/Ginko header:
                    if (! strncasecmp("X-Gina-Flags:", bytes, strlen("X-Gina-Flags:"))) {
                        const char *pos = bytes;
                        while ((pos < bytes+length) && (*pos++ != 0x0A))
                            ;
						
                        flags = [[NSString stringWithCString:bytes+strlen("X-Gina-Flags:") length:pos - (bytes + strlen("X-Gina-Flags:") + 2)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
						//                        OPDebugLog(IMPORT, FLAGS, @"Flags: '%@'", flags);
                        
                        transferData = [NSData dataWithBytes:pos length:bytes+length-pos];
						//                       OPDebugLog(IMPORT, TRANSFERDATA, @"transferData: %@", transferData);
                    }
                    
                    
                    //NSMutableArray* args = [NSMutableArray arrayWithObject: transferData];
					
                    // Moved addition to background thread:
					OPInternetMessage* iMessage = [[OPInternetMessage alloc] initWithTransferData: transferData];
					GIMessage *persistentMessage = [GIMessage messageWithInternetMessage: iMessage];
					[iMessage release];
					
					
                    //if (persistentMessage == (GIMessage *)[NSNull null]) persistentMessage = nil;
                    
                    if (persistentMessage) {
						
						[self addMessage: persistentMessage];
						
                        if (flags) [persistentMessage addFlagsFromString: flags];
                        
                        messagesWereAdded = YES;
                        ++addedMessageCount;
                    }
                                        
                    if ((++mboxDataCount % 100) == 0) {
                        if (messagesWereAdded) {   
							NSDate *lapDate = [NSDate date];
							double overallAverage = (double)addedMessageCount / (double)([lapDate timeIntervalSinceReferenceDate] - [startDate timeIntervalSinceReferenceDate]);
							double localAverage = (double)(addedMessageCount - lastLapCount) / (double)([lapDate timeIntervalSinceReferenceDate] - [lastLapDate timeIntervalSinceReferenceDate]);
							
							NSLog(@"Added %u messages so far... (overall average %.2lf, local average %.2lf (in messages/second)) %.2lf%%", addedMessageCount, overallAverage, localAverage, ((double)[enumerator offsetOfNextObject] / (double)mboxFileSize) * 100.0);
                            [self saveChanges];
                            messagesWereAdded = NO;
							[lastLapDate release];
							lastLapDate = [lapDate retain];
							lastLapCount = addedMessageCount;
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
//                    [job setProgressInfo:[job progressInfoWithMinValue:0 maxValue:mboxFileSize currentValue:[enumerator offsetOfNextObject] description:[mboxFilePath lastPathComponent]]];
                    
                    percentComplete = newPercentComplete;
                    [lastProgressSet release];
                    lastProgressSet = [now retain];
                }
                
                [now release];
            }     
            
        }
        
		NSDate *stopDate = [NSDate date];
        NSLog(@"*** Added %u messages in %.2f seconds.", addedMessageCount, [stopDate timeIntervalSinceReferenceDate] - [startDate timeIntervalSinceReferenceDate]);
        
        [self saveChanges];
        //NSAssert1(!error, @"Fatal Error. Committing of added messages failed (%@).", error);    
		
    } @catch (id localException) {
        if (NSDebugEnabled) NSLog(@"Exception while adding messages in background: %@", localException);
        @throw;
    } @finally {
        [lastProgressSet release];
    }
	
	[pool release];
	
    if ([operation isCancelled])
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

- (void) importMboxFiles: (NSArray*) paths
		   moveOnSuccess: (BOOL) doMove
/*" Schedules jobs for paths given. If doMove is YES, the file is moved to the imported folder - copied otherwise. "*/
{
	if ([paths count]) {
		//[self showActivityPanel: self];
		
		NSEnumerator* enumerator = [paths objectEnumerator];
		NSString* boxFilename;
		
		while (boxFilename = [enumerator nextObject]) {
			NSMutableDictionary *jobArguments = [NSMutableDictionary dictionary];
			
			[jobArguments setObject: boxFilename forKey: @"mboxFilename"];
			//[jobArguments setObject: [OPPersistentObjectContext threadContext] forKey: @"parentContext"];
			if (!doMove) [jobArguments setObject: [NSNumber numberWithBool: YES] forKey: @"copyOnly"];
			
			[self importMessagesFromMboxFileWithArguments: jobArguments]; // synchronious for now
			//[OPJob scheduleJobWithName:MboxImportJobName target:[[[GIMessageBase alloc] init] autorelease] selector:@selector(importMessagesFromMboxFileJob:) argument:jobArguments synchronizedObject:@"mbox import"];
		}
	}
}


- (void) moveThreadsWithOids: (NSArray*) threadOids 
				   fromGroup: (GIMessageGroup*) sourceGroup 
					 toGroup: (GIMessageGroup*) destinationGroup
{
	if (sourceGroup != destinationGroup) {
		
		NSEnumerator *enumerator = [threadOids objectEnumerator];
		NSNumber *oid;
		
		while (oid = [enumerator nextObject]) {
			GIThread *thread = [[OPPersistentObjectContext defaultContext] objectForOID:[oid unsignedLongLongValue]];
			
			NSMutableArray* threadGroups = [thread mutableArrayValueForKey: @"messageGroups"];
			// remove thread from source group:
			[threadGroups removeObject: sourceGroup];
			
			// add thread to destination group:
			[threadGroups addObject: destinationGroup];
			
		}
	} else {
		NSLog(@"Warning: Try to move thread into same group %@", self);
	}
}

@end
