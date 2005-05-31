//
//  GIMessageBase.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 06.04.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "GIMessageBase.h"
#import "G3Message.h"
#import "G3Thread.h"
#import "G3MessageGroup.h"
#import "OPMBoxFile.h"
#import "NSManagedObjectContext+Extensions.h"
#import "GIUserDefaultsKeys.h"
#import "GIFulltextIndexCenter.h"
#import "NSData+MessageUtils.h"
#import <Foundation/NSDebug.h>

@implementation GIMessageBase

+ (G3Message *)addMessageWithTransferData:(NSData *)someTransferData inManagedObjectContext:(NSManagedObjectContext *)aContext
/*" Creates and returns a new G3Message object from someTransferData in the managed object context aContext and adds it to the message base, applying filter rules and threading as necessary. Returns nil if the message could not be created. "*/
{
    G3Message *message = [G3Message messageWithTransferData:someTransferData];
    
    if (message) 
    {
        G3Thread *thread = [message threadCreate:YES];
        NSSet *groups = [self defaultGroupsForMessage:message];
        
        [thread addGroups:groups];        
    }
    
    // add message to index
    //GIFulltextIndexCenter* indexCenter = [GIFulltextIndexCenter defaultIndexCenter];
    //[indexCenter addMessage:message];
    
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

+ (void)addMessage:(G3Message *)aMessage toMessageGroup:(G3MessageGroup *)aGroup
{
    NSParameterAssert(aMessage != nil);
    
    G3Thread *thread = [aMessage threadCreate:YES];
    
    [thread addGroup:aGroup];
    
    /* old baroque style 
    // Add to both sides of relationship:
    [aGroup addValue:thread toRelationshipWithKey:@"threads"];
    [thread addValue:aGroup toRelationshipWithKey:@"groups"];
    */
}

+ (void)addOutgoingMessage:(G3Message *)aMessage
{
    [self addMessage:aMessage toMessageGroup:[G3MessageGroup outgoingMessageGroup]];
}

+ (NSSet *)defaultGroupsForMessage:(G3Message *)aMessage
/*" Returns an array of G3MessageGroup objects where the given message should go into per the user's filter setting. "*/
{
    // TODO: just a dummy here!
    return [NSSet setWithObjects:[G3MessageGroup defaultMessageGroup], nil];
}

- (void)addMessagesFromMboxFileJob:(NSMutableDictionary *)arguments
/*" Adds messages from the given mbox file (dictionary @"mboxFilename") to the message database applying filters/sorters. 

    Should run as job (#{see OPJobs})."*/
{
    NSString *mboxFilePath = [arguments objectForKey:@"mboxFilename"];
    NSParameterAssert(mboxFilePath != nil);
    
    // Create mbox file object for enumerating the contained messages:
    OPMBoxFile *mboxFile = [OPMBoxFile mboxWithPath:mboxFilePath];
    NSAssert1(mboxFile != nil, @"mbox file at path %@ could not be opened.", mboxFilePath);
    
    // Create a own context for this job/thread but use the same store coordinator
    // as the main thread because this job/threads works for the main thread.
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] init];
    [context setPersistentStoreCoordinator:[[NSManagedObjectContext defaultContext] persistentStoreCoordinator]];
    
    [NSManagedObjectContext setDefaultContext:context];
    
    NSEnumerator *enumerator = [mboxFile messageDataEnumerator];
    NSData *mboxData;
    NSError *error = nil;
    unsigned addedMessageCount = 0;
    
    [[context undoManager] disableUndoRegistration];
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    @try 
    {
        while (mboxData = [enumerator nextObject]) 
        {
            //NSLog(@"Found mbox data of length %d", [mboxData length]);
            NSData *transferData = [mboxData transferDataFromMboxData];
            
            if (transferData)
            {
                @try {
                    G3Message *persistentMessage = [[self class] addMessageWithTransferData:transferData inManagedObjectContext:context];
                    
                    NSAssert1(persistentMessage != nil, @"Fatal error. No message could be generated from transfer data: %@", transferData);
                    
                    if ((++addedMessageCount % 100) == 0) 
                    {
                        if (NSDebugEnabled) NSLog(@"*** Committing changes (added %d messages)...", addedMessageCount);
                        
                        [context save:&error];
                        NSAssert1(!error, @"Fatal Error. Committing of added messages failed (%@).", error);
                        
                        [context reset];
                    }
                } @catch (NSException *localException) {
                    if ([localException name] == GIDupeMessageException)
                    {
                        if (NSDebugEnabled) NSLog(@"%@", [localException reason]);
                        else [localException raise];
                    }
                }
            }
            [pool drain]; // should be last statement in while loop
        }
        
        if (NSDebugEnabled) NSLog(@"*** Added %d messages.", addedMessageCount);
        
        [context save:&error];
        NSAssert1(!error, @"Fatal Error. Committing of added messages failed (%@).", error);    
    } 
    @catch (NSException *localException) 
    {
        if (NSDebugEnabled) NSLog(@"Exception while adding messages in background: %@", localException);
        [localException raise];
    } 
    @finally 
    {
        [pool release];
        [context release];
        [NSManagedObjectContext setDefaultContext:nil];
    }
}

+ (void)importFromMBoxFile:(OPMBoxFile *)box
{
    NSManagedObjectContext *context = [NSManagedObjectContext defaultContext];
            
    NSEnumerator *enumerator = [box messageDataEnumerator];
    NSData *mboxData;
    NSError *error = nil;
        
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    int maxImport = 20000;
    int i = 0;
    int imported = 0;
    int lastImported = 0;
    
    // avoid memory hogging:
    [[context undoManager] disableUndoRegistration];
    
    while (mboxData = [enumerator nextObject]) 
    {
        //NSLog(@"Found mbox data of length %d", [mboxData length]);
        NSData *transferData = [mboxData transferDataFromMboxData];
        
        if (transferData)
        {
            G3Message *persistentMessage = [self addMessageWithTransferData:transferData inManagedObjectContext:[NSManagedObjectContext defaultContext]];
            
            //NSLog(@"Found %d. message with MsgId '%@'", i+1, [persistentMessage messageId]);
            
            if (persistentMessage) 
            {
                imported++;
                //NSLog(@"Thread: %@", [persistentMessage threadCreate: YES]);
            }
            
            if (i++ >= maxImport) break;
            
            if ((i % 100) == 0) 
            {
                NSLog(@"*** Read %d messages (imported %d)...", i, imported);
            }
            
            if (((imported % 100) == 0) && (imported > lastImported)) 
            {
                NSLog(@"*** Committing changes (imported %d)...", imported);
                
                [context save:&error];
                if (error) 
                {
                    NSLog(@"Warning: Commit error: %@", error);
                }
                
                [[context undoManager] removeAllActions];

                lastImported = imported;
            }
        }
        [pool drain]; // should be last statement in while loop
    }
    
    [[context undoManager] enableUndoRegistration];

    [pool release];	
    
    NSLog(@"Processed %d messages. %d imported.", i, imported);
    
    [context save:&error];
    
    if (error) 
    {
        NSLog(@"Warning: Commit error: %@", error);
    }
}

+ (OPMBoxFile *)MBoxLogFile
{
    static OPMBoxFile *mboxFile = nil;
    
#warning path is only for testing
    if (!mboxFile) mboxFile = [OPMBoxFile mboxWithPath:@"/tmp/mboxlogfile.txt" createIfNotPresent:YES];
    
    return mboxFile;
}

+ (void)appendMessage:(G3Message *)aMessage toMBoxFile:(OPMBoxFile *)anMBoxFile
{
    
}

@end
