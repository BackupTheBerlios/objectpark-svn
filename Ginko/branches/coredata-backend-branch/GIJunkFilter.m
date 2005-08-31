/*
 $Id: GIJunkFilter.m,v 1.1 2005/04/14 17:28:14 theisen Exp $

 Copyright (c) 2001, 2002 by Bjšrn Bubbat. All rights reserved.

 Permission to use, copy, modify and distribute this software and its documentation
 is hereby granted, provided that both the copyright notice and this permission
 notice appear in all copies of the software, derivative works or modified versions,
 and any portions thereof, and that both notices appear in supporting documentation,
 and that credit is given to Bjšrn Bubbat in all documents and publicity
 pertaining to direct or indirect use of this code or its derivatives.

 THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
 SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
 "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
 DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
 OR OF ANY DERIVATIVE WORK.

 Further information can be found on the project's web pages
 at http://www.objectpark.org/Ginko.html
 */

#import "GIJunkFilter.h"
#import "NSApplication+OPExtensions.h"

// constants for the Graham formula
#define HAM_BIAS	2		// give ham words more weight
#define KEEPERS		15		// how many extrema to keep
#define MINIMUM_FREQ	5		// minimum freq
#define UNKNOWN_WORD	0.4f		// odds that unknown word is spammish
#define SPAM_CUTOFF	0.9f		// if it's spammier than this...
#define MAX_REPEATS	4		// cap on word frequency per message
#define MAX_WORDS       500             // do not use more words per message

#define DEVIATION(n)	fabs((n) - 0.5f)	// deviation from average

#define max(x, y)	(((x) > (y)) ? (x) : (y))
#define min(x, y)	(((x) < (y)) ? (x) : (y))

typedef struct
{
    NSString *key;
    double prob;
}
discrim_t;

typedef struct
{
    double spamicity;
    discrim_t extrema[KEEPERS];
}
bogostat_t;

static NSString *GIJunkFilterHamWordList = @"GIJunkFilter Ham Word List";
static NSString *GIJunkFilterSpamWordList = @"GIJunkFilter Spam Word List";
static NSString *GIJunkFilterHamUniqueIdList = @"GIJunkFilter Ham Unique ID List";
static NSString *GIJunkFilterSpamUniqueIdList = @"GIJunkFilter Spam Unique ID List";
static NSString *GIJunkFilterHamMessageCount = @"GIJunkFilter Ham Message Count";
static NSString *GIJunkFilterSpamMessageCount = @"GIJunkFilter Spam Message Count";

NSString* GINewHamWordsInSpamFilter = @"GINewHamWordsInSpamFilter";
NSString* GINewSpamWordsInSpamFilter = @"GINewSpamWordsInSpamFilter";

@interface GIWordEnumerator: NSEnumerator {
    NSData* messageData;
    unsigned processPointer; // points to the search offset for the next word
}

- (id) initWithTransferData: (NSData*) data;

+ (id) enumeratorWithTransferData: (NSData*) data;

@end

@implementation GIJunkFilter

NSString *_junkFilterDefinitionsPath()
{
    return [[NSApp applicationSupportPath] stringByAppendingPathComponent:@"JunkFilterDefinitions.ginko"];
}


+(GIJunkFilter *)sharedInstance
{
    static GIJunkFilter *_sharedInstance = nil;
    if (!_sharedInstance)
    {
        _sharedInstance = [[NSKeyedUnarchiver unarchiveObjectWithFile:_junkFilterDefinitionsPath()] retain];
        if (_sharedInstance == nil)
        {
            _sharedInstance = [[GIJunkFilter alloc] init];
        }
    }
    return _sharedInstance;
}


+(void)writeJunkFilterDefintion
{
    GIJunkFilter *junkFilter = [GIJunkFilter sharedInstance];
    BOOL result = [NSKeyedArchiver archiveRootObject:junkFilter
                                              toFile:_junkFilterDefinitionsPath()];
    if (!result)
    {
        [NSException raise:NSGenericException format:@"Couldn't write junk filter definition data to Ginko's Application Support folder!"];
    }

}


-(id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    if (self)
    {
        hamWordList = [[decoder decodeObjectForKey:GIJunkFilterHamWordList] retain];
        spamWordList = [[decoder decodeObjectForKey:GIJunkFilterSpamWordList] retain];
        hamUniqueIdList = [[decoder decodeObjectForKey:GIJunkFilterHamUniqueIdList] retain];
        spamUniqueIdList = [[decoder decodeObjectForKey:GIJunkFilterSpamUniqueIdList] retain];
        spamMessageCount = [decoder decodeIntForKey:GIJunkFilterHamMessageCount];
        hamMessageCount = [decoder decodeIntForKey:GIJunkFilterSpamMessageCount];
    }
    return self;
}


