//
//  GIIndex.h
//  GinkoVoyager
//
//  Created by Ulf Licht on 24.05.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface GIIndex : NSObject {
    
    NSString* name;
    SKIndexRef index;
    
}

+ (id)indexWithName:(NSString*)aName atPath:(NSString*)aPath;
- (void)initWithName:(NSString*)aName atPath:(NSString *)aPath;

- (SKIndexRef)index;
- (void)setIndex:(SKIndexRef)newIndex;
- (NSString *)name;
- (void)setName:(NSString * )newName;


- (BOOL)addDocumentWithName:(NSString *)aName andText:(NSString *)aText andProperties:(NSDictionary *) aPropertiesDictionary;
- (BOOL)removeDocumentWithName:(NSString *)aName;

- (BOOL)flushIndex;
- (BOOL)compactIndex;
- (CFIndex)documentCount;

- (NSArray *)hitsForQueryString:(NSString *)aQuery;


// internal helpers
- (SKDocumentRef)createDocumentWithName:(NSString *)aName;


@end
