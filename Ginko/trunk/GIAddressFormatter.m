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
#import "MPWDebug.h"

@implementation GIAddressFormatter

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
    static NSCharacterSet *separatorSet;
    
    if (! separatorSet)
    {
        separatorSet = [[NSCharacterSet characterSetWithCharactersInString:@" ,;\r\n"] retain];
    }
    
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
        NSString *address;
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
            prefixRange = NSMakeRange(0, [completionPrefix length]);
            
            if (NSDebugEnabled) NSLog(@"completion with prefix: '%@'", completionPrefix);
    
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
                ABSearchElement *searchElement;
                NSEnumerator *enumerator;
                NSArray *searchResult;
                id record;
                
                searchElement = [ABPerson searchElementForProperty:kABEmailProperty label:nil key:nil value:completionPrefix comparison:kABPrefixMatchCaseInsensitive];

                searchResult = [[ABAddressBook sharedAddressBook] recordsMatchingSearchElement:searchElement];

                enumerator = [searchResult objectEnumerator];
                while (record = [enumerator nextObject])
                {
                    if ([record isKindOfClass:[ABPerson class]])
                    {
                        address = [(ABPerson *)record email];
                        if ([address length])
                        {
                            NSString *restString;

                            restString = [address substringFromIndex:[completionPrefix length]];

                            if (NSDebugEnabled) NSLog(@"Found match with: %@", address);
                            *partialStringPtr = [*partialStringPtr stringByAppendingString:restString];
                            *proposedSelRangePtr = NSMakeRange(proposedSelRangePtr->location, [*partialStringPtr length] - proposedSelRangePtr->location);

                            return NO;
                        }
                    }
                }
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
