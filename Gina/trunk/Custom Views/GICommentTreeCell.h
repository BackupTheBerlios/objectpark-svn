//
//  $Id: GICommentTreeCell.h,v 1.13 2005/04/05 09:11:38 theisen Exp $
//  Gina
//
//  Created by Dirk Theisen on 13.12.04.
//  Copyright 2004, 2005 Objectpark.org. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface GICommentTreeCell : NSCell {
    struct {
        int isSeen:1;
        int isDummyMessage:1;
        int hasConnectionToDummyMessage:1;
        unsigned int color:3;
    } flags;
    struct {
        int north:1;
        int south:1;
        int east:1;
        int west:1;
    } connections;
    struct {
        int north:1;
        int south:1;
        int east:1;
        int west:1;
    } navigation;
    //id representedObject;
}

- (void) setIsDummyMessage:(BOOL) aBool;
- (void) setHasConnectionToDummyMessage:(BOOL) aBool;
- (void) setSeen:(BOOL) aBool;
- (void) setColorIndex:(unsigned int) anIndex;

- (void) reset;

- (BOOL) hasConnection;
- (void) addConnectionToNorth;
- (void) addConnectionToSouth;
- (void) addConnectionToEast;
- (void) addConnectionToWest;

- (void) addNavigationToNorth;
- (void) addNavigationToSouth;
- (void) addNavigationToEast;
- (void) addNavigationToWest;

@end

@interface NSMatrix (G3Extensions)

- (NSCell*) cellForRepresentedObject: (id) object;

@end