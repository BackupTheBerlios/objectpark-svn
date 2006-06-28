//
//  OPSQLiteConnection.m
//
//  Created by Dirk Theisen on 22.07.05.
//  Copyright 2005 Dirk Theisen <d.theisen@objectpark.org>. All rights reserved.
//
//
//  OPPersistence - a persistent object library for Cocoa.
//
//  For non-commercial use, you can redistribute this library and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your option) any later version.
//
//  This library is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//  Lesser General Public License for more details:
//
//  <http://www.gnu.org/copyleft/lesser.html#SEC1>
//
//  You should have received a copy of the GNU Lesser General Public
//  License along with this library; if not, write to the Free Software
//  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
//
//  For commercial use, commercial licenses and redistribution licenses
//  are available - including support - from the author,
//  Dirk Theisen <d.theisen@objectpark.org> for a reasonable fee.
//
//  DEFINITION Commercial use
//  This library is used commercially whenever the library or derivative work
//  is charged for more than the price for shipping and handling.
//

#import "OPSQLiteConnection.h"
#import "OPClassDescription.h"
#import "OPPersistence.h"
#import <OPDebug/OPLog.h>

@implementation OPSQLiteStatement


static NSHashTable* allInstances;

+ (void) initialize
{
	if (!allInstances) {
		allInstances = NSCreateHashTable(NSNonRetainedObjectHashCallBacks, 10);
	}
}

+ (NSArray*) runningStatements
{
	NSMutableArray* allStatements = [NSMutableArray array];
	NSHashEnumerator e = NSEnumerateHashTable(allInstances);
	id item;
	while (item = NSNextHashEnumeratorItem(&e)) {
		//NSLog(@"Running Enumerator: %@", item);
		[allStatements addObject: item];
	}
	NSEndHashTableEnumeration(&e);
	return allStatements;
}


- (id) initWithSQL: (NSString*) sql connection: (OPSQLiteConnection*) aConnection 
{
	NSParameterAssert(sql != nil);
	NSParameterAssert(aConnection != nil);
	if (self = [super init]) {
		
		//NSParameterAssert(aConnection->connection != NULL);
		
		@synchronized(aConnection) {
			OPDebugLog(OPPERSISTENCE, OPL_MEMORYMANAGEMENT, @"Creating new sql statement %@ '%@'", self, sql);
			if (NSDebugEnabled) sqlString = [sql copy];
			
			int res = sqlite3_prepare([aConnection database], [sql UTF8String], -1, &statement, NULL);
			
			if ((res != SQLITE_OK) || !statement) {
				[self autorelease];
				[aConnection raiseSQLiteError];
				//NSLog(@"Error preparing sql statement %@: %@", self, [connection lastError]);
				//[self autorelease];
				//return nil;
			}
			NSHashInsert(allInstances, self);
			
			connection = [aConnection retain];
		}
	}
	return self;
}

- (NSString*) description 
{
	return [NSString stringWithFormat: @"%@ sql: '%@' connection: %@.", [super description], sqlString, connection]; 
}

- (void) bindPlaceholderAtIndex: (int) index toValue: (id) value
	/*" Index is zero-based. Be sure to call -reset before binding the first value. "*/
{
	@synchronized(connection) {
		index++;
		if (value) {
			[value bindValueToStatement: statement index: index];
		} else {
			sqlite3_bind_null(statement, index);
		}
		NSHashInsert(allInstances, self);
	}
}

- (void) bindPlaceholderAtIndex: (int) index toRowId: (ROWID) rid
	/*" Index is zero-based. Be sure to call -reset before binding the first value. "*/
{
	@synchronized(connection) {
		index++;
		if (rid) {
			sqlite3_bind_int64(statement, index, rid);
		} else {
			sqlite3_bind_null(statement, index);
		}
		NSHashInsert(allInstances, self);
	}
}

- (void) reset
{
	@synchronized(connection) {
		sqlite3_reset(statement);
		NSHashRemove(allInstances, self);
	}
}

- (void) dealloc
{
	//NSLog(@"Deallocing sql statement %@.", self);
	
	sqlite3_finalize(statement);
	[connection release];
	[sqlString release];
	NSHashRemove(allInstances, self);
	[super dealloc];
}

