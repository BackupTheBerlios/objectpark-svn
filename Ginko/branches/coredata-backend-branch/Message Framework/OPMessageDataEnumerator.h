//
//  $Id: OPMessageDataEnumerator.h,v 1.1 2005/01/17 00:00:59 theisen Exp $
//  OPMessageServices
//
//  Created by Jšrg Westheide on Mon Jul 19 2004.
//  Copyright (c) 2004 Objectpark Development Group. All rights reserved.

#import <Foundation/Foundation.h>
@class OPMBoxFile;

@interface OPMessageDataEnumerator : NSEnumerator {
    OPMBoxFile* mbox;
    unsigned offset;
    unsigned length;
}

+ (id) enumeratorWithMBox: (OPMBoxFile*) theMbox;

- (id) initWithMBox: (OPMBoxFile*) theMbox;
- (unsigned) offsetOfNextObject;

@end
