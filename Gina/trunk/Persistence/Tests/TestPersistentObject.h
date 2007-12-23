//
//  Test-PersistentObject.h
//  Gina
//
//  Created by Dirk Theisen on 21.12.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "OPPersistentObjectContext.h"
#import "OPPersistentStringDictionary.h"


@interface TestPersistentObject : SenTestCase {
	OPPersistentObjectContext* context;
}

@end
