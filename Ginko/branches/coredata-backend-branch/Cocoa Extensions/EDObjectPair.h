//---------------------------------------------------------------------------------------
//  EDObjectPair.h created by erik on Sat 29-Aug-1998
//  @(#)$Id: EDObjectPair.h,v 1.1 2004/12/22 17:11:05 theisen Exp $
//
//  Copyright (c) 1998-1999 by Erik Doernenburg. All rights reserved.
//
//  Permission to use, copy, modify and distribute this software and its documentation
//  is hereby granted, provided that both the copyright notice and this permission
//  notice appear in all copies of the software, derivative works or modified versions,
//  and any portions thereof, and that both notices appear in supporting documentation,
//  and that credit is given to Erik Doernenburg in all documents and publicity
//  pertaining to direct or indirect use of this code or its derivatives.
//
//  THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
//  SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
//  "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
//  DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
//  OR OF ANY DERIVATIVE WORK.
//---------------------------------------------------------------------------------------


#import <Foundation/Foundation.h>

@interface EDObjectPair : NSObject <NSCopying, NSMutableCopying, NSCoding>
{
    id 	firstObject;	/*" First object of the pair. "*/
    id 	secondObject;   /*" Second object of the pair. "*/
}

/*" Creating new pair objects "*/
+ (id)pair;
+ (id)pairWithObjectPair:(EDObjectPair *)aPair;
+ (id)pairWithObjects:(id)anObject:(id)anotherObject;

- (id)initWithObjectPair:(EDObjectPair *)aPair;
- (id)initWithObjects:(id)anObject:(id)anotherObject; // designated initializer

/*" Retrieving objects "*/
- (id)firstObject;
- (id)secondObject;

- (NSArray*) allObjects;

@end

@interface EDMutableObjectPair : EDObjectPair

- (void)setFirstObject:(id)anObject;
- (void)setSecondObject:(id)anObject;

@end