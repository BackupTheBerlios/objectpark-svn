//
//  TestOPAppleDoubleContentCoder.m
//  Gina
//
//  Created by Axel Katerbau on 13.04.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "TestOPAppleDoubleContentCoder.h"
#import "OPAppleDoubleContentCoder.h"
#import "NSFileWrapper+OPApplefileExtensions.h"

@implementation TestOPAppleDoubleContentCoder


- (void) testCoding 
{
	NSFileWrapper *wrapper, *wrapper1;
	OPAppleDoubleContentCoder *coder;
	NSAttributedString *attString, *attString1;
	
	wrapper = [[[NSFileWrapper alloc] initWithPath: @"/System/Library/Fonts/Helvetica LT MM" 
								forksAndFinderInfo: YES] autorelease];
	
		
	
	coder = [[[OPAppleDoubleContentCoder alloc] initWithFileWrapper: wrapper] autorelease];
	
		
	wrapper1 = [coder fileWrapper];
	 
    NSAssert([[wrapper regularFileContents] isEqual: [wrapper1 regularFileContents]], @"not equal");
    NSAssert([[wrapper resourceForkContents] isEqual: [wrapper1 resourceForkContents]], @"not equal");
    NSAssert([[wrapper finderInfo] isEqual: [wrapper1 finderInfo]], @"not equal");

	attString = [coder attributedString];
	
	coder = [[[OPAppleDoubleContentCoder alloc] initWithAttributedString: attString] autorelease];
	
	attString1 = [coder attributedString];
	
	NSAssert([[attString string] isEqual: [attString1 string]], @"not equal");
	 
}

@end
