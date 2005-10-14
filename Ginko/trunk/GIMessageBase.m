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
#import <Foundation/NSDebug.h>
#import "OPJobs.h"
#import "GIMessageFilter.h"
#import "OPPOP3Session.h"
#import "NSApplication+OPExtensions.h"

@implementation GIMessageBase

- (void)addMessageInMainThreadWithTransferData:(NSMutableArray *)parameters
{
    GIMessage *message = [GIMessage messageWithTransferData:[parameters objectAtIndex:0]];
    
    if (message) // if no dupe
    {
        if (![GIMessageFilter filterMessage:message flags:0])
        {
            [[self class] addMessage:message toMessageGroup:[GIMessageGroup defaultMessageGroup] suppressThreading:NO];
        }
        
        if ([message hasFlags:OPIsFromMeStatus])
        {
            [[self class] addMessage:message toMessageGroup:[GIMessageGroup sentMessageGroup] suppressThreading:NO];
        }
        
        // add message to index
        //GIFulltextIndexCenter* indexCenter = [GIFulltextIndexCenter defaultIndexCenter];
        //[indexCenter addMessage:message];
        NSLog(@"adding message in main thread... '%@'", [[message internetMessage] subject]);
        [parameters addObject:message]; // out param
    }
    else
    {
        [parameters addObject:[NSNull null]];
    }
}

+ (GIMessage *)addMessageWithTransferData:(NSData *)someTransferData
/*" Creates and returns a new GIMessage object from someTransferData in the managed object context aContext and adds it to the message base, applying filter rules and threading as necessary. Returns nil if message was a dupe messsage. "*/
{
    GIMessage *message = [GIMessage messageWithTransferData:someTransferData];
    
    if (message) // if no dupe
    {
        if (![GIMessageFilter filterMessage:message flags:0])  
        {
            [self addMessage:message toMessageGroup:[GIMessageGroup defaultMessageGroup] suppressThreading:NO];
        }
        
        if ([message hasFlags:OPIsFromMeStatus]) 
        {
            [self addMessage:message toMessageGroup:[GIMessageGroup sentMessageGroup] suppressThreading:NO];
        }
        
        // add message to index
        //GIFulltextIndexCenter* indexCenter = [GIFulltextIndexCenter defaultIndexCenter];
        //[indexCenter addMessage:message];
    }
    
    return message;
}

+ (void)removeMessage:(GIMessage *)aMessage
{	
    // remove message from index
    //[[GIFulltextIndexCenter defaultIndexCenter] removeMessage:aMessage];

    GIThread *thread = [aMessage thread];
        
    // delete thread also if it would become a thread without messages:
    if ([thread messageCount] == 1) 
    {
        [[aMessage context] deleteObject:thread];		
    }
    
    // delete message:
    [[aMessage context] deleteObject:aMessage];
}

+ (void)addMessage:(GIMessage *)aMessage toMessageGroup:(GIMessageGroup *)aGroup suppressThreading:(BOOL)suppressThreading
{
    NSParameterAssert(aMessage != nil);
    
    GIThread *thread = [aMessage threadCreate:!suppressThreading];
    if (!thread) 
    {
        thread = [[GIThread alloc] init];
		[thread insertIntoContext:[aMessage context]];
        [thread setValue:[aMessage valueForKey: @"subject"] forKey:@"subject"];
        [aMessage setValue:thread forKey:@"thread"];
        [thread addToMessages:aMessage];
		[thread release];
    }
    
    [aGroup addThread:thread];
    //[thread addGroup:aGroup];    
}

+ (void)addSentMessage:(GIMessage *)aMessage
{
    [GIMessageFilter filterMessage:aMessage flags:0]; // put the message where it belongs
    [self addMessage:aMessage toMessageGroup:[GIMessageGroup sentMessageGroup] suppressThreading:NO];
}

+ (void)addDraftMessage:(GIMessage *)aMessage
{
    GIThread *thread = [aMessage threadCreate:NO];
    if (thread) [[GIMessageGroup queuedMessageGroup] removeThread:thread];
    [self addMessage:aMessage toMessageGroup:[GIMessageGroup draftMessageGroup] suppressThreading:YES];
}

+ (void)addQueuedMessage:(GIMessage *)aMessage
{
    GIThread *thread = [aMessage threadCreate:NO];
    if (thread) [[GIMessageGroup draftMessageGroup] removeThread:thread];
    [self addMessage:aMessage toMessageGroup:[GIMessageGroup queuedMessageGroup] suppressThreading:YES];
}

+ (void)addTrashThread:(GIThread *)aThread
{
    [[GIMessageGroup draftMessageGroup] removeThread:aThread];
    [[GIMessageGroup queuedMessageGroup] removeThread:aThread];
    
    [[GIMessageGroup trashMessageGroup] addThread:aThread];
}

