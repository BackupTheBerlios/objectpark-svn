//
//  GIThread.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 02.08.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "GIThread.h"

@class G3Message;
@class G3MessageGroup;

@implementation GIThread

// CREATE TABLE ZTHREAD ( Z_ENT INTEGER, Z_PK INTEGER PRIMARY KEY, Z_OPT INTEGER, ZSIZE INTEGER, ZSTATS INTEGER, ZNUMBEROFMESSAGES INTEGER, ZSUBJECT VARCHAR, ZDATE TIMESTAMP );

+ (NSString*) databaseTableName
{
	return @"ZTHREAD";
}

+ (NSString*) persistentAttributesPlist
{
	return 
	@"{"
	@"numberOfMessages = {ColumnName = ZNUMBEROFMESSAGES; AttributeClass = NSNumber;};"
	@"subject = {ColumnName = ZSUBJECT; AttributeClass = NSString;};"
	@"date = {ColumnName = ZDATE; AttributeClass = NSNumber;};"
	@"}";
}

@end
