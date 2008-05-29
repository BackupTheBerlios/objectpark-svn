/* 
     $Id: OPMultipartContentCoder.m,v 1.4 2005/04/20 21:49:58 theisen Exp $

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
*/

#import "OPMultipartContentCoder.h"
#import "EDMessagePart+OPExtensions.h"
#import "NSAttributedString+Extensions.h"
#import "NSString+Extensions.h"
#import "NSArray+Extensions.h"

// ##WARNING axel->all: Only decoding for now. Encoding is always multipart/mixed!

/*
    Future direction for multipart de-/encoding: 
    Moving to distinct decoder classes for the different multipart subtypes.
    That said this class as is obviously a legacy.
*/

@interface EDCompositeContentCoder(PrivateAPI)
- (void)_takeSubpartsFromMultipartContent:(EDMessagePart *)mpart;
- (void)_takeSubpartsFromMessageContent:(EDMessagePart *)mpart;
- (id)_encodeSubpartsWithClass:(Class)targetClass;
@end

@interface OPMultipartContentCoder (PrivateAPI)

- (id)_contentFromMultipartAlternativeWithPreferredContentTypes:(NSArray *)preferredContentTypes attributed:(BOOL)shouldBeAttributed;
- (id)_contentFromMultipartMixedWithPreferredContentTypes:(NSArray *)preferredContentTypes attributed:(BOOL)shouldBeAttributed;
- (id)_contentFromMultipartSignedWithPreferredContentTypes:(NSArray *)preferredContentTypes attributed:(BOOL)shouldBeAttributed;
//- (NSAttributedString *)_attributedStringFromMultipartRelatedWithPreferredContentTypes:(NSArray*) preferredContentTypes;
//- (NSAttributedString *)_attributedStringFromMultipartReportWithPreferredContentTypes:(NSArray*) preferredContentTypes;

@end

@implementation OPMultipartContentCoder
/*" Adds to EDCompositeContentCoder the ability to deal with different multipart subtypes. "*/

- (id)initWithMessagePart:(EDMessagePart *)mpart
{
    if (self = [super initWithMessagePart:mpart]) 
    {
        subtype = [[[[[mpart contentType] componentsSeparatedByString:@"/"] lastObject] stringByRemovingSurroundingWhitespace] retain];
    }
    return self;
}

- (void)dealloc
{
    [subtype release];
    [super dealloc];
}

- (NSString *)subtype
{
    return subtype;
}

- (NSAttributedString *)attributedString
{
    return [self contentWithPreferredContentTypes:nil attributed:YES];
}

- (NSString *)string
{
    return [self contentWithPreferredContentTypes:nil attributed:NO];
}

- (id)contentWithPreferredContentTypes:(NSArray *)preferredContentTypes attributed:(BOOL)shouldBeAttributed
{
    if ([subtype caseInsensitiveCompare:@"alternative"] == NSOrderedSame)
        return [self _contentFromMultipartAlternativeWithPreferredContentTypes:preferredContentTypes attributed:shouldBeAttributed];
    else if ([subtype caseInsensitiveCompare:@"mixed"] == NSOrderedSame)
        return [self _contentFromMultipartMixedWithPreferredContentTypes:preferredContentTypes attributed:shouldBeAttributed];
	else if ([subtype caseInsensitiveCompare:@"signed"] == NSOrderedSame)
        return [self _contentFromMultipartSignedWithPreferredContentTypes:preferredContentTypes attributed:shouldBeAttributed];

/*    else if ([subtype caseInsensitiveCompare:@"related"] == NSOrderedSame)
        return [self _attributedStringFromMultipartRelatedWithPreferredContentTypes:preferredContentTypes];
    else if ([subtype caseInsensitiveCompare:@"report"] == NSOrderedSame)
        return [self _attributedStringFromMultipartReportWithPreferredContentTypes:preferredContentTypes];
*/    
    
    id result = [NSString stringWithFormat:@"multipart/%@ not yet decodable. Fallback to multipart/mixed handling\n", subtype];
    
    if (shouldBeAttributed) 
    {
        result = [[[NSMutableAttributedString alloc] initWithString:result] autorelease];
    
        [result appendAttributedString:[self _contentFromMultipartMixedWithPreferredContentTypes:preferredContentTypes attributed:YES]];
    }
    else
    {
        result = [result stringByAppendingString:[self _contentFromMultipartMixedWithPreferredContentTypes:preferredContentTypes attributed:NO]];
    }
    
    return result;
}