- (sqlite3_stmt*) stmt
{
	return statement;
}

- (int) execute
	/*" Raises exception on error. "*/
{
	int result;
	@synchronized(connection) {
		OPDebugLog(OPPERSISTENCE, OPINFO, @"SQL: Executing %@", self);
		result = sqlite3_step(statement);
		
		if (result != SQLITE_DONE && result != SQLITE_ROW) {
			[connection raiseSQLiteError];
		}	
	}
	return result;
}

@end

@implementation OPSQLiteConnection


+ (void) initialize
{
}

- (void) raiseSQLiteError
{
	NSLog(@"SQLite %s function on connection %@ returned with an error: %@", sqlite3_libversion(), self, [self lastError]);
	
	[NSException raise: @"OPSQLiteError" 
				format: @"Error executing a sqlite %s function on connection %@: %@", sqlite3_libversion(), self, [self lastError]];
	// todo: include error number!
}


- (sqlite3*) database
{
    return connection;
}

- (id) initWithFile: (NSString*) inPath
{
    if (self = [super init]) {
    
        dbPath     = [inPath copy];
        connection = NULL;	
    }
    return self;
}

- (NSDictionary*) attributesForRowId: (ROWID) rid
							 ofClass: (Class) persistentClass
{
    NSMutableDictionary* result = nil;
	OPClassDescription* cd = [persistentClass persistentClassDescription];
		
	@synchronized(self) {
		OPSQLiteStatement* statement = [self fetchStatementForClass: persistentClass];
		[statement reset];
		[statement bindPlaceholderAtIndex: 0 toRowId: rid];
		
		if ([statement execute] == SQLITE_ROW) {
			// We got a raw row, loop over all attributes and create a dictionary:
			
			NSArray* attributes = cd->attributeDescriptions;
			int attrCount = cd->simpleAttributeCount;
			int i = 0;
			//NSLog(@"Processing attributeDescriptions %@", attributes);
			result = [NSMutableDictionary dictionaryWithCapacity: attrCount];
			NSAssert2(sqlite3_column_count([statement stmt])>=attrCount, @"Not enough columns returned. Expected %d, got %d", 
					  attrCount, sqlite3_column_count([statement stmt]));
			//NSLog(@"Got %d column return.", sqlite3_column_count([statement stmt]));
			while (i<attrCount) {
				OPAttributeDescription* desc = [attributes objectAtIndex: i];
				id value = [desc->theClass newFromStatement: [statement stmt] index: i];
				// if (NSDebugEnabled) NSLog(@"Read attribute %@ (%@): %@",desc->name, desc->theClass, value);
				if (value) {
					[result setObject: value forKey: desc->name];
				} 
				
				i++;
			}
		} 
		[statement reset];
	}
    return result;
}



- (OPSQLiteStatement*) fetchStatementForClass: (Class) poClass
										rowId: (ROWID) rid
								 relationship: (NSString*) key;
{
	OPClassDescription* cd = [poClass persistentClassDescription];
	
	OPAttributeDescription* ad = [cd attributeWithName: key];
	
	NSString* queryString = [ad queryString];
	
	OPSQLiteStatement* result = [[[OPSQLiteStatement alloc] initWithSQL: queryString connection: self] autorelease];
	
	return result;
}

 
 - (OPSQLiteStatement*) updateStatementForClass: (Class) poClass
{
	OPSQLiteStatement* result;
	@synchronized(updateStatements) {
		result = [updateStatements objectForKey: poClass];
		if (!result) {
			// Create statement using class description and cache it in the updateStatements dictionary:
			OPClassDescription* cd = [poClass persistentClassDescription];
			NSMutableArray* columnNames = [cd columnNames];
			int i = [columnNames count] + 1;
			NSMutableArray* valuePlaceholders = [NSMutableArray array];
			while (i--) [valuePlaceholders addObject: @"?"];
			[columnNames addObject: @"ROWID"];
			
			NSString* queryString = [NSString stringWithFormat: @"insert or replace into %@ (%@) values (%@);", [cd tableName], [columnNames componentsJoinedByString: @","], [valuePlaceholders componentsJoinedByString: @","]];
			//NSLog(@"Preparing statement for updates: %@", queryString);
			
			result = [[[OPSQLiteStatement alloc] initWithSQL: queryString connection: self] autorelease]; 
			
			//disabled [updateStatements setObject: result forKey: poClass]; // cache it
			
		}
	}
	return result;
}
 
 

