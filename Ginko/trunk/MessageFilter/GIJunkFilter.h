/*
 $Id: GIJunkFilter.h,v 1.1 2005/04/14 17:28:13 theisen Exp $

 Copyright (c) 2001, 2002 by Björn Bubbat. All rights reserved.

 Permission to use, copy, modify and distribute this software and its documentation
 is hereby granted, provided that both the copyright notice and this permission
 notice appear in all copies of the software, derivative works or modified versions,
 and any portions thereof, and that both notices appear in supporting documentation,
 and that credit is given to Björn Bubbat in all documents and publicity
 pertaining to direct or indirect use of this code or its derivatives.

 THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
 SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
 "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
 DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
 OR OF ANY DERIVATIVE WORK.

 Further information can be found on the project's web pages
 at http://www.objectpark.org/Ginko.html
 */

#import <Foundation/Foundation.h>

// Notification names:
extern NSString* GINewHamWordsInSpamFilter;
extern NSString* GINewSpamWordsInSpamFilter;
extern NSString* GIJunkFilterSpamThreshold;

@interface GIJunkFilter : NSObject {
    
    NSMutableDictionary* hamWordList;
    NSMutableDictionary* spamWordList;
    NSMutableArray *hamUniqueIdList; // deprecated 
    NSMutableArray *spamUniqueIdList; // deprecated
    unsigned spamMessageCount; // The number of spam messages trained
    unsigned hamMessageCount; // The number of ham messages trained
	float spamThreshold;
	BOOL didChange; // YES, if the ham or spam word list changed.
}

+ (void) addWordsFromString: (NSString*) string 
				 withPrefix: (NSString*) prefix
					toArray: (NSMutableArray*) words;

+ (GIJunkFilter*) sharedInstance;
- (void) writeJunkFilterDefintion;

- (id) init;

- (id) initWithPlist: (NSDictionary*) dict;
- (NSDictionary*) plist;


- (BOOL) optimize;

- (void) registerHamWords: (NSEnumerator*) wordEnumerator
			 withUniqueId: (NSString*) aUniqueId;

- (void) registerSpamWords: (NSEnumerator*) wordEnumerator
			  withUniqueId: (NSString*) aUniqueId;

//- (BOOL) isSpamMessage: (NSData*) aMessageData withUniqueId: (NSString*) aUniqueId; // deprecated

- (BOOL) isSpamMessage: (NSEnumerator*) wordEnumerator;


@end
