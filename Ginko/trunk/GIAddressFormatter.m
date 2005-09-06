/* 
     $Id: GIAddressFormatter.m,v 1.2 2004/12/23 16:57:06 theisen Exp $

     Copyright (c) 2001 by Axel Katerbau. All rights reserved.

     Permission to use, copy, modify and distribute this software and its documentation
     is hereby granted, provided that both the copyright notice and this permission
     notice appear in all copies of the software, derivative works or modified versions,
     and any portions thereof, and that both notices appear in supporting documentation,
     and that credit is given to Axel Katerbau in all documents and publicity
     pertaining to direct or indirect use of this code or its derivatives.

     THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
     SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
     "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
     DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
     OR OF ANY DERIVATIVE WORK.

     Further information can be found on the project's web pages
     at http://www.objectpark.org/Ginko.html
*/

#import "GIAddressFormatter.h"
#import <AddressBook/AddressBook.h>
#import "ABPerson+Convenience.h"
#import "NSString+Extensions.h"
#import "MPWDebug.h"

@implementation GIAddressFormatter
/*"
Should match the following formats:

 email@address.org (firstname lastname)
 
 firstname lastname <email@address.org>

 lastname, firstname <email@address.org> 
"*/
- (NSString *)stringForObjectValue:(id)obj
{
    return [obj description];
}

- (NSAttributedString *)attributedStringForObjectValue:(id)obj withDefaultAttributes:(NSDictionary *)attrs
{
    return [[[NSAttributedString alloc] initWithString:[obj description]] autorelease];
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString **)error
{
    *obj = string;
    return YES;
}