/*
- (OPSQLiteStatement*) updateStatementForClass: (Class) poClass
{
	OPSQLiteStatement* result = [updateStatements objectForKey: poClass];
	if (!result) {
		char* delimiter = "";
		// Create statement using class description and cache it in the updateStatements dictionary:
		OPClassDescription* cd = [poClass persistentClassDescription];
		NSMutableArray* columnNames = [cd columnNames];
		NSMutableString* queryString = [NSMutableString string];
		[queryString appendFormat: @"update %@ set ", [cd tableName]];
		NSEnumerator* e = [columnNames objectEnumerator];
		NSString* columnName;
		while (columnName = [e nextObject]) {
			[queryString appendFormat: @"%s%@=?", delimiter, columnName];
			delimiter = ",";
		}
		
		[queryString appendString: @" where ROWID=?;"];
		//NSString* queryString = [NSString stringWithFormat: @"insert or replace into %@ (%@) values (%@);", [cd tableName], [columnNames componentsJoinedByString: @","], [valuePlaceholders componentsJoinedByString: @","]];
		//NSLog(@"Preparing statement for updates: %@", queryString);
		
		result = [[[OPSQLiteStatement alloc] initWithSQL: queryString connection: self] autorelease]; 
		
		// Cache statement for later use:
		[updateStatements setObject: result forKey: poClass];
		
	}
	return result;
}
*/

- (OPSQLiteStatement*) insertStatementForClass: (Class) poClass
{
	OPSQLiteStatement* result;
	@synchronized(insertStatements) {
		result = [insertStatements objectForKey: poClass];
		
		if (!result) {
			// Create statement using class description and cache it in the insertStatements dictionary:
			OPClassDescription* cd = [poClass persistentClassDescription];
			
			// Just create an empty entry to get a new ROWID:
			NSString* queryString = [NSString stringWithFormat: @"insert into %@ (ROWID) values (NULL)", [cd tableName]];
			//NSLog(@"Preparing statement for inserts: %@", queryString);
			//sqlite3_prepare([connection database], [queryString UTF8String], -1, &insertStatement, NULL);
			result = [[[OPSQLiteStatement alloc] initWithSQL: queryString connection: self] autorelease]; 
			
			NSAssert2(result, @"Could not prepare statement (%@): %@", queryString, [self lastError]);	
			// Cache statement for later use:
			[insertStatements setObject: result forKey: poClass]; 
		}
	}
	return result;
}


- (OPSQLiteStatement*) addStatementForJoinTableName: (NSString*) joinTableName
									firstColumnName: (NSString*) firstColumnName 
								   secondColumnName: (NSString*) secondColumnName
/*" Bind source oid to index 0 and target oid to index 1. "*/
{
	NSParameterAssert([joinTableName length]);
	NSParameterAssert([firstColumnName length]);
	NSParameterAssert([secondColumnName length]);
	
	OPSQLiteStatement* result;
	@synchronized(addRelationStatements) {	
		result = [addRelationStatements objectForKey: joinTableName];
		if (!result) {
			NSParameterAssert(joinTableName != nil); // make sure this is a many-to-many attribute
			
			NSString* queryString = [NSString stringWithFormat: @"insert into %@ (%@,%@) values (?,?);", joinTableName, firstColumnName, secondColumnName];
			
			//OPDebugLog(OPPERSISTENCE, OPINFO, @"Preparing statement for fetches: %@", queryString);
			result = [[[OPSQLiteStatement alloc] initWithSQL: queryString connection: self] autorelease];
			// Cache statement for later use:
			[addRelationStatements setObject: result forKey: joinTableName];
		}
	}
	return result;
}

