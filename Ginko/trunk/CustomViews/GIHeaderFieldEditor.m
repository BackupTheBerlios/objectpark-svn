/*
 $Id: GIHeaderFieldEditor.m,v 1.3 2002/12/28 09:54:39 mikesch Exp $

 Copyright (c) 2002 by Axel Katerbau. All rights reserved.

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

#import "GIHeaderFieldEditor.h"
#import "NSPasteboard+OPExtendedFileTypeMatching.h"
#import "ABPerson+Convenience.h"

#define ABPeopleUIDsPboardType @"ABPeopleUIDsPboardType"

@implementation GIHeaderFieldEditor
/*" Adds support for vCard file dropping. "*/

- (NSArray *)readablePasteboardTypes
/*" Adds the NSFilenamesPboardType to grok vcf files. "*/
{
    return [[super readablePasteboardTypes] arrayByAddingObject:NSFilenamesPboardType];
}

- (void)_addPersons:(NSArray *)somePersons
/*" Adds the realnames and the email addresses at the end of the input line of all %{ABPerson} objects contained in the array somePersons. "*/
{
    NSEnumerator *enumerator;
    ABPerson *person;
    NSMutableArray *completePersonAddresses;

    completePersonAddresses = [NSMutableArray array];
    
    enumerator = [somePersons objectEnumerator];
    while (person = [enumerator nextObject])
    {
        NSString *fullname;
        NSString *email;
        NSMutableString *addressString;
        
        fullname = [person fullname];
        email = [person email];
        addressString = [NSMutableString string];
        
        if ([email length])
        {
            if ([fullname length])
            {
                [addressString appendString:@"\""];
                [addressString appendString:fullname];
                [addressString appendString:@"\""];
            }

            [addressString appendString:@" <"];
            [addressString appendString:email];
            [addressString appendString:@">"];

            [completePersonAddresses addObject:addressString];
        }
    }

    if ([completePersonAddresses count])
    {
        NSString *stringToInsert;
        int length;

        length = [[self textStorage] length];
        stringToInsert = [completePersonAddresses componentsJoinedByString:@", "];
        if (length)
        {
            stringToInsert = [NSString stringWithFormat:@", %@", stringToInsert];
            [self setSelectedRange:NSMakeRange(length, 0)];
        }
        [self insertText:stringToInsert];
        length = [[self textStorage] length];
        //[self setMarkedRange:NSMakeRange(length - [stringToInsert length], [stringToInsert length])];
        [self setNeedsDisplay:YES];
    }
}

- (BOOL)readSelectionFromPasteboard:(NSPasteboard *)pboard type:(NSString *)type
/*" Handles vcf files. "*/
{
    
    NSLog(@"pasteboard types = %@", [pboard types]);
    
    if ([type isEqualToString:NSFilenamesPboardType])
    {
        NSArray *vcfs;
        
        vcfs = [pboard filenamesOfType:@"vcf"];
        
        if ([vcfs count])
        {
            NSEnumerator *enumerator;
            NSString *vcf;
            NSMutableArray *persons;
            NSAutoreleasePool *pool;

            pool = [[NSAutoreleasePool alloc] init];
            persons = [NSMutableArray array];
            
            enumerator = [vcfs objectEnumerator];
            while (vcf = [enumerator nextObject])
            {
                [persons addObjectsFromArray:[ABPerson personsWithContentsFromVCardFile:vcf]];
            }

            [self _addPersons:persons];
            
            [pool release];
            return YES;
        }
        else
        {
            NSBeep();
            return NO;
        }
    }
    return [super readSelectionFromPasteboard:pboard type:type];
}

#define TAB ((char)'\x09')

- (void)keyDown:(NSEvent *)theEvent
/*" Enables the use of the tab key for moving to next/previous key view. "*/
{
    NSString *characters;
    unichar firstChar;
    int modifierFlags;
    id delegate = [self delegate];

    modifierFlags = [theEvent modifierFlags];
    characters = [theEvent characters];
    firstChar = [characters characterAtIndex:0];

    switch (firstChar)
    {
        case TAB:
            if(modifierFlags & NSShiftKeyMask)
            {
                if ([delegate respondsToSelector:@selector(selectPreviousKeyView:)])
                {
                    [delegate selectPreviousKeyView:self];
                    return;
                }
                else
                {
                    [[self window] selectPreviousKeyView:self];
                    return;
                }
            }
            else
            {
                if ([delegate respondsToSelector:@selector(selectNextKeyView:)])
                {
                    [delegate selectNextKeyView:self];
                    return;
                }
                else
                {
                    [[self window] selectNextKeyView:self];
                    break;
                }
            }
        default:
            [super keyDown:theEvent];
            break;
    }
}

/*
- (unsigned int) draggingEntered: (id <NSDraggingInfo>) sender
{
    NSLog(@"dragged types = %@", [[sender draggingPasteboard] types]);
    return [super draggingEntered: sender];
}
*/

@end
