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

- (void)setUp
{
}

- (void)tearDown
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
    NSString *testString = @"This is\n a test";
    
    STAssertEqualObjects(testString, [[testString stringByEncodingFlowedFormat] stringByDecodingFlowedUsingDelSp:NO], @"should be same.");
    
    testString = @"this/is/simply/a/long/line/longer/than/80/characters/in/lenght/with/ \r\nno/sucking/umlauts/for/making/a/good/example";
    NSString *expectedString = @"this/is/simply/a/long/line/longer/than/80/characters/in/lenght/with/no/sucking/umlauts/for/making/a/good/example";
    
    STAssertTrue([[testString stringByDecodingFlowedUsingDelSp:YES] isEqualToString:expectedString], @"%@ is wrong", [testString stringByDecodingFlowedUsingDelSp:YES]);
}

- (void)testPunycode
{
    NSString *punycode = /* @"PorqunopuedensimplementehablarenEspaol-fmd56a"; */
    @"heinz-knig-kcb";
    
    NSLog(@"decoded punycode: %@", [punycode punycodeDecodedString]);
    
    shouldBeEqual(punycode, [[punycode punycodeDecodedString] punycodeEncodedString]);
}

- (void)testIDNAEncoding
{
    NSString *IDNAEncoded = @"mail.xn--heinz-knig-kcb.de";
    
    NSLog(@"decoded IDNA: %@", [IDNAEncoded IDNADecodedDomainName]);
    
    shouldBeEqual(IDNAEncoded, [[IDNAEncoded IDNADecodedDomainName] IDNAEncodedDomainName]);
}

/*
- (void) testEmptyFirstName
{
    [person setFirstName:@""];
    [person setLastName:@"Picasso"];
    STAssertEqualObjects ([person fullName], [person lastName], 
                          @"Last name should equal full name.");
}


- (void) testNilFirstName
{
    [person setFirstName:nil];
    [person setLastName:@"Picasso"];
    STAssertEqualObjects ([person firstName], @"",
                          @"First name should be empty.");
    STAssertEqualObjects ([person fullName], [person lastName], 
                          @"Last name should equal full name.");
}


- (void) testEmptyLastName
{
    [person setFirstName:@"Pablo"];
    [person setLastName:@""];
    STAssertEqualObjects ([person fullName], [person firstName], 
                          @"Full name should equal first name.");
}


- (void) testNilLastName
{
    [person setFirstName:@"Pablo"];
    [person setLastName:nil];
    STAssertEqualObjects ([person lastName], @"",
                          @"Last name should be empty.");
    STAssertEqualObjects ([person fullName], [person firstName], 
                          @"Full name should equal first name.");
}
*/
@end
