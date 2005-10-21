/*
 $Id: ABPerson+Convenience.m,v 1.2 2004/12/23 16:57:06 theisen Exp $

 Copyright (c) 2002 by Dirk Theisen and Axel Katerbau. All rights reserved.

 Permission to use, copy, modify and distribute this software and its documentation
 is hereby granted, provided that both the copyright notice and this permission
 notice appear in all copies of the software, derivative works or modified versions,
 and any portions thereof, and that both notices appear in supporting documentation,
 and that credit is given to Dirk Theisen and Axel Katerbau in all documents and publicity
 pertaining to direct or indirect use of this code or its derivatives.

 THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
 SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
 "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
 DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
 OR OF ANY DERIVATIVE WORK.

 Further information can be found on the project's web pages
 at http://www.objectpark.org/Ginko.html
 */

#import "ABPerson+Convenience.h"
#import "MPWDebug.h"

/*" The nilGuard is used below in the accessors to provide a unified return value because the AB framework does not: Empty strings can be set and retrieved but revert to nil on AB save.

:-( "*/
static inline NSString *nilGuard(NSString *str)
{
    return str ? str : @"";
}

@interface ABMultiValue (GIExtensions)
- (int)firstIndexForLabel: (NSString*) label fallback:(BOOL)fallback;
- (id)firstValueForLabel: (NSString*) label fallback:(BOOL)fallback;
@end

@implementation ABMultiValue (GIExtensions)
/*" Convenience methods. "*/

- (int)firstIndexForLabel: (NSString*) label fallback:(BOOL)fallback
{
    int count;

    count = [self count];
    
    if (count)
    {
        if (label)
        {
            int i;
            for (i = 0; i < count; i++)
            {
                if ([[self labelAtIndex:i] isEqualToString:label])
                {
                    return i;
                }
            }
        }
        if (fallback)
        {
            int result;

            result = [self indexForIdentifier:[self primaryIdentifier]];
            
            if (result == NSNotFound)
            {
                result = 0; // take the first entry found
            }
            return result;
        }
    }
    return NSNotFound;
}

- (id)firstValueForLabel: (NSString*) label fallback:(BOOL)fallback
/*" Returns the first value for the label given. If non found, the primaryValue (or otherwise the first value found) is returned if fallback is YES, nil otherwise. " */
{

    int result;

    result = [self firstIndexForLabel:label fallback:fallback];
    
    return result != NSNotFound ? [self valueAtIndex:result] : nil;
}

@end

@implementation ABPerson (Convenience)
/*" Some convenience methods for ABPerson. "*/

+ (NSArray*) personsWithContentsFromVCardFile: (NSString*) filename
/*" Returns an array containing %{ABPerson} objects that could be read out of the file with the given filename. If no %{ABPerson} object could be read an empty array is returned. "*/
{
    NSMutableArray *result;
    NSString *vcardString;
    NSData *data;
    int position = 0, length;
    
    result = [NSMutableArray array];

    data = [NSData dataWithContentsOfFile:filename];

    // The following is a complete fuck-up because of the poor definition made in the RFC.
    // First ISO Latin1 encoding is tried.
    // If this fails *shudder* Unicode UTF16 encoding is being tried.
    vcardString = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    length = [vcardString length];

    if ([vcardString rangeOfString: @"END:VCARD" options:NSCaseInsensitiveSearch].location == NSNotFound)
    {
        // try UTF16
        vcardString = [[NSString alloc] initWithData:data encoding:NSUnicodeStringEncoding];
        length = [vcardString length];
    }

    // Hopefully the vCard data could be decoded the right way.
    //MPWDebugLog(@"vcardString = %@", vcardString);

    while (position < length)
    {
        NSRange searchRange, foundRange;
        NSString *vcard;
        NSData *personData;
        ABPerson *person;
        NSAutoreleasePool *pool;

        pool = [[NSAutoreleasePool alloc] init];
        searchRange = NSMakeRange(position, length - position);
        foundRange = [vcardString rangeOfString: @"END:VCARD" options:NSCaseInsensitiveSearch range:searchRange];

        if (foundRange.location == NSNotFound)
        {
            [pool release];
            break;
        }

        vcard = [vcardString substringWithRange:NSMakeRange(position, NSMaxRange(foundRange) - position)];

        //MPWDebugLog(@"vcard = %@", vcard);
        
        personData = [vcard dataUsingEncoding:NSUnicodeStringEncoding];
        person = [[ABPerson alloc] initWithVCardRepresentation:personData];
        [result addObject:person];
        [person release];
        
        position = NSMaxRange(foundRange);
        [pool release];
    }
    
    [vcardString release];

    //MPWDebugLog(@"ABPersons = %@", result);
    
    return result;
}

- (NSString*) firstname
/*" Returns the first name of the receiver. Returns at least an empty string (never nil). "*/
{
    return nilGuard([self valueForProperty:kABFirstNameProperty]);
}

- (NSString*) lastname
/*" Returns the last name of the receiver. Returns at least an empty string (never nil). "*/
{
    return nilGuard([self valueForProperty:kABLastNameProperty]);
}

- (NSString*) fullname
/*" Returns the formatted full name of a person including the honorprefix. Returns an empty string otherwise. "*/
{
    NSString *next;
    NSMutableString *formatted = [NSMutableString string];

    if ([next = [self lastname] length])
    {
        [formatted appendString:next];

        if ([next = [self firstname] length])
        {
            [formatted insertString: @" " atIndex:0];
            [formatted insertString:next atIndex:0];
        }
        if ([next = [self honorprefix] length])
        {
            [formatted insertString: @" " atIndex:0];
            [formatted insertString:next atIndex:0];
        }
        if ([next = [self honorpostfix] length])
        {
            [formatted appendString: @", "];
            [formatted appendString:next];
        }
    }
    return formatted;
}

- (NSString*) honorprefix
/*" Returns the honor prefix of the receiver. Returns at least an empty string (never nil). "*/
{
    return nilGuard([self valueForProperty: @"Title"]);
}

- (NSString*) honorpostfix
/*" Returns the honor postfix of the receiver. Returns at least an empty string (never nil). "*/
{
    return nilGuard([self valueForProperty:kABSuffixProperty]);
}

- (NSString*) email
/*" Returns the email of the receiver. The work email address is preferred over the home email address. Returns at least an empty string (never nil). "*/
{
    return [[self valueForProperty:kABEmailProperty] firstValueForLabel:kABWorkLabel fallback: YES];
}

@end