+ (void)removeDraftMessage:(GIMessage *)aMessage
/*" Removes group and message from aMessage's thread. "*/
{
    GIThread *thread = [aMessage thread];
    NSAssert(thread != nil, @"draft message without thread");
    
    [thread removeFromGroups:[GIMessageGroup draftMessageGroup]];
    [thread removeFromMessages:aMessage];
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
    OPPersistentObjectContext* context = [OPPersistentObjectContext threadContext];  
    [context setMergePolicy: NSMergeByPropertyObjectTrumpMergePolicy];
    
    NSEnumerator *enumerator = [mboxFile messageDataEnumerator];
    NSData *mboxData;

    BOOL     messagesWereAdded = NO;
    unsigned mboxDataCount     = 0;
    unsigned addedMessageCount = 0;
    
    [[context undoManager] disableUndoRegistration];
    
    [OPJobs setProgressInfo:[OPJobs progressInfoWithMinValue:0 maxValue:mboxFileSize currentValue:[enumerator offsetOfNextObject] description:@""]];
    
    NSAutoreleasePool *pool = nil;
    
    @try {
        pool = [[NSAutoreleasePool alloc] init];
        
        while (mboxData = [enumerator nextObject]) {
            //NSLog(@"Found mbox data of length %d", [mboxData length]);
            NSData *transferData = [mboxData transferDataFromMboxData];
            
            if (transferData)
            {;
                @try 
                {
                    NSMutableArray *args = [NSMutableArray arrayWithObject:transferData];
                    [self performSelectorOnMainThread:@selector(addMessageInMainThreadWithTransferData:) withObject:args waitUntilDone:YES];
                        
                    GIMessage *persistentMessage = [args objectAtIndex:1];
                    
                    if (persistentMessage == (GIMessage *)[NSNull null]) persistentMessage = nil;
                    
                    //GIMessage *persistentMessage = [[self class] addMessageWithTransferData:transferData];
                    if (persistentMessage) 
                    {
                        messagesWereAdded = YES;
                        ++addedMessageCount;
                    }

                    [persistentMessage flushInternetMessageCache]; // free some memory
                    
                    if ((++mboxDataCount % 100) == 0) {
                        if (messagesWereAdded) {
                            if (NSDebugEnabled) NSLog(@"*** Committing changes (added %u messages)...", addedMessageCount);
                            
                            //[NSApp performSelectorOnMainThread: @selector(saveAction:) withObject: self waitUntilDone: YES];
                            NSError *error = nil;
                            [context saveChanges];

                            messagesWereAdded = NO;
                            //[context reset];
                        }
                        
                        [pool release]; pool = [[NSAutoreleasePool alloc] init];                            
                    }
                } 
                @catch (NSException *localException) 
                {
                    [localException retain]; [localException autorelease]; // Try to avoid zombie exception object
                    [localException raise];
                }
            }
            
            if (mboxFileSize > 0) // avoid division by zero
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
        
        //[NSApp performSelectorOnMainThread:@selector(saveAction:) withObject:self waitUntilDone:YES];
        [context saveChanges];
        //NSAssert1(!error, @"Fatal Error. Committing of added messages failed (%@).", error);    
    } 
    @catch (NSException *localException) 
    {
        if (NSDebugEnabled) NSLog(@"Exception while adding messages in background: %@", localException);
        [[localException retain] autorelease];
        @throw;
    } 
    @finally 
    {
        [lastProgressSet release];
        [OPPersistentObjectContext resetThreadContext];
        [pool release];
    }
    
    // move imported mbox to imported boxes:
    NSString *importedMboxesDirectory = [[NSApp applicationSupportPath] stringByAppendingPathComponent:@"imported mboxes"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:importedMboxesDirectory])
    {
        NSAssert1([[NSFileManager defaultManager] createDirectoryAtPath:importedMboxesDirectory attributes:nil], @"Could not create directory %@", importedMboxesDirectory);
    }
    
    NSString *destinationPath = [importedMboxesDirectory stringByAppendingPathComponent:[mboxFilePath lastPathComponent]];
    
    // only move if not already there:
    if (![[NSFileManager defaultManager] fileExistsAtPath:destinationPath])
    {
        if (shouldCopyOnly)
        {
            NSAssert2([[NSFileManager defaultManager] copyPath:mboxFilePath toPath:destinationPath handler:NULL], @"Could not copy imported mbox at path %@ to directory %@", mboxFilePath, destinationPath);
        }
        else
        {
            NSAssert2([[NSFileManager defaultManager] movePath:mboxFilePath toPath:destinationPath handler:NULL], @"Could not move imported mbox at path %@ to directory %@", mboxFilePath, destinationPath);
        }
    }
}

@end