-(void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:hamWordList forKey:GIJunkFilterHamWordList];
    [encoder encodeObject:spamWordList forKey:GIJunkFilterSpamWordList];
    [encoder encodeObject:hamUniqueIdList forKey:GIJunkFilterHamUniqueIdList];
    [encoder encodeObject:spamUniqueIdList forKey:GIJunkFilterSpamUniqueIdList];
    [encoder encodeInt:spamMessageCount forKey:GIJunkFilterHamMessageCount];
    [encoder encodeInt:hamMessageCount forKey:GIJunkFilterSpamMessageCount];
}


-(id)init
{
    self = [super init];
    if (self)
    {
        hamWordList = [[NSMutableDictionary dictionary] retain];
        spamWordList = [[NSMutableDictionary dictionary] retain];
        hamUniqueIdList = [[NSMutableArray array] retain];
        spamUniqueIdList = [[NSMutableArray array] retain];
        spamMessageCount = 0;
        hamMessageCount = 0;
    }
    return self;
}

-(BOOL)optimize
{
    NSMutableSet *keys;
    NSEnumerator *enumerator;
    NSString *key;
    BOOL didOptimize = NO;
    
    keys = [NSMutableSet setWithArray:[spamWordList allKeys]];
    [keys addObjectsFromArray:[hamWordList allKeys]];
    enumerator = [keys objectEnumerator];

    while (key = [enumerator nextObject]) {
        int totalCount;

        totalCount = [[spamWordList objectForKey:key] intValue] + [[hamWordList objectForKey:key] intValue];
        if (totalCount < MINIMUM_FREQ)
        {
            [spamWordList removeObjectForKey:key];
            [hamWordList removeObjectForKey:key];
            didOptimize = YES;
        }
    }
    if (didOptimize)
    {
        NSLog(@"Junk got optimized.");
    }
    return didOptimize;
}


/*
- (NSEnumerator*) wordEnumeratorForMessageData: (NSData*) data
{
    return [GIWordEnumerator enumeratorWithMessageData: data];
}
*/

-(NSDictionary*) processMessageData: (NSData*) aMessageData
{
    //NSMutableCharacterSet *workingSet;
    //NSCharacterSet *finalCharSet;

    //NSScanner *theScanner;

    NSMutableDictionary *privateWordList;
    NSAutoreleasePool* innerPool;
    NSEnumerator* wordEnumerator;
    NSString* aWord;
    unsigned count;
    
    //workingSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy];
    //[workingSet formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
    //[workingSet addCharactersInString:@"<>\"="];
    //finalCharSet = [workingSet copy];
    //[workingSet release];

    //theScanner = [NSScanner scannerWithString:aMessage];
    privateWordList = [NSMutableDictionary dictionary];

    innerPool = [[NSAutoreleasePool alloc] init];
    wordEnumerator = [GIWordEnumerator enumeratorWithTransferData: aMessageData];
    aWord = nil;
    count = MAX_WORDS;

    while ((aWord=[wordEnumerator nextObject]) && count--) {
        // Get the first MAX_WORDS words:
        if ([aWord length]>1 && [aWord length] < 40)
        {
            int wordCount = [[privateWordList objectForKey:aWord] intValue];

            if (wordCount < MAX_REPEATS) {
                [privateWordList setObject: [NSNumber numberWithInt: wordCount+1]
                                    forKey: aWord];
            }
        }
    }
    [innerPool release];

    /*
    while ([theScanner isAtEnd] == NO) {
        NSAutoreleasePool * innerPool = [[NSAutoreleasePool alloc] init];
        NSString *aWord = nil;
        if ([theScanner scanUpToCharactersFromSet:finalCharSet intoString:&aWord] ||
            [theScanner scanCharactersFromSet:finalCharSet intoString:nil])
        {
            NSNumber *wordCount;
            NSLog(@"NSScanner found word '%@'.", aWord);
            aWord = [aWord lowercaseString];
            if ([aWord length]>1 && [aWord length] < 40)
            {
                wordCount = [privateWordList objectForKey:aWord];

                if (wordCount)
                {
                    if ([wordCount intValue] < MAX_REPEATS)
                    {
                        wordCount = [NSNumber numberWithInt:[wordCount intValue]+1];
                        [privateWordList setObject:wordCount
                                            forKey:aWord];
                    }
                }
                else
                {
                    wordCount = [NSNumber numberWithInt:1];
                    [privateWordList setObject:wordCount
                                        forKey:aWord];
                }
            }
        }
        
        [innerPool release];
    }
    */
    return privateWordList;
}

