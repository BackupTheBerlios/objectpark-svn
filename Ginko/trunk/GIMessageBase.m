//
//  GIMessageBase.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 06.04.05.
//  Copyright 2005 Objectpark Group. All rights reserved.
//

#import "GIMessageBase.h"
#import "G3Message.h"
#import "G3Thread.h"
#import "G3Account.h"
#import "G3MessageGroup.h"
#import "OPMBoxFile.h"
#import "NSManagedObjectContext+Extensions.h"
#import "GIUserDefaultsKeys.h"
#import "GIFulltextIndexCenter.h"
#import "NSData+MessageUtils.h"
#import <Foundation/NSDebug.h>
#import "OPJobs.h"
#import "GIMessageFilter.h"
#import "OPPOP3Session.h"
#import "NSApplication+OPExtensions.h"

@implementation GIMessageBase

+ (G3Message *)addMessageWithTransferData:(NSData *)someTransferData
/*" Creates and returns a new G3Message object from someTransferData in the managed object context aContext and adds it to the message base, applying filter rules and threading as necessary. Returns nil if message was a dupe messsage. "*/
{
    G3Message *message = [G3Message messageWithTransferData:someTransferData];
    
    if (message) // if no dupe
    {
        if (![GIMessageFilter filterMessage:message flags:0])
        {
            [self addMessage:message toMessageGroup:[G3MessageGroup defaultMessageGroup] suppressThreading:NO];
        }
        
        // add message to index
        //GIFulltextIndexCenter* indexCenter = [GIFulltextIndexCenter defaultIndexCenter];
        //[indexCenter addMessage:message];
    }
    
    return message;
}

+ (void)removeMessage:(G3Message *)aMessage
{	
    // remove message from index
    //[[GIFulltextIndexCenter defaultIndexCenter] removeMessage:aMessage];

    G3Thread *thread = [aMessage thread];
        
    // delete thread also if it would become a thread without messages:
    if ([thread messageCount] == 1)
    {
        [[NSManagedObjectContext defaultContext] deleteObject:thread];		
    }
    
    // delete message:
    [[NSManagedObjectContext defaultContext] deleteObject:aMessage];
}

+ (void)addMessage:(G3Message *)aMessage toMessageGroup:(G3MessageGroup *)aGroup suppressThreading:(BOOL)suppressThreading
{
    NSParameterAssert(aMessage != nil);
    
    G3Thread *thread = [aMessage threadCreate:!suppressThreading];
    if (!thread)
    {
        thread = [G3Thread threadInManagedObjectContext:[aMessage managedObjectContext]];
        [thread setValue:[aMessage valueForKey:@"subject"] forKey:@"subject"];
        [aMessage setValue:thread forKey:@"thread"];
        [thread addMessage:aMessage];
    }
    
    [aGroup addThread:thread];
    //[thread addGroup:aGroup];    
}

+ (void)addSentMessage:(G3Message *)aMessage
{
    [self addMessage:aMessage toMessageGroup:[G3MessageGroup sentMessageGroup] suppressThreading:NO];
}

+ (void)addDraftMessage:(G3Message *)aMessage
{
    G3Thread *thread = [aMessage threadCreate:NO];
    if (thread) [[G3MessageGroup queuedMessageGroup] removeThread:thread];
    [self addMessage:aMessage toMessageGroup:[G3MessageGroup draftMessageGroup] suppressThreading:YES];
}

+ (void)addQueuedMessage:(G3Message *)aMessage
{
    G3Thread *thread = [aMessage threadCreate:NO];
    if (thread) [[G3MessageGroup draftMessageGroup] removeThread:thread];
    [self addMessage:aMessage toMessageGroup:[G3MessageGroup queuedMessageGroup] suppressThreading:YES];
}

+ (void)addTrashThread:(G3Thread *)aThread
{
    [[G3MessageGroup draftMessageGroup] removeThread:aThread];
    [[G3MessageGroup queuedMessageGroup] removeThread:aThread];
    
    [[G3MessageGroup trashMessageGroup] addThread:aThread];
}

+ (void)removeDraftMessage:(G3Message *)aMessage
/*" Removes group and message from aMessage's thread. "*/
{
    G3Thread *thread = [aMessage thread];
    NSAssert(thread != nil, @"draft message without thread");
    
    [thread removeGroup:[G3MessageGroup draftMessageGroup]];
    [thread removeMessage:aMessage];
}

