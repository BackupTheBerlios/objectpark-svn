//
//  NSString+OPHTMLTools.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 30.06.06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "NSString+OPHTMLTools.h"

#include <string.h>
#include <libxml/xmlmemory.h>
#include <libxml/HTMLparser.h>

@implementation NSString (OPHTMLTools)

static void charactersParsed(void* context, const xmlChar * ch, int len)
	/*" Callback function for stringByStrippingHTML. "*/
{
		NSMutableString* result = context;
		
		NSString* parsedString;
		parsedString = [[NSString alloc] initWithBytesNoCopy: (xmlChar*) ch
													  length: len 
													encoding: NSUTF8StringEncoding 
												freeWhenDone: NO];
		[result appendString: parsedString];
		[parsedString release];
}


- (NSString*) stringByStrippingHTML
	/*" interpretes the receiver als HTML and removes all tags and converts it to plain text. "*/
{
	int mem_base = xmlMemBlocks();
	
	NSMutableString* result = [NSMutableString string];
	xmlSAXHandler handler; bzero(&handler, sizeof(xmlSAXHandler)); // null structure
	handler.characters = &charactersParsed;
	
	htmlSAXParseDoc((xmlChar*)[self UTF8String], "utf-8", &handler, result);
	
	if (mem_base != xmlMemBlocks()) {
		printf("Leak of %d blocks found in htmlSAXParseDoc",
	           xmlMemBlocks() - mem_base);
	}
	
	return result;
}


@end