- (OPSQLiteStatement*) removeStatementForJoinTableName: (NSString*) joinTableName
									   firstColumnName: (NSString*) firstColumnName 
									  secondColumnName: (NSString*) secondColumnName
	/*" Bind source oid to index 0 and target oid to index 1. "*/
{
	NSParameterAssert([joinTableName length]);
	NSParameterAssert([firstColumnName length]);
	NSParameterAssert([secondColumnName length]);
	
	OPSQLiteStatement* result;
	@synchronized(removeRelationStatements) {
		result = [removeRelationStatements objectForKey: joinTableName];
		if (!result) {
			NSParameterAssert(joinTableName != nil); // make sure this is a many-to-many attribute
			
			NSString* queryString = [NSString stringWithFormat: @"delete from %@ where \"%@\"=? and \"%@\"=?;", joinTableName, firstColumnName, secondColumnName];
			
			//OPDebugLog(OPPERSISTENCE, OPINFO, @"Preparing statement for fetches: %@", queryString);
			result = [[[OPSQLiteStatement alloc] initWithSQL: queryString connection: self] autorelease];
			// Cache statement for later use:
			[removeRelationStatements setObject: result forKey: joinTableName];
		}
	}
	return result;
}


- (OPSQLiteStatement*) fetchStatementForClass: (Class) poClass
{
	OPSQLiteStatement* result;
	@synchronized(fetchStatements) {
		result = [fetchStatements objectForKey: poClass];
		
		if (!result) {
			// Create statement using class description and cache it in the updateStatements dictionary:
			OPClassDescription* cd = [poClass persistentClassDescription];
			
			NSString* queryString = [NSString stringWithFormat: @"select %@ from %@ where ROWID=?;", [[cd columnNames] componentsJoinedByString: @","], [cd tableName]];
			//OPDebugLog(OPPERSISTENCE, OPINFO, @"Preparing statement for fetches: %@", queryString);
			result = [[[OPSQLiteStatement alloc] initWithSQL: queryString connection: self] autorelease];
			// Cache statement for later use:
			[fetchStatements setObject: result forKey: poClass]; // cache it
		}
	}
	return result;
}


- (ROWID) updateRowOfClass: (Class) poClass
					 rowId: (ROWID) rid
					values: (NSDictionary*) values
/*" Returns a new row id, if rid was 0. "*/
{
	
	OPClassDescription* cd = [poClass persistentClassDescription];
	NSArray* attributes = cd->attributeDescriptions;
	OPSQLiteStatement* updateStatement = [self updateStatementForClass: poClass];		
	
	int attrCount = [attributes count];
	int i, placeholder;

	@synchronized(self) {
		[updateStatement reset];
		// Bind all placeholders in updateStatement:
		for (i=placeholder=0; i<attrCount; i++) {
			OPAttributeDescription* ad = [attributes objectAtIndex: i];
			if (![ad isToManyRelationship]) {
				NSString* key = ad->name;
				id value = [values objectForKey: key];
				//NSLog(@"Binding value %@ to attribute #%d(%@) of update statement.", value, placeholder, key);
				[updateStatement bindPlaceholderAtIndex: placeholder++ toValue: value];
			}
		}
		//	NSLog(@"Binding rowid to attribute #%d(%@) of update statement.", i);
		
		[updateStatement bindPlaceholderAtIndex: placeholder toRowId: rid]; // fill in where clause
		
		[updateStatement execute];
		[updateStatement reset];
		
		if (!rid) {
			rid = sqlite3_last_insert_rowid(connection);
			OPDebugLog(OPPERSISTENCE, OPINFO, @"Got new oid for %@ object: %lld", poClass, rid);
		}
	}
	return rid;
}

- (ROWID) insertNewRowForClass: (Class) poClass
/*" Creates an empty row and returns the rowid assigned by SQLite. "*/
{
	ROWID result;
	OPSQLiteStatement* insertStatement = [self insertStatementForClass: poClass];
	@synchronized(self) {
		[insertStatement execute];
		[insertStatement reset];
		result = sqlite3_last_insert_rowid(connection);
	}
	return result;
}

