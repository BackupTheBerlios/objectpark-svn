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

// TODO: take LRU addresses into account
// TODO: match also first and last name

@implementation GIMailAddressTokenFieldDelegate

- (NSArray *)tokenField:(NSTokenField *)tokenField completionsForSubstring:(NSString *) substring indexOfToken:(int)tokenIndex indexOfSelectedItem:(int *)selectedIndex
{
	NSMutableSet *candidates = [NSMutableSet set];
	
    ABSearchElement *searchElementEmailAddress = [ABPerson searchElementForProperty:kABEmailProperty label: nil key:nil value:substring comparison:kABPrefixMatchCaseInsensitive];
    //ABSearchElement* searchElementFirstname = [ABPerson searchElementForProperty:kABFirstNameProperty label: nil key:nil value:substring comparison:kABPrefixMatchCaseInsensitive];
    //ABSearchElement* searchElementLastname = [ABPerson searchElementForProperty:kABLastNameProperty label: nil key:nil value:substring comparison:kABPrefixMatchCaseInsensitive];
    
    NSArray *searchResult = [[ABAddressBook sharedAddressBook] recordsMatchingSearchElement:searchElementEmailAddress];
	
    NSEnumerator *enumerator = [searchResult objectEnumerator];
	id record;
    while (record = [enumerator nextObject]) 
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
				
                //if ([entryCandidate hasPrefix:substring]) [candidates addObject:entryCandidate];
            }
        }
    }
	
    NSMutableArray *result = (id)[[candidates allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    return [result count] ? result : nil;
}

/*
 -(NSArray*) tokenField: (NSTokenField*) tokenField shouldAddObjects:(NSArray*) tokens atIndex:(unsigned)index
 {
 return [NSArray array];
 }
 */

@end
