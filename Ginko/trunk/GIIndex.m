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
    NSLog(@"+[GIIndex indexWithName:%@ atPath:%@]", aName, aPath);
    return [[[self alloc] initWithName:aName atPath:aPath] autorelease];
}

- (id)initWithName:(NSString*)aName atPath:(NSString *)aPath;
{
    self = [super init];
    
    [self setName:aName];
    NSURL* indexFileURL = [NSURL fileURLWithPath: aPath];
    NSFileManager* fm = [NSFileManager defaultManager];
    
    // open or create index
    if ([fm fileExistsAtPath:aPath]) {
        NSLog(@"-[GIIndex initWithName:%@ atPath:%@] opening existing index", aName, aPath);
        [self setIndex:SKIndexOpenWithURL((CFURLRef)indexFileURL,(CFStringRef)aName, true) ];
    } else {        
        NSLog(@"-[GIIndex initWithName:%@ atPath:%@] creating new index ", aName, aPath);
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
            NSLog(@"Warning: -[GIIndex initWithName:%@ atPath:%@] Couldn't create index", aName, aPath);
        } else {
            NSLog(@"[GIIndex initWithName:%@ atPath:%@] contains %d documents", aName, [self documentCount]);
        }
    }
    //#warning when to call SKIndexClose? In setIndex
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
    // Sets a new index. Closes the previous one.
{
    //NSLog(@"-[GIIndex(%@) setIndex]", [self name]);
    #warning if index == newIndex might release might be dangerous
    if (index) {
        //NSLog(@"-[GIIndex(%@) setIndex] will close/release old index", [self name]);
        SKIndexClose(index);
        CFRelease(index); // initially, index is nil
    }
    if (newIndex) 
    {
        //NSLog(@"-[GIIndex(%@) setIndex] will retain new index", [self name]);
        CFRetain(newIndex);
    } 
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
    BOOL isIndexed = NO;
//	NSLog(@"-[GIIndex(%@) addDocumentWithName:%@",[self name], aName);
    SKDocumentRef tempDocument = [self createDocumentWithName:aName];
    // add document to index
    if (tempDocument) 
    {
        isIndexed = SKIndexAddDocumentWithText([self index], tempDocument, (CFStringRef)aText, YES);
    }
    if (isIndexed)
    {
        SKIndexSetDocumentProperties([self index], tempDocument, (CFDictionaryRef)aPropertiesDictionary);
    }

    [self flushIndex];
    
    return isIndexed;
}

- (BOOL)removeDocumentWithName:(NSString *)aName
{
    BOOL isRemoveSuccessfull = NO;
    if ([self index])
    {
//      NSLog(@"-[GIIndex(%@) removeDocumentWithName:]", [self name]);
        isRemoveSuccessfull = SKIndexRemoveDocument([self index], [self createDocumentWithName:aName]);
        if (isRemoveSuccessfull)
        {
            [self flushIndex];
        }
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
    NSLog(@"-[GIIndex(%@) hitsForQueryString:%@] resulted in %d hit(s) from %d documents", [self name], aQuery, tempOutFoundCount, [self documentCount]);
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
    // CFRelease(searchRef); // crashes, don't know why
    return [[resultArray copy] autorelease];
}



// internal helpers

- (SKDocumentRef)createDocumentWithName:(NSString *)aName
{
    return SKDocumentCreate((CFStringRef)@"Ginko", NULL, (CFStringRef)aName);
}


@end
