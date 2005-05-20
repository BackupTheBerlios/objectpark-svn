//
//  GIFulltextIndexCenter.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 18.04.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "GIFulltextIndexCenter.h"
#import "G3Message.h"

// Dear Ulf, this is only a proposal to start and methods etc. will likely be changed by you...

@implementation GIFulltextIndexCenter

SKIndexRef theIndex;

+ (id)defaultIndexCenter
{
	static GIFulltextIndexCenter *defaultCenter = nil;
    NSString* filePath = @"/tmp/testindex";
	
    NSLog(@"-[GIFulltextIndexCenter defaultIndexCenter]");

	if (!defaultCenter)
	{
		defaultCenter = [[self alloc] init];
        theIndex = [defaultCenter getIndexWithPath:filePath];
        NSParameterAssert(theIndex!=NULL);
        #warning when to call SKIndexClose?
	}

	return defaultCenter;
}

- (BOOL)addMessage:(G3Message *)aMessage
{
	NSLog(@"-[GIFulltextIndexCenter addMessage:]");
    BOOL isIndexed = FALSE;
    NSString* tempScheme = @"Ginko";
    NSString* tempMessageId = [aMessage messageId];
    NSString* tempDocumentText = [[aMessage contentAsAttributedString] string];
    // create document
	SKDocumentRef tempDocument = SKDocumentCreate((CFStringRef)tempScheme, NULL, (CFStringRef)tempMessageId);
    // add document to index
    isIndexed = SKIndexAddDocumentWithText(theIndex, tempDocument, (CFStringRef)tempDocumentText, TRUE);
    if (isIndexed) {
        [aMessage setFlags:OPFulltextIndexedStatus];
    }
    
    // flush index after every inserted document
    if (SKIndexFlush(theIndex))
    {
        NSLog(@"index flushed\n");
    }
    NSLog(@"index contains %d documents", SKIndexGetDocumentCount(theIndex));
    return isIndexed;
}

- (void)removeMessage:(G3Message *)aMessage
{
    #warning removeMessage not yet implemented
	NSLog(@"-[GIFulltextIndexCenter removeMessage:]");
}

- (NSArray *)hitsForQueryString:(NSString *)aQuery
{
 	NSLog(@"-[GIFulltextIndexCenter hitsForQueryString:%@]", aQuery);
    
    // debug index
    CFIndex tempTermID = SKIndexGetTermIDForTermString (theIndex, (CFStringRef)aQuery);
    CFIndex tempTermCount = SKIndexGetTermDocumentCount (theIndex, tempTermID);
    CFIndex tempTermDocumentCount = SKIndexGetTermDocumentCount (theIndex, tempTermID);
 	NSLog(@"term %@ has termID %d and appears %d time(s) in %d document(s)", aQuery, tempTermID, tempTermCount, tempTermDocumentCount);
    
    // build Search object
    SKSearchRef tempSearchRef = SKSearchCreate(theIndex, (CFStringRef)aQuery, kSKSearchOptionDefault);
    // start search
    int tempInMaximumCount = 10;
    int tempMaximumTime = 10;
    SKDocumentID tempDocumentIDArray[10];
    float tempScoresArray[10];
    CFIndex tempOutFoundCount = 0;
    NSLog(@"starting search %d", tempOutFoundCount);
    Boolean searchResult = SKSearchFindMatches(tempSearchRef, tempInMaximumCount, tempDocumentIDArray, tempScoresArray, tempMaximumTime, (void*)tempOutFoundCount);
    if (searchResult) {
        NSLog(@"search still in progress");
    } else {
        NSLog(@"search exhausted");
    }
    //while ( SKSearchFindMatches(tempSearchRef, tempInMaximumCount, tempDocumentIDArray, tempScoresArray, tempMaximumTime, tempOutFoundCount) ) {
    //    NSLog(@"number of hits during search: %d", tempOutFoundCount);
    //};
    NSLog(@"number of hits after search: %d", tempOutFoundCount);
    unsigned int i;
    for (i=0; i<tempInMaximumCount; i++) {
        NSLog(@"hit: %d with score: %f", tempDocumentIDArray[i], tempScoresArray[i]);
    }
    
    // release
    #warning this crashes, don't know why
    // CFRelease(tempSearchRef); 
    
	return nil;
}

- (SKIndexRef)getIndexWithPath:(NSString*)aPath
{
    SKIndexRef tempIndex;
    NSURL* indexFileURL = [NSURL fileURLWithPath: aPath];
    NSFileManager* fm = [NSFileManager defaultManager];
    
    // open or create index
    if ([fm fileExistsAtPath:aPath]) {
        tempIndex = SKIndexOpenWithURL((CFURLRef)indexFileURL,NULL,true);
        NSLog(@"Opened existing index");
    } else {        
        NSMutableDictionary * analysisDict = [[NSMutableDictionary alloc] init];
        [analysisDict setObject:@"en" forKey:(NSString *)kSKLanguageTypes];
        [analysisDict setObject:[NSNumber numberWithInt:2] 
                         forKey:(NSString *)kSKMinTermLength];
        
        tempIndex = SKIndexCreateWithURL( 
                                         // the file: URL of where to place the index file.
                                         (CFURLRef)indexFileURL,
                                         //A name for the index (this may be nil).
                                         NULL,
                                         //The type of index.
                                         kSKIndexInverted,
                                         //And your index attributes dictionary.
                                         (CFDictionaryRef)analysisDict);
        
        if(tempIndex == nil) {
            NSLog(@"Couldn't create index.");
        } else {
            NSLog(@"Created new index");
        }
    }
    return tempIndex;
}

@end
