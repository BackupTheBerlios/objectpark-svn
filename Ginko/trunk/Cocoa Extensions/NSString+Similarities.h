//
//  NSString+Similarities.m
//  GinkoVoyager
//
//  Created by Rick Bourner <rick@bourner.com> on Sat Aug 09 2003.
//  Improved by Dirk Theisen on 14.02.06.
//  Copyright 2006 by the authors. All rights reserved.
//
//

#import <Foundation/Foundation.h>

@interface NSString(Levenshtein)

// calculate the smallest distance between all words in stringA and  stringB
- (float) compareWithString: (NSString *) stringB;

	// calculate the distance between two string treating them each as a
	// single word
- (float) compareWithWord: (NSString *) stringB;


@end