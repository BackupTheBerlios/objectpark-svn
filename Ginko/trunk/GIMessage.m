//
//  GIMessage.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 22.07.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "GIMessage.h"


@implementation GIMessage

+ (NSString*) databaseTableName
{
    return @"ZMESSAGE";
}

+ (NSArray*) databaseAttributeNames
{
    // CREATE TABLE ZMESSAGE ( Z_ENT INTEGER, Z_PK INTEGER PRIMARY KEY, Z_OPT INTEGER, ZISANSWERED INTEGER, ZISFLAGGED INTEGER, ZMESSAGEID VARCHAR, ZISFULLTEXTINDEXED INTEGER, ZISSEEN INTEGER, ZISINTERESTING INTEGER, ZAUTHOR VARCHAR, ZISFROMME INTEGER, ZISDRAFT INTEGER, ZISQUEUED INTEGER, ZSUBJECT VARCHAR, ZDATE TIMESTAMP, ZISJUNK INTEGER, ZTHREAD INTEGER, ZPROFILE INTEGER, ZREFERENCE INTEGER, ZMESSAGEDATA INTEGER );

    static NSArray* attrs = nil;
    if (!attrs) {
        attrs = [[NSArray alloc] initWithObjects:
            @"ZMESSAGEID",
            @"ZMESSAGEDATA",
            @"ZDATE",
            @"ZAUTHOR",
            @"ZSUBJECT",
            @"ZPROFILE",
            nil];
    }
    return attrs;
}

+ (NSArray*) objectAttributeNames
{
    static NSArray* oattrs = nil;
    if (!oattrs) {
        oattrs = [[NSArray alloc] initWithObjects:
            @"messageId",
            @"messageDataForeignKey",
            @"date",
            @"author",
            @"subject",
            @"profileForeignKey",
            nil];
    }
    return oattrs;
}

- (NSString*) messageId
{
    return [self persistentValueForKey: @"messageId"];
}

@end