- (OPSQLiteStatement*) deleteStatementForClass:  (Class) poClass
{	
	OPSQLiteStatement* result;
	
	@synchronized(deleteStatements) {
		
		result = [deleteStatements objectForKey: poClass];
		
		if (!result) {
			
			NSString* queryString = [NSString stringWithFormat: @"delete from %@ where ROWID=?;", [[poClass persistentClassDescription] tableName]];
			
			result = [[OPSQLiteStatement alloc] initWithSQL: queryString connection: self]; 
			
			NSAssert2(result, @"Could not prepare statement (%@): %@", queryString, [self lastError]);
			
			[deleteStatements setObject: result forKey: poClass];
		}
	}
	return result;
}

- (void) deleteRowOfClass: (Class) poClass 
					rowId: (ROWID) rid
{
	OPSQLiteStatement* result = [self deleteStatementForClass: poClass];
		
	@synchronized(self) {
		[result reset];
		[result bindPlaceholderAtIndex: 0 toRowId: rid];
		[result execute];
		[result reset];
	}
}


- (void) dealloc
{
    [self close];
    [dbPath release];
	[dbName release];
    [super dealloc];
}

- (BOOL) open
{
	BOOL result = YES;
	if (!connection) {
		@synchronized(self) {
			OPDebugLog(OPPERSISTENCE, OPINFO, @"Opening database at '%@'.", dbPath);
			// Comment next three lines to disable statement caching:
			updateStatements = [[NSMutableDictionary alloc] initWithCapacity: 10];
			insertStatements = [[NSMutableDictionary alloc] initWithCapacity: 10];
			fetchStatements  = [[NSMutableDictionary alloc] initWithCapacity: 10];
			deleteStatements = [[NSMutableDictionary alloc] initWithCapacity: 10];
			
			result = SQLITE_OK==sqlite3_open([dbPath UTF8String], &connection);
		}
	}
	return result;
}

- (void) close
{
    if (!connection) return;
    	
    sqlite3_close(connection);
    connection = NULL;
	
	[updateStatements release]; updateStatements = nil; 
	[insertStatements release]; insertStatements = nil; 
	[deleteStatements release]; deleteStatements = nil; 
	[fetchStatements release];  fetchStatements  = nil; 
	
	[addRelationStatements release];    addRelationStatements    = nil;
	[removeRelationStatements release]; removeRelationStatements = nil;
}

- (NSString*) path
{
    return dbPath;
}

- (NSString*) name
{
	if (!dbName) {
		dbName = [[[dbPath lastPathComponent] stringByDeletingPathExtension] retain];
	}
	return dbName;
}


- (void) performCommand: (NSString*) sql
/*" A command is a SQL statement not returning rows. "*/
{
	@synchronized(self) {
		sqlite3_stmt* statement = NULL;
		sqlite3_prepare(connection, [sql UTF8String], -1, &statement, NULL);
		OPDebugLog(OPPERSISTENCE, OPINFO, @"SQL: Executing Command: '%@'", sql);
		int result = sqlite3_step(statement);
		sqlite3_reset(statement);
		if (result != SQLITE_DONE) {
			[self raiseSQLiteError];
		}
	}
}

- (BOOL) transactionInProgress
{
	return transactionInProgress;
}

- (BOOL) beginTransaction
/*" Does nothing, if a transaction is already in progress and returns NO. Returns YES, if a transaction was started. "*/
{
	if (!transactionInProgress) {
	//NSAssert(transactionInProgress==NO, @"Transaction already in progress.");
	//if (!transactionInProgress) {
	//OPDebugLog(OPPERSISTENCE, OPINFO, @"Beginning db transaction for %@", self);
	// Simplistic implementation. Should use a statement class/object and cache that:
		transactionInProgress = YES;
		[self performCommand: @"BEGIN TRANSACTION"];   
		return YES;
	}
	return NO;
}

- (void) commitTransaction
{
	NSAssert(transactionInProgress==YES, @"There seems to be no transaction to commit.");
	//OPDebugLog(OPPERSISTENCE, OPINFO, @"Committing db transaction for %@", self);
	// Simplistic implementation. Should use a statement class/object and cache that:
    [self performCommand: @"COMMIT TRANSACTION"];  
	transactionInProgress = NO;
}