- (EDMessagePart *)mostPreferredSubpartWithPreferredContentTypes:(NSArray *)preferredContentTypes
{
    EDMessagePart *subpart;
    EDMessagePart *result = nil;
    
    NSMutableArray *alternativeContentTypes = [[NSMutableArray allocWithZone:[self zone]] init];
    NSMutableArray *alternativeSubparts = [[NSMutableArray allocWithZone:[self zone]] init];
    
    // reverse order (the most rich content type should be the first after that)
    // filter out the alternatives for which no decoder class can be found
    NSEnumerator *enumerator = [[self subparts] reverseObjectEnumerator];
    while (subpart = [enumerator nextObject]) 
    {
        if ([EDContentCoder contentDecoderClass: subpart] != nil) 
        {
            NSString *aContentType = [[subpart contentType] lowercaseString];
            
            if (aContentType) 
            {
                [alternativeContentTypes addObject:aContentType];
                [alternativeSubparts addObject:subpart];
            }
        }
    }
    
    if ([alternativeContentTypes count] == 0) // don't return empty array
    {
        [alternativeContentTypes release];
        [alternativeSubparts release];
		
        return nil;
    }
    
    // sort array after user preference
    
    if (preferredContentTypes) 
    {
        NSString *anDefault;
        enumerator = [preferredContentTypes reverseObjectEnumerator];
        
        while (anDefault = [enumerator nextObject]) 
        {
            NSString *comparand = [anDefault lowercaseString];
            int index = [alternativeContentTypes indexOfObject:comparand];
            
            if (index != NSNotFound)
            {
                // move to first position
                [alternativeContentTypes insertObject:[alternativeContentTypes objectAtIndex:index] atIndex:0];
                [alternativeSubparts insertObject:[alternativeSubparts objectAtIndex:index] atIndex:0];
                
                [alternativeContentTypes removeObjectAtIndex:index + 1];
                [alternativeSubparts removeObjectAtIndex:index + 1];
            }
        }
    }
    
    NSAssert([alternativeSubparts count] > 0, @"at least one alternative");
    
    result = [[alternativeSubparts objectAtIndex:0] retain];
    
    [alternativeContentTypes release];
    [alternativeSubparts release];
    
    return [result autorelease];
}

@end

@implementation OPMultipartContentCoder (PrivateAPI)

// alternative
- (id)_contentFromMultipartAlternativeWithPreferredContentTypes:(NSArray *)preferredContentTypes attributed:(BOOL)shouldBeAttributed
{
    EDMessagePart *preferredSubpart = [self mostPreferredSubpartWithPreferredContentTypes:preferredContentTypes];
    
    if (preferredSubpart) 
    {
        return [preferredSubpart contentWithPreferredContentTypes:preferredContentTypes attributed:shouldBeAttributed];
    } 
    else 
    {
        id result = @"\nmultipart/alternative message part with no decodable alternative.\n";
        if (shouldBeAttributed) result = [[[NSAttributedString alloc] initWithString:result] autorelease];
        return result;
    }
}

// mixed
- (id)_contentFromMultipartMixedWithPreferredContentTypes:(NSArray *)preferredContentTypes attributed:(BOOL)shouldBeAttributed;
{
    id result = shouldBeAttributed ? [[[NSMutableAttributedString alloc] init] autorelease] : [NSMutableString string];
    EDMessagePart *subpart;
    NSEnumerator *enumerator = [[self subparts] objectEnumerator];
    
    while (subpart = [enumerator nextObject])
    {;
        @try 
        {
            id subpartContent = [subpart contentWithPreferredContentTypes:preferredContentTypes attributed:shouldBeAttributed];
            if (!subpartContent) 
            {
                [result appendString:[NSString stringWithFormat: @"\nsubpart decoding error [%@]\n", subpart]];
                //[subpart contentWithPreferredContentTypes:preferredContentTypes attributed:shouldBeAttributed];
            } 
            else shouldBeAttributed ? [result appendAttributedString:subpartContent] : [result appendString:subpartContent];
        } 
        @catch (id localException) 
        {
            [result appendString:[NSString stringWithFormat:@"\nsubpart decoding error [%@]\n", [localException reason]]];
            NSLog(@"subpart decoding error [%@]\n", [localException reason]);
        }
    }
    
    return result;
}

- (id)_contentFromMultipartSignedWithPreferredContentTypes:(NSArray *)preferredContentTypes attributed:(BOOL)shouldBeAttributed;
{
    id result = shouldBeAttributed ? [[[NSMutableAttributedString alloc] init] autorelease] : [NSMutableString string];
	
	if ([[self subparts] count] != 2) NSLog(@"Warning: multipart/signed with %d subparts (should be 2)", [[self subparts] count]);
	
    EDMessagePart *subpart = [[self subparts] firstObject];
    
	@try 
	{
		id subpartContent = [subpart contentWithPreferredContentTypes:preferredContentTypes attributed:shouldBeAttributed];
		if (!subpartContent) 
		{
			[result appendString:[NSString stringWithFormat: @"\nsubpart decoding error [%@]\n", subpart]];
		} 
		else shouldBeAttributed ? [result appendAttributedString:subpartContent] : [result appendString:subpartContent];
	} 
	@catch (id localException) 
	{
		[result appendString:[NSString stringWithFormat:@"\nsubpart decoding error [%@]\n", [localException reason]]];
		NSLog(@"subpart decoding error [%@]\n", [localException reason]);
	}
    
    return result;
}

/*
// related
- (NSAttributedString *)_attributedStringFromMultipartRelatedWithPreferredContentTypes:(NSArray *)preferredContentTypes
{
    NSMutableAttributedString *result;

    result = [[[NSMutableAttributedString alloc] initWithString:@"\nmultipart/related is not handled right at the moment. Fallback to multipart/mixed handling.\n"] autorelease];

    [result appendAttributedString:[self _attributedStringFromMultipartMixedWithPreferredContentTypes:preferredContentTypes]];

    return result;
}

// report
- (NSAttributedString *)_attributedStringFromMultipartReportWithPreferredContentTypes:(NSArray *)preferredContentTypes
{
    NSMutableAttributedString *result;
    
    result = [[[NSMutableAttributedString alloc] initWithString:@"\nmultipart/report is not handled right at the moment. Fallback to multipart/mixed handling.\n"] autorelease];
    
    [result appendAttributedString:[self _attributedStringFromMultipartMixedWithPreferredContentTypes:preferredContentTypes]];
    
    return result;
}
*/

@end
