//
//  GIIndex.m
//  GinkoVoyager
//
//  Created by Ulf Licht on 24.05.05.
//  Copyright 2005 Ulf Licht, Objectpark Group. All rights reserved.
//

#import "GIIndex.h"


@implementation GIIndex

+ (id)indexWithName:(NSString*)aName atPath:(NSString*)aPath
{
    NSLog(@"+[GIIndex indexWithPath:%@]", aPath);
    GIIndex* newIndex = [[self alloc] initWithName:aName atPath:aPath];
    return [newIndex autorelease];
}

- (id)initWithName:(NSString*)aName atPath:(NSString *)aPath;
{
    self = [super init];
    
    [self setName:aName];
    NSURL* indexFileURL = [NSURL fileURLWithPath: aPath];
    NSFileManager* fm = [NSFileManager defaultManager];
    
    // open or create index
    if ([fm fileExistsAtPath:aPath]) {
        [self setIndex:SKIndexOpenWithURL((CFURLRef)indexFileURL,NULL,true)];
    } else {        
        NSMutableDictionary * analysisDict = [[NSMutableDictionary alloc] init];
        [analysisDict setObject:@"en" forKey:(NSString *)kSKLanguageTypes];
        [analysisDict setObject:[NSNumber numberWithInt:2] 
                         forKey:(NSString *)kSKMinTermLength];
        
        // returns an retained index or nil, if failed:
        SKIndexRef theIndex = SKIndexCreateWithURL( 
                                                    // the file: URL of where to place the index file.
                                                    (CFURLRef)indexFileURL,
                                                    //A name for the index (this may be nil).
                                                    (CFStringRef)aName,
                                                    //The type of index.
                                                    kSKIndexInverted,
                                                    //And your index attributes dictionary.
                                                    (CFDictionaryRef)analysisDict);
        
        
        [self setIndex: theIndex]; // setIndex retains it.
        
        if (theIndex) CFRelease(theIndex);
        
        if(index == nil) {
            NSLog(@"Warning: -[GIIndex initWithPath] Couldn't create index.");
        }
    }
    #warning when to call SKIndexClose?
    return self;
}

- (void)dealloc
{
    [self setIndex: nil];
    [name release];
    
    [super dealloc];
}

- (SKIndexRef)index
{
    return index;
}

- (void)setIndex:(SKIndexRef)newIndex

{
    if (index) CFRelease(index); // initially index is nil
    if (newIndex) CFRetain(newIndex);
    index = newIndex;
}

- (NSString *)name
{
    return name;
}

- (void)setName:(NSString * )newName
{
    [newName retain];
    [name release];
    name = newName;
}


- (BOOL)addDocumentWithName:(NSString *)aName andText:(NSString *)aText andProperties:(NSDictionary *) aPropertiesDictionary
{
    BOOL isIndexed = YES;
	NSLog(@"-[GIIndex(%@) addDocumentWithName:%@",[self name], aName);
    SKDocumentRef tempDocument = [self createDocumentWithName:aName];
    // add document to index
    isIndexed = SKIndexAddDocumentWithText([self index], tempDocument, (CFStringRef)aText, YES);
    if (isIndexed) {
        SKIndexSetDocumentProperties([self index], tempDocument, (CFDictionaryRef)aPropertiesDictionary);
    }
    // flush index after every inserted document
    [self flushIndex];
    return isIndexed;
}

- (BOOL)removeDocumentWithName:(NSString *)aName
{
    BOOL isRemoveSuccessfull = NO;
	NSLog(@"-[GIIndex(%@) removeDocumentWithName:]", [self name]);
    isRemoveSuccessfull = SKIndexRemoveDocument([self index], [self createDocumentWithName:aName]);
    if (isRemoveSuccessfull) {
        [self flushIndex];
    }
    return isRemoveSuccessfull;
}

- (BOOL)flushIndex
{
    return SKIndexFlush([self index]);
}

- (BOOL)compactIndex
{
    return SKIndexCompact([self index]);
}

- (CFIndex)documentCount
{
    return SKIndexGetDocumentCount([self index]);
}

- (NSArray *)hitsForQueryString:(NSString *)aQuery
{
 	NSLog(@"-[GIIndex(%@) hitsForQueryString:%@]",[self name], aQuery);
    NSMutableArray* resultArray = [NSMutableArray arrayWithCapacity:10];
    
    // build Search objects
    SKSearchRef searchRef = SKSearchCreate([self index], (CFStringRef)aQuery, kSKSearchOptionDefault);
    // set up and start search
    int tempInMaximumCount = 10;
    int tempMaximumTime = 5;
    // create search output variables and get pointers referencing them
    SKDocumentID tempDocumentIDArray[10];
    SKDocumentID* pointerToDocumentIDArray = &tempDocumentIDArray[0];
    float tempScoresArray[10];
    float* pointerToScoresArray = &tempScoresArray[0];
    CFIndex tempOutFoundCount = 0;
    CFIndex* pointerToOutFoundCount = &tempOutFoundCount;
    SKSearchFindMatches(searchRef, tempInMaximumCount, pointerToDocumentIDArray, pointerToScoresArray, tempMaximumTime, pointerToOutFoundCount);
    NSLog(@"-[GIIndex(%@) hitsForQueryString]search resulted in %d hit(s)", [self name], tempOutFoundCount);
    /*
     while ( SKSearchFindMatches(contentSearchRef, tempInMaximumCount, pointerToDocumentIDArray, pointerToScoresArray, tempMaximumTime, pointerToOutFoundCount) ) {
         NSLog(@"search still in progress with currently %d results", tempOutFoundCount);
     }
     NSLog(@"search exhausted with %d hits", tempOutFoundCount);
     */
    
    // output results
    unsigned int i;
    for (i=0; i<tempOutFoundCount; i++) {
        //NSLog(@"hit: %d with score: %f", tempDocumentIDArray[i], tempScoresArray[i]);
        SKDocumentRef tempHitDocument =  SKIndexCopyDocumentForDocumentID ([self index], tempDocumentIDArray[i]);
        //CFDictionaryRef tempHitProperties = SKIndexCopyDocumentProperties ([self index], tempHitDocument);
        NSString* tempHitName = (NSString*)SKDocumentGetName(tempHitDocument);
        //NSLog(@"hitName: %@", tempHitName);
        [resultArray addObject:tempHitName];
    }
    
    // release
    #warning this crashes, don't know why
    // CFRelease(contentSearchRef); 
    
    return [[resultArray copy] autorelease];
}



// internal helpers

- (SKDocumentRef)createDocumentWithName:(NSString *)aName
{
    return SKDocumentCreate((CFStringRef)@"Ginko", NULL, (CFStringRef)aName);
}


@end
