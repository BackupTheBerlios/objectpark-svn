//
//  TestOPXFolderContentCoder.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 22.02.05.
//  Copyright (c) 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "TestOPXFolderContentCoder.h"
#import "OPXFolderContentCoder.h"

@implementation TestOPXFolderContentCoder

#define FOLDERPATH @"/tmp/OPMSXFolderTestFolder"
#define FILEPATH @"/tmp/OPMSXFolderTestFolder/Testfile"

- (void) testEncodeAndDecode
{
    NSFileManager *fileManager;
    OPXFolderContentCoder *coder;
    NSFileWrapper *wrapper;
    EDMessagePart *messagePart;
    NSDictionary *fileWrappers;
    
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
    // make folder with file in it
    fileManager = [NSFileManager defaultManager];
    BOOL couldCreate = [fileManager createDirectoryAtPath:FOLDERPATH attributes:nil];
    STAssertTrue(couldCreate, @"Could not create folder.");
    STAssertTrue([fileManager createFileAtPath:FILEPATH contents:[NSData data] attributes: nil], @"Could not create file.");
    
    wrapper = [[[NSFileWrapper alloc] initWithPath:FOLDERPATH] autorelease];

    // encode file wrapper in X-Folder messagepart
    coder = [[[OPXFolderContentCoder alloc] initWithFileWrapper:wrapper] autorelease];

	/*

    messagePart = [coder messagePart];
    STAssertNotNil(messagePart, @"no message part could be encoded.");

    // decode file wrapper from X-Folder messagepart
    coder = [[[OPXFolderContentCoder alloc] initWithMessagePart:messagePart] autorelease];
    wrapper = [coder fileWrapper];
    STAssertNotNil(wrapper, @"no fileWrapper could be decoded.");
    
    // inspect result
    STAssertTrue([[wrapper preferredFilename] isEqualToString:[FOLDERPATH lastPathComponent]], @"folder has wrong file name");
    STAssertTrue([wrapper isDirectory], @"folder is no directory :-)");
    
    fileWrappers = [wrapper fileWrappers];
    STAssertTrue([fileWrappers count] == 1, @"not exactly one file in folder");
    STAssertNotNil([fileWrappers objectForKey:[FILEPATH lastPathComponent]], @"file in folder has wrong name");
	*/
	
	[pool release];
	NSLog(@"after");
}

- (void)tearDown
{
    [[NSFileManager defaultManager] removeFileAtPath:FOLDERPATH handler: nil];
}

- (void)setUp
{
    [[NSFileManager defaultManager] removeFileAtPath:FOLDERPATH handler:nil];
}

@end
