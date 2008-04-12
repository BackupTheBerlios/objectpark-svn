//
//  NSString+OPHTMLTools.m
//  Gina
//
//  Created by Dirk Theisen on 30.06.06.
//  Copyright 2006 Objectpark Group. All rights reserved.
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

/* GCS: custom error function to ignore errors */
static void structuredError(void * userData,
							xmlErrorPtr error)
{
	/* ignore all errors */
	(void)userData;
	(void)error;
}

- (NSString*) stringByStrippingHTML
	/*" interpretes the receiver als HTML and removes all tags and converts it to plain text. "*/
{
	if (! [self length]) return self;
	
	int mem_base = xmlMemBlocks();
	NSMutableString* result = [NSMutableString string];
	xmlSAXHandler handler; bzero(&handler,
								 sizeof(xmlSAXHandler));
	handler.characters = &charactersParsed;
	
	/* GCS: override structuredErrorFunc to mine so
	 I can ignore errors */
	xmlSetStructuredErrorFunc(xmlGenericErrorContext,
							  &structuredError);
	
	htmlSAXParseDoc((xmlChar*)[self UTF8String], "utf-8",
					&handler, result);
    
	if (mem_base != xmlMemBlocks()) {
		NSLog( @"Leak of %d blocks found in htmlSAXParseDoc",
			  xmlMemBlocks() - mem_base);
	}
	return result;
}


@end
