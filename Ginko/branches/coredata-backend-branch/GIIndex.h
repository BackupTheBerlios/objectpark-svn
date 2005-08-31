//
//  GIIndex.h
//  GinkoVoyager
//
//  Created by Ulf Licht on 24.05.05.
//  Copyright 2005 Ulf Licht, Objectpark Group. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface GIIndex : NSObject {
    
    @private
    NSString* name;
    SKIndexRef index;
    
}

+ (id)indexWithName:(NSString*)aName atPath:(NSString*)aPath;
- (id)initWithName:(NSString*)aName atPath:(NSString *)aPath;

- (SKIndexRef)index;

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