- (void) rollBackTransaction
{
	if (transactionInProgress) {
		[self performCommand: @"ROLLBACK TRANSACTION"];   
		//OPDebugLog(OPPERSISTENCE, OPINFO, @"Rolled back db transaction.");
		transactionInProgress = NO;
	}
}

- (int) lastErrorNumber
{
	int result;
	@synchronized(self) {
		result = sqlite3_errcode(connection); 
	}
	return result;
}

- (NSString*) lastError
{
	NSString* result;
	@synchronized(self) {
		result = SQLITE_OK==sqlite3_errcode(connection) ? nil : [NSString stringWithUTF8String: sqlite3_errmsg(connection)];
	}
	return result;
}

/*

- (SQLResult*) performQuery:(NSString*) inQuery
{
    SQLResult*	sqlResult = nil;
    char**		results;
    int			result;
    int			columns;
    int			rows;
    
    if( !mDatabase )
        return nil;
    
    result = sqlite3_get_table( mDatabase, [inQuery cString], &results, &rows, &columns, NULL );
    if( result != SQLITE_OK )
    {
        sqlite3_free_table( results );
        return nil;
    }
    
    sqlResult = [[SQLResult alloc] initWithTable:results rows:rows columns:columns];
    if( !sqlResult )
        sqlite3_free_table( results );
    
    return sqlResult;
}

- (SQLTable*) tableWithName: (NSString*) tableName
{
    return [[SQLTable alloc] initWithDatabase: self name: tableName];
}

- (SQLResult*) performQueryWithFormat:(NSString*) inFormat, ...
{
    SQLResult*	sqlResult = nil;
    NSString*	query = nil;
    va_list		arguments;
    
    if( inFormat == nil )
        return nil;
    
    va_start( arguments, inFormat );
    
    query = [[NSString alloc] initWithFormat:inFormat arguments:arguments];
    sqlResult = [self performQuery:query];
    [query release];
    
    va_end( arguments );
    
    return sqlResult;
}

*/

@end

@implementation NSString (OPSQLiteSupport)

+ (BOOL) canPersist
{
	return YES; 
}

- (void) bindValueToStatement: (sqlite3_stmt*)  statement index: (int) index
{
    NSParameterAssert(statement != NULL);
    NSParameterAssert(index >= 0);
    
	const char* utf8 = [self UTF8String];
	int result = sqlite3_bind_text(statement, index, utf8, -1, SQLITE_TRANSIENT); // todo: optimize away copying!
	NSAssert(result == SQLITE_OK, @"Failed to bind string in statement.");
}

@end

@implementation NSMutableString (OPSQLiteSupport)

+ (BOOL) canPersist
{
	return NO;
}

@end


@implementation NSAttributedString (OPSQLiteSupport)

+ (BOOL) canPersist
{
	return YES; 
}


- (void) bindValueToStatement: (sqlite3_stmt*)  statement index: (int) index
{
	NSData* stringData = [self RTFFromRange: NSMakeRange(0,[self length]) documentAttributes: nil];
	[stringData bindValueToStatement: statement index: index];
}

+ (id) newFromStatement: (sqlite3_stmt*) statement index: (int) index
{
	NSError* error = nil;
	NSData* stringData = [NSData newFromStatement: statement index: index];
	NSAttributedString* result = nil;
	if ([stringData length]) {
		result = [[[NSAttributedString alloc] initWithData: stringData options: nil documentAttributes: nil error: &error] autorelease];
		if (error) NSLog(@"Warning! Unable to deserialize attr. string: %@", error);
	}
	return result;
}


@end

@implementation NSMutableAttributedString (OPSQLiteSupport)

+ (BOOL) canPersist
{
	return NO;
}

@end




@implementation NSObject (OPSQLiteSupport)

+ (BOOL) canPersist
	/*" Returns NO. General objects cannot persist. Persistent subclasses override this. "*/
{
	return NO;
}


