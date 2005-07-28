//
//  GIProfile.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 26.07.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "GIProfile.h"
#import <Foundation/NSDebug.h>


@implementation GIProfile

// CREATE TABLE ZPROFILE ( Z_ENT INTEGER, Z_PK INTEGER PRIMARY KEY, Z_OPT INTEGER, ZDEFAULTCC VARCHAR, ZDEFAULTBCC VARCHAR, ZENABLED INTEGER, ZDEFAULTREPLYTO VARCHAR, ZMAILADDRESS VARCHAR, ZORGANIZATION VARCHAR, ZNAME VARCHAR, ZSIGNATURE BLOB, ZMESSAGETEMPLATE BLOB, ZREALNAME VARCHAR, ZSENDACCOUNT INTEGER );


+ (NSString*) databaseTableName
{
    return @"ZPROFILE";
}

+ (NSString*) persistentAttributesPlist
{
	return 
	@"{"
	@"defaultCC = {ColumnName = ZDEFAULTCC; AttributeClass = NSString;};"
	@"defaultBCC = {ColumnName = ZDEFAULTBCC; AttributeClass = NSString;};"
	@"enabled = {ColumnName = ZENABLED; AttributeClass = NSNumber;};"
	@"defaultReplyTo = {ColumnName = ZDEFAULTREPLYTO; AttributeClass = NSString;};"
	@"mailAddress = {ColumnName = ZMAILADDRESS; AttributeClass = NSString;};"
	@"organization = {ColumnName = ZORGANIZATION; AttributeClass = NSString;};"
	@"name = {ColumnName = ZNAME; AttributeClass = NSString;};"
	@"signature = {ColumnName = ZSIGNATURE; AttributeClass = NSString;};"
	@"messageTemplate = {ColumnName = ZMESSAGETEMPLATE; AttributeClass = NSString;};"
	@"sendAccount = {ColumnName = ZSENDACCOUNT; AttributeClass = OPPersistentObject;};"
	@"}";
}



@end
