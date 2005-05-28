//
//  OPMBoxFile.h
//  OPMessageServices
//
//  Created by Dirk Theisen on Wed Jul 28 2004.
//  Copyright (c) 2004 Objectpark Development Group. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OPMBoxFile : NSObject {

    @protected
    NSString *_path;
    BOOL _isReadOnly;
    NSDate *_dateOfMostRecentChange;
    
    NSLock *_lock;
    
    FILE *_mboxFile;
}

/*" Factory Methods "*/
+ (id) mboxWithPath:(NSString*) aPath;
+ (id) mboxWithPath:(NSString*) aPath createIfNotPresent: (BOOL) shouldCreateIfNotPresent;


    /*" Initialization Methods "*/
- (id) initWithPath:(NSString*) aPath;
- (id) initWithPath:(NSString*) aPath createIfNotPresent:(BOOL) shouldCreateIfNotPresent;

- (NSData*) mboxSubdataFromOffset: (unsigned) offset endOffset: (unsigned*) endOffset;

- (FILE*) mboxFile;
- (NSString*) path;
- (void) setPath: (NSString*) aPath;
- (BOOL) isReadOnly;
- (unsigned int) mboxFileSize;

- (NSEnumerator*) messageDataEnumerator;

/*" Exception name for Mbox exceptions. "*/
extern NSString *OPMBoxException;

@end
