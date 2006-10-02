//
//  TestNSString+OPMessageUtilities.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 17.02.05.
//  Copyright (c) 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "TestNSString+MessageUtils.h"
#import "NSString+MessageUtils.h"


@implementation TestNSString_MessageUtils

- (void) setUp
{
}

- (void) tearDown
{
}

- (void)testStringWithUnixLinebreaks
{
    NSString *testString = @"This is a test string with mixed\nLinebreaks\r\nyou know?";
    NSString *stringWithUnixLinebreaks;
    NSString *stringWithCanonicalLinebreaks;
        
    stringWithUnixLinebreaks = [testString stringWithUnixLinebreaks];
    stringWithCanonicalLinebreaks = [testString stringWithCanonicalLinebreaks];
    
    STAssertEqualObjects(stringWithCanonicalLinebreaks, @"This is a test string with mixed\r\nLinebreaks\r\nyou know?", @"Should be equal");
    STAssertEqualObjects(stringWithUnixLinebreaks, @"This is a test string with mixed\nLinebreaks\nyou know?", @"Should be equal");
    
    STAssertEqualObjects(stringWithUnixLinebreaks, [stringWithCanonicalLinebreaks stringWithUnixLinebreaks], @"length %d != length %d.", [stringWithUnixLinebreaks length], [[stringWithCanonicalLinebreaks stringWithUnixLinebreaks] length]);
}

- (void)testFormatFlowed
{
    NSString *testString = @"This is\r\n a test. And this test shows that there is much more complexity in format flowed wrapping than be visible at fist sight.";
    
	NSString *testEncoded = [testString stringByEncodingFlowedFormatUsingDelSp:NO];
	
	STAssertEqualObjects(testEncoded, @"This is\r\n  a test. And this test shows that there is much more complexity in \r\nformat flowed wrapping than be visible at fist sight.", @"Encoding without DelSp is broken");
	
	NSString *testDecoded = [testEncoded stringByDecodingFlowedFormatUsingDelSp:NO];
	
    STAssertEqualObjects(testString, testDecoded, @"should be same.");

	NSString *expectedString = @"this/is/simply/a/long/line/longer/than/80/characters/in/lenght/with/no/sucking/umlauts/for/ma-king/a/good/example";

	NSString *encodedString = [expectedString stringByEncodingFlowedFormatUsingDelSp:YES];
	NSString *formerDelSpEncodedString = [encodedString stringByDecodingFlowedFormatUsingDelSp:YES];
	
	STAssertEqualObjects(expectedString, formerDelSpEncodedString, @"DelSp Encoding does not seem to work");
	
	testString = @"this/is/simply/a/long/line/longer/than/80/characters/in/lenght/with/ \r\nno/sucking/umlauts/for/ma-king/a/good/example";
    
    STAssertTrue([[testString stringByDecodingFlowedFormatUsingDelSp:YES] isEqualToString:expectedString], @"%@ is wrong", [testString stringByDecodingFlowedFormatUsingDelSp:YES]);
	
	// -- just another test:
	NSString *expectedEncodedParagraph = 
		@"We can think of e.g. 15% rebate for this promotion. If you like to use  \r\n"
		@"your infrastructure we'd suggest that you send us the buyers info (such  \r\n"
		@"as email-address, name, address, etc.) and we would send out the  \r\n"
		@"license information.";

	NSString *paragraph = 
		@"We can think of e.g. 15% rebate for this promotion. If you like to use "
		@"your infrastructure we'd suggest that you send us the buyers info (such "
		@"as email-address, name, address, etc.) and we would send out the "
		@"license information.";
	
	NSString *encodedParagraph = [paragraph stringByEncodingFlowedFormatUsingDelSp:YES];
	
	STAssertEqualObjects(expectedEncodedParagraph, encodedParagraph, @"paragraph was not properly encoded.");

	NSString *decodedParagraph = [encodedParagraph stringByDecodingFlowedFormatUsingDelSp:YES];
	
	STAssertEqualObjects(paragraph, decodedParagraph, @"paragraph was not properly decoded.");
	
	// test long paragraph:
	NSString *longParagraph = 
		@"Thisisalongparagraphwithoutanywhitespaceinitasitseemstobethecaseinsomelanguageswhichhavenointerpunctationand"
		@"Thisisalongparagraphwithoutanywhitespaceinitasitseemstobethecaseinsomelanguageswhichhavenointerpunctationand"
		@"Thisisalongparagraphwithoutanywhitespaceinitasitseemstobethecaseinsomelanguageswhichhavenointerpunctationand"
		@"Thisisalongparagraphwithoutanywhitespaceinitasitseemstobethecaseinsomelanguageswhichhavenointerpunctationand"
		@"Thisisalongparagraphwithoutanywhitespaceinitasitseemstobethecaseinsomelanguageswhichhavenointerpunctationand"
		@"Thisisalongparagraphwithoutanywhitespaceinitasitseemstobethecaseinsomelanguageswhichhavenointerpunctationand"
		@"Thisisalongparagraphwithoutanywhitespaceinitasitseemstobethecaseinsomelanguageswhichhavenointerpunctationand"
		@"Thisisalongparagraphwithoutanywhitespaceinitasitseemstobethecaseinsomelanguageswhichhavenointerpunctationand"
		@"Thisisalongparagraphwithoutanywhitespaceinitasitseemstobethecaseinsomelanguageswhichhavenointerpunctationand"
		@"Thisisalongparagraphwithoutanywhitespaceinitasitseemstobethecaseinsomelanguageswhichhavenointerpunctationand"
		@"Thisisalongparagraphwithoutanywhitespaceinitasitseemstobethecaseinsomelanguageswhichhavenointerpunctationand"
		@"Thisisalongparagraphwithoutanywhitespaceinitasitseemstobethecaseinsomelanguageswhichhavenointerpunctationand"
		@"Thisisalongparagraphwithoutanywhitespaceinitasitseemstobethecaseinsomelanguageswhichhavenointerpunctationand"
		@"Thisisalongparagraphwithoutanywhitespaceinitasitseemstobethecaseinsomelanguageswhichhavenointerpunctationand"
		@"Thisisalongparagraphwithoutanywhitespaceinitasitseemstobethecaseinsomelanguageswhichhavenointerpunctationand"
		@"Thisisalongparagraphwithoutanywhitespaceinitasitseemstobethecaseinsomelanguageswhichhavenointerpunctationand"
		@"Thisisalongparagraphwithoutanywhitespaceinitasitseemstobethecaseinsomelanguageswhichhavenointerpunctationand"
		@"Thisisalongparagraphwithoutanywhitespaceinitasitseemstobethecaseinsomelanguageswhichhavenointerpunctationand"
		@"Thisisalongparagraphwithoutanywhitespaceinitasitseemstobethecaseinsomelanguageswhichhavenointerpunctation";
	
	NSString *encodedLongParagraph = [longParagraph stringByEncodingFlowedFormatUsingDelSp:YES];
	
	NSString *decodedLongParagraph = [encodedLongParagraph stringByDecodingFlowedFormatUsingDelSp:YES];
	
	STAssertEqualObjects(longParagraph, decodedLongParagraph, @"long paragraph flowed encoding is broken.");
	
	// test empty lines:
	NSString *emptyLinesString = @"This is a line\r\n"
		@"\r\n"
		@"Afer empty line.";
	NSString *encodedEmptyLineString = [emptyLinesString stringByEncodingFlowedFormatUsingDelSp:YES];
	NSString *decodedEmptyLineString = [encodedEmptyLineString stringByDecodingFlowedFormatUsingDelSp:YES];
	
	STAssertEqualObjects(emptyLinesString, decodedEmptyLineString, @"empty line flowed encoding is broken.");
}

