//
//  GIFulltextIndexCenter.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 18.04.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "GIFulltextIndexCenter.h"
#import "G3MessageGroup.h"
#import "G3Thread.h"
#import "G3Message.h"
#import "GIIndex.h"
#import "NSApplication+OPExtensions.h"

// Dear Ulf, this is only a proposal to start and methods etc. will likely be changed by you...

@implementation GIFulltextIndexCenter

NSDictionary* indexDictionary;

+ (id)defaultIndexCenter
{
	static GIFulltextIndexCenter *defaultCenter = nil;
	
    NSLog(@"-[GIFulltextIndexCenter defaultIndexCenter]");

	if (!defaultCenter)
	{
		defaultCenter = [[self alloc] init];
        
        NSMutableDictionary* tempIndexDictionary = [NSMutableDictionary dictionaryWithCapacity:3];
        
        NSString* CONTENT_INDEX_PATH = [[[NSApplication sharedApplication] applicationSupportPath] stringByAppendingPathComponent: @"content.index"];
        NSString* SENDER_INDEX_PATH = [[[NSApplication sharedApplication] applicationSupportPath] stringByAppendingPathComponent: @"sender.index"];
        NSString* STATUS_INDEX_PATH = [[[NSApplication sharedApplication] applicationSupportPath] stringByAppendingPathComponent: @"status.index"];
        [tempIndexDictionary setObject:[GIIndex indexWithName:@"contentIndex" atPath:CONTENT_INDEX_PATH]
                                forKey:@"contentIndex"];
        [tempIndexDictionary setObject:[GIIndex indexWithName:@"senderIndex" atPath:SENDER_INDEX_PATH]
                                forKey:@"senderIndex"];
        [tempIndexDictionary setObject:[GIIndex indexWithName:@"statusIndex" atPath:STATUS_INDEX_PATH]
                                forKey:@"statusIndex"];
        
        indexDictionary = [tempIndexDictionary copy];
        [tempIndexDictionary release];
    }

	return defaultCenter;
}

- (BOOL)addMessage:(G3Message *)aMessage
{
    BOOL isIndexed = FALSE;
    NSMutableDictionary* documentPropertiesDict = [[NSMutableDictionary alloc] init];
    [documentPropertiesDict setObject:[aMessage senderName] forKey:@"senderName"];
    
    isIndexed = [[indexDictionary objectForKey:@"contentIndex"] addDocumentWithName:[aMessage messageId]
                                          andText:[[aMessage contentAsAttributedString] string]
                                    andProperties:documentPropertiesDict];
    isIndexed = [[indexDictionary objectForKey:@"senderIndex"] addDocumentWithName:[aMessage messageId]
                                          andText:[aMessage senderName]
                                    andProperties:documentPropertiesDict];
    if ( [aMessage hasFlag:OPFulltextIndexedStatus] ) {
        isIndexed = [[indexDictionary objectForKey:@"statusIndex"] addDocumentWithName:[aMessage messageId]
                                             andText:@"OPFulltextIndexedStatus"
                                       andProperties:documentPropertiesDict];
        #warning GIIndex when does status change?
        #warning GIIndex how to handle more stati
    }
         
    if (isIndexed) {
        [aMessage setFlags:OPFulltextIndexedStatus];
    }
    
    return isIndexed;
}

- (BOOL)removeMessage:(G3Message *)aMessage
{
    BOOL isRemoveSuccessfull;
    isRemoveSuccessfull = [[indexDictionary objectForKey:@"contentIndex"] removeDocumentWithName:[aMessage messageId]];
    isRemoveSuccessfull = [[indexDictionary objectForKey:@"senderIndex"] removeDocumentWithName:[aMessage messageId]];
    isRemoveSuccessfull = [[indexDictionary objectForKey:@"statusIndex"] removeDocumentWithName:[aMessage messageId]];
    if (isRemoveSuccessfull) {
        [aMessage removeFlags:OPFulltextIndexedStatus];
    }
    return isRemoveSuccessfull;
}

- (NSArray *)hitsForQueryString:(NSString *)aQuery
{
 	NSLog(@"-[GIFulltextIndexCenter hitsForQueryString:%@]", aQuery);
    GIIndex* tempContentIndex = [indexDictionary objectForKey:@"contentIndex"];
    if (tempContentIndex) {
        NSLog(@"got index");
    }
	return [tempContentIndex hitsForQueryString:aQuery];
    
    
    //NSMutableArray* resultArray = [NSMutableArray arrayWithArray:[[indexDictionary objectForKey:@"contentIndex"] hitsForQueryString:aQuery]];
    //[resultArray addObjectsFromArray:[[indexDictionary objectForKey:@"senderIndex"] hitsForQueryString:aQuery]];
    //[resultArray addObjectsFromArray:[[indexDictionary objectForKey:@"statusIndex"] hitsForQueryString:aQuery]];
    // return resultArray;
}


- (BOOL)reindexAllMessages
{
    BOOL result;
    NSEnumerator* threadEnumerator;
    NSEnumerator* messageEnumerator;
    G3Thread* tempThread;
    G3Message* tempMessage;
    
    // get default MessageGroup
    #warning get all MessageGroups
    G3MessageGroup* tempMessageGroup = [G3MessageGroup defaultMessageGroup];
    
    // get all threads
    threadEnumerator = [[tempMessageGroup threadsByDate] objectEnumerator];
    while ( tempThread = [threadEnumerator nextObject] ) {
        messageEnumerator = [[tempThread messagesByDate] objectEnumerator];
        while ( tempMessage = [messageEnumerator nextObject] ) {
            result = [self addMessage:tempMessage];
        }
    }
    return result;
}


@end
