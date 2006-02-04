//
//  TestWithPersistence.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 03.02.06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "TestWithPersistence.h"


@implementation TestWithPersistence
/*" All tests that need a clean Ginko database should be subclassed from this class. 
It provides an OPPersistentObjectContext in the instance variable %{context}.
If setUp or tearDown are implemented in subclasses super MUST be called.
"*/

- (void) setUp
{
    context = [OPPersistentObjectContext defaultContext];
    
    if (![context databaseConnection]) {
        
		if (!context) {
            NSString *path = @"/tmp/TestBase.sqlite";
			context = [[[OPPersistentObjectContext alloc] init] autorelease];
            //[[NSFileManager defaultManager] removeFileAtPath:path handler:NULL];
            
            [context setDatabaseConnectionFromPath:path];
            [context checkDBSchemaForClasses:@"GIMessage,GIAccount,GIThread,GIMessageGroup,GIProfile,GIMessageData"];
            
			[OPPersistentObjectContext setDefaultContext:context];
		}
    }
}

- (void) tearDown
{
    [context reset];
    [[NSFileManager defaultManager] removeFileAtPath:@"/tmp/TestBase.sqlite" handler:NULL];
    [OPPersistentObjectContext setDefaultContext:nil];
}

@end