- (BOOL)isPartialStringValid:(NSString **)partialStringPtr proposedSelectedRange:(NSRangePointer)proposedSelRangePtr originalString:(NSString *)origString originalSelectedRange:(NSRange)origSelRange errorDescription:(NSString **)error
{   
    static NSCharacterSet *separatorSet = nil;
        
    if (! separatorSet) separatorSet = [[NSCharacterSet characterSetWithCharactersInString:@" ,;\r\n"] retain];
    
    // check whether completion should happen
    if ( 
        (NSMaxRange(origSelRange) == [origString length]) // either all chars follwing the 
                                                          // selection/insertion point are 
                                                          // selected or no chars follow the
                                                          // selection/insertion point
        && ((*proposedSelRangePtr).location > origSelRange.location) // insertion point moved forward
        ) // do completion
    {
        NSString *completionPrefix;
        NSRange prefixRange;
//        NSEnumerator *enumerator;
        
        // test if comma was typed in
        if ([*partialStringPtr hasSuffix:@","]) // comma found
        {
            *partialStringPtr = [origString stringByAppendingString:@", "];
            *proposedSelRangePtr = NSMakeRange([*partialStringPtr length], 0);
                        
            return NO;
        }
        
        prefixRange = [*partialStringPtr rangeOfCharacterFromSet:separatorSet options:NSBackwardsSearch range:NSMakeRange(0, (*proposedSelRangePtr).location)];
        
        if (prefixRange.location != NSNotFound)
        {
            completionPrefix = [*partialStringPtr substringFromIndex:prefixRange.location + 1];
        }
        else
        {
            completionPrefix = *partialStringPtr;
        }
        
        if ([completionPrefix length])
        {
            static NSMutableArray *candidates = nil;
            static char cycleChar = '+'; // +
            static NSString *cycleSuffix = nil;
            static int nextIndex = 0;
            
            if (!cycleSuffix) cycleSuffix = [[NSString alloc] initWithFormat:@"%c", cycleChar];
            
            if ([completionPrefix hasSuffix:cycleSuffix])
            {                
                completionPrefix = [completionPrefix substringToIndex:[completionPrefix length] - 1];
                *partialStringPtr = [*partialStringPtr substringToIndex:[*partialStringPtr length] - 1];
                *proposedSelRangePtr = NSMakeRange(proposedSelRangePtr->location - 1, ([*partialStringPtr length] - proposedSelRangePtr->location) - 1);
                
                if ([candidates count] < 2) // nothing to cycle
                {
                    NSBeep();
                }
                else
                {
                    nextIndex += 1;
                    if (nextIndex >= [candidates count]) nextIndex = 0;
                    
                    NSString *restString = [[candidates objectAtIndex:nextIndex] substringFromIndex:[completionPrefix length]];
                    
                    if (NSDebugEnabled) NSLog(@"Found match with: %@", [candidates objectAtIndex:nextIndex]);
                    *partialStringPtr = [*partialStringPtr stringByAppendingString:restString];
                    *proposedSelRangePtr = NSMakeRange(proposedSelRangePtr->location, [*partialStringPtr length] - proposedSelRangePtr->location);
                    
                    return NO;
                }
            }
            
            prefixRange = NSMakeRange(0, [completionPrefix length]);
            
            if (NSDebugEnabled) NSLog(@"completion with prefix: '%@'", completionPrefix);
    
            // reset candidates
            if (candidates) [candidates release];
            candidates = [[NSMutableArray alloc] init];
            
            // try to find match
            /*
            enumerator = [[[GIMessageCenter defaultMessageCenter] LRUMailAddresses] objectEnumerator];
            while (address = [enumerator nextObject])
            {
                if ([address compare:completionPrefix options:NSCaseInsensitiveSearch range:prefixRange] == NSOrderedSame)
                {
                    NSString *restString;
                    
                    restString = [address substringFromIndex:[completionPrefix length]];
                    
                    if (NSDebugEnabled) NSLog(@"Found match with: %@", address);
                    *partialStringPtr = [*partialStringPtr stringByAppendingString:restString];
                    *proposedSelRangePtr = NSMakeRange(proposedSelRangePtr->location, [*partialStringPtr length] - proposedSelRangePtr->location);

                    return NO;
                }
            }
             */
            
            // try address book
            {
                ABSearchElement *searchElementEmailAddress, *searchElementFirstname, *searchElementLastname;
                NSEnumerator *enumerator;
                NSArray *searchResult;
                id record;
                
                searchElementEmailAddress = [ABPerson searchElementForProperty:kABEmailProperty label:nil key:nil value:completionPrefix comparison:kABPrefixMatchCaseInsensitive];
//                searchElementFirstname = [ABPerson searchElementForProperty:kABFirstNameProperty label:nil key:nil value:completionPrefix comparison:kABPrefixMatchCaseInsensitive];
//                searchElementLastname = [ABPerson searchElementForProperty:kABLastNameProperty label:nil key:nil value:completionPrefix comparison:kABPrefixMatchCaseInsensitive];
                    
//                ABSearchElement *conjunction = [ABSearchElement searchElementForConjunction:kABSearchOr children:[NSArray arrayWithObjects:searchElementEmailAddress, searchElementFirstname, searchElementLastname, nil]];
                
                searchResult = [[ABAddressBook sharedAddressBook] recordsMatchingSearchElement:searchElementEmailAddress];

                enumerator = [searchResult objectEnumerator];
                while (record = [enumerator nextObject])
                {
                    if ([record isKindOfClass:[ABPerson class]])
                    {
                        static NSCharacterSet *problematicSet = nil;
                        if (!problematicSet) problematicSet = [[NSCharacterSet characterSetWithCharactersInString:@"(),\""] retain];
                        
                        ABMultiValue *addresses = [record valueForProperty:kABEmailProperty];
                        NSString *fullname = [[record fullname] stringByRemovingCharactersFromSet:problematicSet];
                        NSString *realname = [fullname length] ? [NSString stringWithFormat:@" (%@)", fullname] : @"";
                        int i, count = [addresses count];
                        
                        for (i = 0; i < count; i++)
                        {
                            NSString *address = [addresses valueAtIndex:i];
                            if ([address hasPrefix:completionPrefix])
                            {
                                [candidates addObject:[address stringByAppendingString:realname]];
                            }
                        }                        
                    }
                }
            }
            
            // return first match:
            if ([candidates count])
            {
                NSString *restString = [[candidates objectAtIndex:0] substringFromIndex:[completionPrefix length]];
                
                if (NSDebugEnabled) NSLog(@"Found match with: %@", [candidates objectAtIndex:0]);
                *partialStringPtr = [*partialStringPtr stringByAppendingString:restString];
                *proposedSelRangePtr = NSMakeRange(proposedSelRangePtr->location, [*partialStringPtr length] - proposedSelRangePtr->location);
                
                nextIndex = 1;
                return NO;
            }
        }
    }
    else
    {
        if (NSDebugEnabled) NSLog(@"no completion");
    }
    
    return YES;
/*
    NSRange range;
    NSLog(@"isPartialStringValid: partial = (%@), orig = (%@)", *partialStringPtr, origString);
    *partialStringPtr = [NSString stringWithFormat:@"%@%@", *partialStringPtr, @"PARTIAL"];
    range = NSMakeRange(proposedSelRangePtr->location, [*partialStringPtr length] - proposedSelRangePtr->location);
    *proposedSelRangePtr = range;
    return NO;
    */
}

@end
