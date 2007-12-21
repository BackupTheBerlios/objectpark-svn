//
//  OPPersistenceWrapper.h
//  BTreeLite
//
//  Created by Dirk Theisen on 23.10.07.
//  Copyright 2007 Dirk Theisen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OPPersistentObject.h"


@interface OPPersistenceWrapper : OPPersistentObject <NSCoding> {
	id content;
}

+ (id) wrapperWithContent: (id) someContent;
- (id) initWithContent: (id) someContent;

- (id) content;

@end