-(void)merge:(NSDictionary *)sourceList withList:(NSMutableDictionary *)destinationList
{
    NSEnumerator *enumerator = [sourceList keyEnumerator];
    NSString *key;

    while (key = [enumerator nextObject])
    {
        NSNumber *destinationValue;
        int count;

        count = [[sourceList objectForKey:key] intValue];
        destinationValue = [destinationList objectForKey:key];
        if (destinationValue)
        {
            count += [destinationValue intValue];
        }
        [destinationList setObject:[NSNumber numberWithInt:count]
                            forKey:key];
    }

}


-(void)remove:(NSDictionary *)sourceList fromList:(NSMutableDictionary *)destinationList
{
    NSEnumerator *enumerator = [sourceList keyEnumerator];
    NSString *key;

    while (key = [enumerator nextObject])
    {
        NSNumber *destinationValue;
        int count;

        count = [[sourceList objectForKey:key] intValue];
        destinationValue = [destinationList objectForKey:key];
        if (destinationValue)
        {
            count -= [destinationValue intValue];
            if (count <= 0)
            {
                [destinationList removeObjectForKey:key];
            }
            else
            {
                [destinationList setObject:[NSNumber numberWithInt:count]
                                    forKey:key];
            }
        }
    }

}


- (void) registerHamMessageTransferData: (NSData*) aMessageData
                           withUniqueId: (NSString*) aUniqueId
/*" Sends a GINewHamWordsInSpamFilter notification to the default notification center, whenever new ham words have been added. "*/
{
    //NSString* aMessage = [[[NSString alloc] initWithData: aMessageData
    //                                            encoding: NSNonLossyASCIIStringEncoding] autorelease];
    
    [[GIWordEnumerator enumeratorWithTransferData: aMessageData] allObjects];
    
    if (![hamUniqueIdList containsObject:aUniqueId])
    {
        NSDictionary *wordList;

        wordList = [self processMessageData: aMessageData];

        if ([spamUniqueIdList containsObject:aUniqueId])
        {
            [self remove:wordList
                fromList:spamWordList];
            [spamUniqueIdList removeObject:aUniqueId];
            spamMessageCount--;

        }
        hamMessageCount++;
        [hamUniqueIdList addObject:aUniqueId];
        [self merge:wordList
           withList:hamWordList];

        [[NSNotificationCenter defaultCenter] postNotificationName: GINewHamWordsInSpamFilter
                                                            object: self]; 
    }
}


- (void) registerSpamMessageTransferData: (NSData*) aMessageData
                            withUniqueId: (NSString*) aUniqueId
/*" Sends a GINewSpamWordsInSpamFilter notification to the default notification center, whenever new spam words have been added. "*/
{
    //NSString* aMessage = [[[NSString alloc] initWithData: aMessageData
    //                                            encoding: NSNonLossyASCIIStringEncoding] autorelease];
    if (![spamUniqueIdList containsObject:aUniqueId])
    {
        NSDictionary *wordList;

        wordList = [self processMessageData: aMessageData];

        if ([hamUniqueIdList containsObject:aUniqueId])
        {
            [self remove:wordList
                fromList:hamWordList];
            [hamUniqueIdList removeObject:aUniqueId];
            hamMessageCount--;
        }
        spamMessageCount++;
        [spamUniqueIdList addObject:aUniqueId];
        [self merge:wordList
           withList:spamWordList];
        
        [[NSNotificationCenter defaultCenter] postNotificationName: GINewSpamWordsInSpamFilter
                                                            object: self]; 
    }
}


