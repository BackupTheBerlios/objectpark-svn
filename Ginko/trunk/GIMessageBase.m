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

@implementation GIMessageBase

+ (G3Message *)insertMessageWithTransferData:(NSData *)transferData
/*" Creates a new G3Message object from transferData and adds it to the message base, applying filter rules and threading as necessary. "*/
{
    G3Message *message = [G3Message messageWithTransferData:transferData];
    if (message) 
    {
        G3Thread *thread = [message threadCreate:YES];
        NSSet *groups = [self defaultGroupsForMessage:message];
        
        [thread addGroups:groups];
        
        /*
        // Make sure, thread is contained in all groups:
        int i;
        for (i = [groups count] - 1; i >= 0; i--) 
        {
            G3MessageGroup *group = [groups objectAtIndex:i];
            
            // Add to both sides of relationships:
            [group addValue:thread toRelationshipWithKey:@"threads"];
            [thread addValue:group toRelationshipWithKey:@"groups"];
        }
         */
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
    
    // Add to both sides of relationship:
    [aGroup addValue:thread toRelationshipWithKey:@"threads"];
    [thread addValue:aGroup toRelationshipWithKey:@"groups"];
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
            G3Message *persistentMessage = [self insertMessageWithTransferData:transferData];
            
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
