//
//  GIMailAddressTokenFieldDelegate.m
//  Gina
//
//  Created by Axel Katerbau on 28.04.08.
//  Copyright 2008 Objectpark Group. All rights reserved.
//

#import "GIMailAddressTokenFieldDelegate.h"

#import <AddressBook/AddressBook.h>
#import "ABPerson+Convenience.h"
#import "NSString+Extensions.h"
#import "NSString+MessageUtils.h"
#import "GIAddressFormatter.h"

@implementation GIMailAddressTokenFieldDelegate

#define LRUCACHESIZE 100

+ (NSMutableArray *)LRUMailAddresses
{
	static NSMutableArray *LRUMailAddresses = nil;

    if (!LRUMailAddresses)
    {
        LRUMailAddresses = [[[NSUserDefaults standardUserDefaults] objectForKey:@"LRUMailAddresses"] mutableCopy];
        if (!LRUMailAddresses) LRUMailAddresses = [[NSMutableArray alloc] initWithCapacity:LRUCACHESIZE];
    }
    
    return LRUMailAddresses;
}

+ (void)addToLRUMailAddresses:(NSString *)anAddressString
{
	NSParameterAssert([NSThread currentThread] == [NSThread mainThread]);
	NSMutableArray *addresses = [self LRUMailAddresses];
	
	[addresses removeObject:anAddressString];
	
	if ([addresses count] == LRUCACHESIZE) [addresses removeObjectAtIndex:0];
	
	[addresses addObject:anAddressString];
	
	[[NSUserDefaults standardUserDefaults] setObject:addresses forKey:@"LRUMailAddresses"];
}

+ (void)removeFromLRUMailAddresses:(NSString *)anAddressString
{
	NSParameterAssert([NSThread currentThread] == [NSThread mainThread]);
	NSMutableArray *addresses = [self LRUMailAddresses];
	
	if ([addresses containsObject:anAddressString]) 
	{
		[addresses removeObject:anAddressString];
		[[NSUserDefaults standardUserDefaults] setObject:addresses forKey:@"LRUMailAddresses"];        
	}
}

- (NSArray *)tokenField:(NSTokenField *)tokenField completionsForSubstring:(NSString *)substring indexOfToken:(int)tokenIndex indexOfSelectedItem:(int *)selectedIndex
{
	NSMutableArray *result = [NSMutableArray array];
	
	// LRU cache:
	NSEnumerator *reverseEnumerator = [[[self class] LRUMailAddresses] reverseObjectEnumerator];
	NSString *cachedAddress;

	while (cachedAddress = [reverseEnumerator nextObject]) 
	{
		if ([cachedAddress hasPrefix:substring]) [result addObject:cachedAddress];
	}	
	
	NSMutableSet *candidates = [NSMutableSet set];

	// add email address candidates:
    ABSearchElement *searchElementEmailAddress = [ABPerson searchElementForProperty:kABEmailProperty label:nil key:nil value:substring comparison:kABPrefixMatchCaseInsensitive];
    
    NSArray *searchResult = [[ABAddressBook sharedAddressBook] recordsMatchingSearchElement:searchElementEmailAddress];
	
	for (id record in searchResult)
	{
        if ([record isKindOfClass:[ABPerson class]]) // only persons (not groups!) at this time
        {
            ABPerson *person = record;
            NSString *fullname = [person fullname];
            ABMultiValue *emails = [person valueForProperty:kABEmailProperty];
            int i;
            NSString *entryCandidate = nil;
            
            for (i = 0; i < [emails count]; i++) 
			{
                if ([fullname length]) 
				{
                    entryCandidate = [NSString stringWithFormat:@"%@ (%@)", [emails valueAtIndex:i], fullname];
                }
                else
                {
                    entryCandidate = [person email];
                }
                
				if ([entryCandidate compare:substring options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch range:NSMakeRange(0, substring.length)] == NSOrderedSame)
				{
					[candidates addObject:entryCandidate];
				}
            }
        }
    }
	
	// add first and last name candidates:
	NSArray *components = [substring componentsSeparatedByString:@" "];
	NSMutableArray *searchElements = [NSMutableArray array];
	
	for (NSString *component in components)
	{
		[searchElements addObject:[ABPerson searchElementForProperty:kABFirstNameProperty label:nil key:nil value:component comparison:kABPrefixMatchCaseInsensitive]];
		[searchElements addObject:[ABPerson searchElementForProperty:kABLastNameProperty label:nil key:nil value:component comparison:kABPrefixMatchCaseInsensitive]];
	}
	
	ABSearchElement *searchElementConjunction = [ABSearchElement searchElementForConjunction:kABSearchOr children:searchElements];
	
    searchResult = [[ABAddressBook sharedAddressBook] recordsMatchingSearchElement:searchElementConjunction];

	for (id record in searchResult)
	{
        if ([record isKindOfClass:[ABPerson class]]) // only persons (not groups!) at this time
        {
			static NSCharacterSet *problematicSet = nil;
			if (!problematicSet) problematicSet = [[NSCharacterSet characterSetWithCharactersInString:@"(),\""] retain];
			
			ABMultiValue *addresses = [record valueForProperty:kABEmailProperty];
			NSString *realnameA = [[NSString stringWithFormat:@"%@ %@", [record firstname], [record lastname]] stringByRemovingCharactersFromSet:problematicSet];
			NSString *realnameB = [[NSString stringWithFormat:@"%@ %@", [record lastname], [record firstname]] stringByRemovingCharactersFromSet:problematicSet];
			int i, count = [addresses count];
			
			for (i = 0; i < count; i++)
			{
				NSString *address = [addresses valueAtIndex:i];
				NSString *candidate = [realnameA stringByAppendingFormat:@" <%@>", address];
				
				if ([candidate hasPrefixCaseInsensitive:substring]) [candidates addObject:candidate];
				
				candidate = [realnameB stringByAppendingFormat:@" <%@>", address];
				
				if ([candidate hasPrefixCaseInsensitive:substring]) [candidates addObject:candidate];
			}                        
		}
    }
	
	[result addObjectsFromArray:[[candidates allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
    return [result count] ? result : nil;
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
    NSTextField *sender = [aNotification object];
    
	NSString *addressList = [sender stringValue];
	NSArray *components = [addressList componentsSeparatedByString:@","];
	
	for (NSString *component in components)
	{
		if ([[component addressFromEMailString] length])
		{
			[[self class] addToLRUMailAddresses:[component stringByRemovingSurroundingWhitespace]];
		}
	}
}

/*
 -(NSArray*) tokenField: (NSTokenField*) tokenField shouldAddObjects:(NSArray*) tokens atIndex:(unsigned)index
 {
 return [NSArray array];
 }
 */

//- (void)textViewDidChangeSelection:(NSNotification *)notification;
//{
//	NSLog(@"textViewDidChangeSelection");
//}
//
//- (NSArray *)textView:(NSTextView *)textView willChangeSelectionFromCharacterRanges:(NSArray *)oldSelectedCharRanges toCharacterRanges:(NSArray *)newSelectedCharRanges
//{
//	NSLog(@"willChangeSelectionFromCharacterRanges");
//	return nil;
//}
//
//- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRanges:(NSArray *)affectedRanges replacementStrings:(NSArray *)replacementStrings
//{
//	NSLog(@"shouldChangeTextInRanges");
//	
//	return YES;
//}

@end
