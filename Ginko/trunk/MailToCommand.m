//
//  MailToCommand.m
//  Ginko
//
//  Created by Axel Katerbau on Sat Jul 27 2002.
//  Copyright (c) 2002 Objectpark Group. All rights reserved.
//

#import "MailToCommand.h"
#include <CoreFoundation/CFURL.h>
#import "GIMessageEditorController.h"

@implementation MailToCommand
/*" Script Command for handling "mailto:" URLs.

Could evolve to GURLCommand eventually to handle additional URL types like "news:" etc. "*/

- (NSDictionary *)_componentsFromURL:(NSString *)anURL
/*" Extracts the different components from the given anURL into a dictionary with the parameter names being the keys and the values the object values. "*/
{
    NSArray *components;
    NSMutableDictionary *result;
    NSEnumerator *enumerator;
    NSString *component;
    
    result = [NSMutableDictionary dictionary];
    components = [anURL componentsSeparatedByString:@"?"];
    enumerator = [components objectEnumerator];

    // special handling of the first (e.g. implicit) parameter
    if (component = [enumerator nextObject]) 
    {
        // cutting of the URL type if given
        NSRange colonRange = [component rangeOfString:@":"];
        if ((colonRange.location != NSNotFound) && ([component length] > colonRange.location + 1))
        {
            component = [component substringFromIndex:colonRange.location + 1];
        }

        // decoding percent escapes
        component = (NSString *)CFURLCreateStringByReplacingPercentEscapes(NULL, (CFStringRef)component, CFSTR(""));

        // adding mailto: specific "to" to the dictionary
        // when supporting different kinds of URLs this must change
        [result setObject:component forKey:@"to"];
    }

	NSString *additionalParameters = [[enumerator allObjects] componentsJoinedByString:@"?"];
	enumerator = [[additionalParameters componentsSeparatedByString:@"&"] objectEnumerator];
	
    // handling of additional/optional "regular" parameters
    while (component = [enumerator nextObject])
    {
        NSArray *innerComponents;
        NSEnumerator *innerEnumerator;
        NSMutableString *value;
        NSString *key;
        NSString *innerComponent;
        
        value = [NSMutableString string];
        
        innerComponents = [component componentsSeparatedByString:@"="];
        innerEnumerator = [innerComponents objectEnumerator];

        // getting the parameter's name/key
        if (key = [innerEnumerator nextObject]) 
        {
            key = (NSString *)CFURLCreateStringByReplacingPercentEscapes(NULL, (CFStringRef)key, CFSTR(""));
            key = [key lowercaseString];
        }

        // getting the parameter's value/object value
        while (innerComponent = [innerEnumerator nextObject])
        {
            [value appendString:(NSString *)CFURLCreateStringByReplacingPercentEscapes(NULL, (CFStringRef)innerComponent, CFSTR(""))];
        }
        [result setObject:value forKey:key];
    }
    
    return result;
}

- (id)performDefaultImplementation
/*" Overridden from %{NSScriptCommand}. The receiver interprets the given URL (which is passed as a "direct parameter"). Only "mailto:" URLs are supported at this time. "*/
{
    NSLog(@"performDefaultImplementation %@", [self _componentsFromURL:[self directParameter]]);
	[[[GIMessageEditorController alloc] initNewMessageWithMailToDictionary:[self _componentsFromURL:[self directParameter]]] autorelease];
//    [[GIMessageEditorManager sharedMessageEditorManager] newMessageWithMailToDictionary:[self _componentsFromURL:[self directParameter]]];
    return nil;
}

@end
