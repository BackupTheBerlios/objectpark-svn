//
//  GIMessage.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 22.07.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "GIMessage.h"
#import "GIProfile.h"


@implementation GIMessage

    // CREATE TABLE ZMESSAGE ( Z_ENT INTEGER, Z_PK INTEGER PRIMARY KEY, Z_OPT INTEGER, ZISANSWERED INTEGER, ZISFLAGGED INTEGER, ZMESSAGEID VARCHAR, ZISFULLTEXTINDEXED INTEGER, ZISSEEN INTEGER, ZISINTERESTING INTEGER, ZAUTHOR VARCHAR, ZISFROMME INTEGER, ZISDRAFT INTEGER, ZISQUEUED INTEGER, ZSUBJECT VARCHAR, ZDATE TIMESTAMP, ZISJUNK INTEGER, ZTHREAD INTEGER, ZPROFILE INTEGER, ZREFERENCE INTEGER, ZMESSAGEDATA INTEGER );

+ (NSString*) databaseTableName
{
    return @"ZMESSAGE";
}

+ (NSString*) persistentAttributesPlist
{
	return 
	@"{"
	@"messageId = {ColumnName = ZMESSAGEID; AttributeClass = NSString;};"
	@"messageDataRowId = {ColumnName = ZMESSAGEDATA; AttributeClass = NSNumber;};"
	@"subject = {ColumnName = ZSUBJECT; AttributeClass = NSString;};"
	@"date = {ColumnName = ZDATE; AttributeClass = NSCalendarDate;};"
	@"author = {ColumnName = ZAUTHOR; AttributeClass = NSString;};"
	@"profile = {ColumnName = ZPROFILE; AttributeClass = GIProfile;};"
	@"}";
}


+ (id) messageForMessageId: (NSString*) messageId
	/*" Returns either nil or the message specified by its messageId. "*/
{
	GIMessage* result = nil;
    if (messageId) {
		
		OPPersistentObjectContext* context = [OPPersistentObjectContext defaultContext];
		
		OPPersistentObjectEnumerator* objectEnum = [context objectEnumeratorForClass: self where: @"$messageId=?"];
		
		[objectEnum reset]; // optional
		[objectEnum bind: messageId, nil]; // only necessary for requests containing question mark placeholders
		
		result = [objectEnum nextObject];
		
	}
	return result;
	
	/*	
        NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
        //NSManagedObjectModel *model = [[NSApp delegate] managedObjectModel];
        [request setEntity: [self entity]];
        NSPredicate *predicate = [NSComparisonPredicate predicateWithLeftExpression:[NSExpression expressionForKeyPath: @"messageId"] rightExpression:[NSExpression expressionForConstantValue:messageId] modifier:NSDirectPredicateModifier type:NSEqualToPredicateOperatorType options:0];
        [request setPredicate:predicate];
        
        NSError *error = nil;
        NSArray *results = [[NSManagedObjectContext threadContext] executeFetchRequest:request error:&error];
        
        NSAssert1(!error, @"+[G3Message messageForMessageId:inManagedObjectContext:] error while fetching (%@).", error);    
        
        if (results != nil) 
        {
            return [results count] ? [results lastObject] : nil;						
        } 
    }
    return nil;
	 */
}


- (NSString*) messageId
{
    return [self persistentValueForKey: @"messageId"];
}


@end