- (void)testPunycode
{
    NSString *punycode = /* @"PorqunopuedensimplementehablarenEspaol-fmd56a"; */
    @"heinz-knig-kcb";
    
//     NSLog(@"decoded punycode: %@", [punycode punycodeDecodedString]);
    
    NSAssert([punycode isEqual:[[punycode punycodeDecodedString] punycodeEncodedString]], @"not equal");
}

- (void) testIDNAEncoding
{
    NSString *IDNAEncoded = @"mail.xn--heinz-knig-kcb.de";
    
//     NSLog(@"decoded IDNA: %@", [IDNAEncoded IDNADecodedDomainName]);
    
    NSAssert([IDNAEncoded isEqual:[[IDNAEncoded IDNADecodedDomainName] IDNAEncodedDomainName]], @"not equal");
}

/*
- (void) testEmptyFirstName
{
    [person setFirstName: @""];
    [person setLastName: @"Picasso"];
    STAssertEqualObjects ([person fullName], [person lastName], 
                          @"Last name should equal full name.");
}


- (void) testNilFirstName
{
    [person setFirstName: nil];
    [person setLastName: @"Picasso"];
    STAssertEqualObjects ([person firstName], @"",
                          @"First name should be empty.");
    STAssertEqualObjects ([person fullName], [person lastName], 
                          @"Last name should equal full name.");
}


- (void) testEmptyLastName
{
    [person setFirstName: @"Pablo"];
    [person setLastName: @""];
    STAssertEqualObjects ([person fullName], [person firstName], 
                          @"Full name should equal first name.");
}


- (void) testNilLastName
{
    [person setFirstName: @"Pablo"];
    [person setLastName: nil];
    STAssertEqualObjects ([person lastName], @"",
                          @"Last name should be empty.");
    STAssertEqualObjects ([person fullName], [person firstName], 
                          @"Full name should equal first name.");
}
*/
@end