-(BOOL)isMessageSpam: (NSData*) aMessageData withUniqueId:(NSString *)aUniqueId
{
    //NSDictionary *wordList;
    NSEnumerator *enumerator;
    NSString *key;

    double prob;
    // double msg_prob;
    double slotdev;
    double hitdev;
    double product;
    double invproduct;
    int wordCount;
    
    bogostat_t stats;
    discrim_t *pp;
    discrim_t *hit;

    if ([spamUniqueIdList containsObject:aUniqueId])
    {
        return YES;
    }
    if ([hamUniqueIdList containsObject:aUniqueId])
    {
        return NO;
    }

    enumerator = [GIWordEnumerator enumeratorWithTransferData: aMessageData];
    // msg_prob = ((double)spamMessageCount / (double)hamMessageCount);


    for (pp = stats.extrema; pp < stats.extrema+sizeof(stats.extrema)/sizeof(*stats.extrema); pp++)
    {
        pp->prob = 0.5f;
        pp->key = nil;
    }

    wordCount = MAX_WORDS; // use only the first MAX_WORDS words for the test (for efficiency).
    
    while ((key = [enumerator nextObject]) && wordCount--)
    {
        int hamWordCount = [[hamWordList objectForKey:key] intValue];
        int spamWordCount = [[spamWordList objectForKey:key] intValue];
        double dev;

        hamWordCount *= HAM_BIAS;
        if (hamWordCount + spamWordCount < MINIMUM_FREQ)
        {
            // prob = msg_prob;
            prob = UNKNOWN_WORD;
        }
        else
        {
            register double pSpam = min(1, ((double)spamWordCount / (double)spamMessageCount));
            register double pHam = min(1, ((double)hamWordCount / (double)hamMessageCount));
            // prob = (pSpam * msg_prob) / ((pHam * (1 - msg_prob)) + (pSpam * msg_prob));
            prob = pSpam / (pHam + pSpam);
            prob = min(prob, 0.99);
            prob = max(prob, 0.01);
        }

        // update the list of tokens with maximum deviation
        dev = DEVIATION(prob);
        hit = NULL;
        hitdev=0;

        for (pp = stats.extrema; pp < stats.extrema+sizeof(stats.extrema)/sizeof(*stats.extrema); pp++)
        {
            // don't allow duplicate tokens in the stats.extrema
            if (pp->key && [pp->key isEqualToString: key]) // compare: seems VERY expensive!
            {
                hit = NULL;
                break;
            }
            else
            {
                slotdev=DEVIATION(pp->prob);
                if (dev>slotdev && dev>hitdev)
                {
                    hit=pp;
                    hitdev=slotdev;
                }
            }
        }
        if (hit)
        {
            hit->prob = prob;
            hit->key = key;
        }
    }

    // Bayes' theorem.
    // For discussion, see <http://www.mathpages.com/home/kmath267.htm>.
    product = invproduct = 1.0f;
    for (pp = stats.extrema; pp < stats.extrema+sizeof(stats.extrema)/sizeof(*stats.extrema); pp++)
    {
        if (pp->prob != 0.0)
        {
            product *= pp->prob;
            invproduct *= (1 - pp->prob);
        }
    }
    stats.spamicity = product / (product + invproduct);
    // NSLog(@"probability of spam: %f", stats.spamicity);
    return stats.spamicity > SPAM_CUTOFF;
}

@end

@implementation GIWordEnumerator

static const BOOL* stopChars()
/*" Returns an array of size 128 of BOOLs. If stopChars()[c]==YES, c is a stop character. "*/
{
    static BOOL* _stopChars = NULL;
    if (!_stopChars) {
        unichar i;
        NSMutableCharacterSet* workingSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy];
        [workingSet formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
        [workingSet addCharactersInString:@"<>\"=@-*\\"]; // additions to set by dth
        
        _stopChars = NSZoneMalloc(nil, 128*sizeof(char));
        bzero(_stopChars,  128*sizeof(char));
        for (i=0;i<128;i++) {
            if ([workingSet characterIsMember: (unichar)i]) {
                _stopChars[i]=YES;
                //NSLog(@"StopChar '%c' found.", i);
                NSCAssert(_stopChars[i]==YES, @"failed.");
            }
        }
        NSCAssert(_stopChars[67]==NO, @"Failed");
    }
    return _stopChars;
}


- (id) initWithTransferData: (NSData*) data
{
    if (self=[super init]) {
        messageData = [data retain];
        processPointer = 0;
    }
    return self;
}

- (void) dealloc
{
    [messageData release];
    [super dealloc];
}

+ (id) enumeratorWithTransferData: (NSData*) data
{
    return [[[self alloc] initWithTransferData: data] autorelease];
}

- (id) nextObject
/*" Returns the next word as a string object. "*/
{
    unsigned char* scanchar = (unsigned char*)[messageData bytes]+processPointer;
    const unsigned char* lastchar = (const unsigned char*)scanchar-processPointer+[messageData length];
    const unsigned char* cresult;
    const BOOL* stopchar = stopChars();
    NSString* result;
    unsigned  resultLength;
    
    // Find a non-stop char:
    while (scanchar<lastchar && (*scanchar<128 && stopchar[(unsigned)*scanchar]==YES))
        scanchar++;
    cresult = scanchar; // the word starts here
    // Find a stop char:
    while (scanchar<lastchar && (*scanchar>=128 || stopchar[(unsigned)*scanchar]==NO))
        scanchar++;

    processPointer = (void*)scanchar-[messageData bytes]; // update process pointer
    result = nil;
    resultLength = (void*)scanchar-(void*)cresult;
    if (resultLength) {
        result = [NSMutableString stringWithCString: (char*)cresult length: resultLength];
        CFStringLowercase((CFMutableStringRef)result, NULL);
    }
    //NSLog(@"Scanned word '%@'.", result);
    return result;
}

@end