+ (id) newFromStatement: (sqlite3_stmt*) statement index: (int) index
/*" Returns an autoreleased instance, initialized with the sqlite column value at the sepcified index. Defaults to a string. "*/
{
	id result = nil;
	int type = sqlite3_column_type(statement, index);
	if (type!=SQLITE_NULL) {
		const char* utf8TextResult = (char*)sqlite3_column_text(statement, index);
		if (utf8TextResult) {
			result = [NSString stringWithUTF8String: utf8TextResult];
		}
	}
    return result;
}

- (void) bindValueToStatement: (sqlite3_stmt*)  statement index: (int) index
{
	assert(0);
}

@end



@implementation NSNumber (OPSQLiteSupport)

+ (BOOL) canPersist
{
	return YES;
}

+ (id) newFromStatement: (sqlite3_stmt*) statement index: (int) index
{
    id result = nil;
    int type = sqlite3_column_type(statement, index);
    //SQLITE_INTEGER, SQLITE_FLOAT, SQLITE_TEXT, SQLITE_BLOB, SQLITE_NULL
    if (type!=SQLITE_NULL) {
        if (type==SQLITE_FLOAT) {
            result = [NSNumber numberWithDouble: sqlite3_column_double(statement, index)];
        } else if (type==SQLITE_INTEGER) {
            long long value = sqlite3_column_int64(statement, index);
            result = value<(2^31) ? [NSNumber numberWithInt: value] : [NSNumber numberWithLongLong: value]; // who knows about Cocoa's implementation?
        } else {
            NSLog(@"Warning: Typing Error. Number expected, got sqlite type #%d. Value ignored.", type);
        }
    }
    return result;
}

- (void) bindValueToStatement: (sqlite3_stmt*)  statement index: (int) index
{
    int type = sqlite3_column_type(statement, index);
    //SQLITE_INTEGER, SQLITE_FLOAT, SQLITE_TEXT, SQLITE_BLOB, SQLITE_NULL
    if (type!=SQLITE_NULL) {
        if (type==SQLITE_FLOAT) {
			sqlite3_bind_double(statement, index, [self doubleValue]);
        } else {
			sqlite3_bind_int64(statement, index, [self longLongValue]);
			//sqlite3_bind_null(<#sqlite3_stmt * #>,<#int #>)
		} 
		/*else {
			NSLog(@"Warning! column type not handeled for save!");	
		}*/
	}
}

@end

@implementation NSDate (OPSQLiteSupport)

+ (BOOL) canPersist
{
	return YES;
}

+ (id) newFromStatement: (sqlite3_stmt*) statement index: (int) index
{
    id result = nil;
    int type = sqlite3_column_type(statement, index);
    //SQLITE_INTEGER, SQLITE_FLOAT, SQLITE_TEXT, SQLITE_BLOB, SQLITE_NULL
    if (type!=SQLITE_NULL) {
        double value = sqlite3_column_double(statement, index);
		
        result = [self dateWithTimeIntervalSinceReferenceDate: value];
    }
    return result;
}

- (void) bindValueToStatement: (sqlite3_stmt*)  statement index: (int) index
{
	sqlite3_bind_double(statement, index, [self timeIntervalSinceReferenceDate]);
}

@end 

@implementation NSData (OPSQLiteSupport)

+ (BOOL) canPersist
{
	return YES;
}

+ (id) newFromStatement: (sqlite3_stmt*) statement index: (int) index
{
    id result = nil;
    int type = sqlite3_column_type(statement, index);
    if (type!=SQLITE_NULL) {
        NSAssert2(type==SQLITE_BLOB, @"SQLite type error. Expected #%d, got #%d.", SQLITE_BLOB, type);
        const void* bytes = sqlite3_column_blob(statement, index);
        int byteCount = sqlite3_column_bytes(statement, index);
        result = [NSData dataWithBytes: bytes length: byteCount];
    }
    return result;
}

- (void) bindValueToStatement: (sqlite3_stmt*)  statement index: (int) index
{
	int result = sqlite3_bind_blob(statement, index, [self bytes], [self length], SQLITE_TRANSIENT);
	NSAssert(result == SQLITE_OK, @"Failed to bind data in statement.");
}

@end