+ (NSSet *)defaultGroupsForMessage:(G3Message *)aMessage
/*" Returns an array of G3MessageGroup objects where the given message should go into per the user's filter setting. "*/
{
    // TODO: just a dummy here!
    return [NSSet setWithObjects:[G3MessageGroup defaultMessageGroup], nil];
}

NSString *MboxImportJobName = @"mbox import";

- (void)importMessagesFromMboxFileJob:(NSMutableDictionary *)arguments
/*" Adds messages from the given mbox file (dictionary @"mboxFilename") to the message database applying filters/sorters. 

    Should run as job (#{see OPJobs})."*/
{
    NSString *mboxFilePath = [arguments objectForKey:@"mboxFilename"];
    NSParameterAssert(mboxFilePath != nil);
    NSManagedObjectContext *parentContext = [arguments objectForKey:@"parentContext"];
    NSParameterAssert(parentContext != nil);
    BOOL shouldCopyOnly = [[arguments objectForKey:@"copyOnly"] boolValue];
    int percentComplete = -1;
    NSDate *lastProgressSet = [[NSDate alloc] init];
    
    // Create mbox file object for enumerating the contained messages:
    OPMBoxFile *mboxFile = [OPMBoxFile mboxWithPath:mboxFilePath];
    NSAssert1(mboxFile != nil, @"mbox file at path %@ could not be opened.", mboxFilePath);
    unsigned int mboxFileSize = [mboxFile mboxFileSize];
    
    // Create a own context for this job/thread but use the same store coordinator
    // as the main thread because this job/threads works for the main thread.
    NSManagedObjectContext *context = parentContext; //[[NSManagedObjectContext alloc] init];
    //[context setPersistentStoreCoordinator:[parentContext persistentStoreCoordinator]];
    //[context setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
    
    [NSManagedObjectContext setDefaultContext:context];
    //[NSManagedObjectContext setDefaultContext:parentContext];
    
    NSEnumerator *enumerator = [mboxFile messageDataEnumerator];
    NSData *mboxData;
    NSError *error = nil;
    unsigned addedMessageCount = 0;
    unsigned mboxDataCount = 0;
    
    [[context undoManager] disableUndoRegistration];
    
    [OPJobs setProgressInfo:[OPJobs progressInfoWithMinValue:0 maxValue:mboxFileSize currentValue:[enumerator offsetOfNextObject] description:@""]];
    
    NSAutoreleasePool *pool = nil;
    
    @try 
    {
        pool = [[NSAutoreleasePool alloc] init];
        
        while (mboxData = [enumerator nextObject]) 
        {
            //NSLog(@"Found mbox data of length %d", [mboxData length]);
            NSData *transferData = [mboxData transferDataFromMboxData];
            
            if (transferData)
            {
                @try {
                    G3Message *persistentMessage = [[self class] addMessageWithTransferData:transferData];
                    
                    if ((++mboxDataCount % 100) == 0) 
                    {
                        if (persistentMessage) 
                        {
                            if ((++addedMessageCount % 100) == 0)
                            {
                                if (NSDebugEnabled) NSLog(@"*** Committing changes (added %d messages)...", addedMessageCount);
                                
                                [context save:&error];
                                if (error)
                                {
                                    NSLog(@"Error in Import Job. Committing of added messages failed (%@).", error);
                                }
                                //[context reset];
                            }
                        }
                        
                        [pool drain]; pool = [[NSAutoreleasePool alloc] init];                            
                    }
                } @catch (NSException *localException) {
                    if ([localException name] == GIDupeMessageException) 
                    {
                        if (NSDebugEnabled) NSLog(@"%@", [localException reason]);
                        [pool drain]; pool = [[NSAutoreleasePool alloc] init];
                    } 
                    else 
                    {
                        [localException raise];
                    }
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
            
            if ((++mboxDataCount % 100) == 0) 
            {
                
            }
        }
        
        if (NSDebugEnabled) NSLog(@"*** Added %d messages.", addedMessageCount);
        
        [context save:(NSError **)&error];
        NSAssert1(!error, @"Fatal Error. Committing of added messages failed (%@).", error);    
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
        [NSManagedObjectContext setDefaultContext:nil];
        [pool release];
        [context release];
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
