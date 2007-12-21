//
//  OPPersistenceWrapper.m
//  BTreeLite
//
//  Created by Dirk Theisen on 23.10.07.
//  Copyright 2007 Dirk Theisen. All rights reserved.
//

#import "OPPersistenceWrapper.h"


@implementation OPPersistenceWrapper

+ (id) wrapperWithContent: (id) someContent
{
	return [[[self alloc] initWithContent: someContent] autorelease];
}
- (id) initWithContent: (id) someContent
{
	if (self = [super init]) {
		content = [someContent retain];
		//[content addObserver: self forKeyPath:<#(NSString *)keyPath#> options:<#(NSKeyValueObservingOptions)options#> context:<#(void *)context#>];
	}
	return self;
}

- (id) content
{
	return content;
}

- (void) dealloc
{
	[content release];
	[super dealloc];
}

- (id) initWithCoder: (NSCoder*) coder
{
	content = [coder decodeObjectForKey: @"OPContent"];
	return self;
}

- (void) encodeWithCoder: (NSCoder*) coder
{
	[coder encodeObject: content forKey: @"OPContent"];
}

- (NSString*) description
{
	return [NSString stringWithFormat: @"<OPPersistenceWrapper (oid#%016llx) around %@>", [self oid], [self content]];
}

@end
