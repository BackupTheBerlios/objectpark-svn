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

@implementation OPSQLiteConnection


+ (void) initialize
{
}

- (void) raiseSQLiteError
{
	NSLog(@"SQLite function returned with an error: %@", [self lastError]);
	
	[NSException raise: @"OPSQLiteError" 
				format: @"Error executing a sqlite function: %@", [self lastError]];
	// todo: include error number!
}


- (sqlite3*) database
{
    return connection;
}

- (id) initWithFile: (NSString*) inPath
{
    if(self = [super init]) {
    
        dbPath     = [inPath copy];
        connection = NULL;	
    }
    return self;
}

- (OPClassDescription*) descriptionForClass: (Class) poClass
// this method should go away!
{
	id result = [poClass persistentClassDescription];
	[result createStatementsForConnection: self];
	return result;
	/*
	if (!result) {
		// Create and cache the classDescription:
		result = [[[OPClassDescription alloc] initWithPersistentClass: poClass] autorelease];
		//NSLog(@"Created ClassDescription %@", result);
		[result createStatementsForConnection: self]; // create necessary SQL-Statements
		[classDescriptions setObject: result forKey: poClass];
	}
	return result;
	 */
}


- (NSDictionary*) attributesForRowId: (ROWID) rid
							 ofClass: (Class) persistentClass
{
    NSMutableDictionary* result = nil;
	OPClassDescription* cd = [self descriptionForClass: persistentClass];
    OPSQLiteStatement* statement = [self fetchStatementForClass: persistentClass];
		
	[statement reset];
	[statement bindPlaceholderAtIndex: 0 toRowId: rid];
	
    if ([statement execute] == SQLITE_ROW) {
		// We got a raw row, loop over all attributes and create a dictionary:
		
		NSArray* attributes = cd->attributeDescriptions;
        int attrCount = [attributes count];
        int i = 0;
		//NSLog(@"Processing attributeDescriptions %@", attributes);
        result = [NSMutableDictionary dictionaryWithCapacity: attrCount];
		NSAssert2(sqlite3_column_count([statement stmt])>=attrCount, @"Not enough columns returned. Expected %d, got %d", 
				  attrCount, sqlite3_column_count([statement stmt]));
		//NSLog(@"Got %d column return.", sqlite3_column_count([statement stmt]));
        while (i<attrCount) {
			OPAttributeDescription* desc = [attributes objectAtIndex: i];
			id value = [desc->theClass newFromStatement: [statement stmt] index: i];
			//NSLog(@"Read attribute %@ (%@): %@",desc->name, desc->theClass, value);
			if (value) {
				[result setObject: value forKey: desc->name];
			} 
			
            i++;
        }
    } 
    return result;
}

/*

- (sqlite3_stmt*) statementForClass: (Class) object
							 forId: (ROWID) rid
					   relationship: (NSString*) key
{
	OPClassDescription* cd = [self descriptionForClass: poClass];

	
	
	OPAttributeDescription* ad = [cd attributeDescriptionWithName: key];
	
	sqlite3_stmt* statement = [ad fetchStatement];
	if 
	
	
}

*/

- (OPSQLiteStatement*) updateStatementForClass: (Class) poClass
{
	OPSQLiteStatement* result = [updateStatements objectForKey: poClass];
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
		
		[updateStatements setObject: result forKey: poClass]; // cache it
		
	}
	return result;
}

- (OPSQLiteStatement*) fetchStatementForClass: (Class) poClass
{
	OPSQLiteStatement* result = [fetchStatements objectForKey: poClass];
	
	if (!result) {
		// Create statement using class description and cache it in the updateStatements dictionary:
		OPClassDescription* cd = [poClass persistentClassDescription];
		
		NSString* queryString = [NSString stringWithFormat: @"select %@ from %@ where ROWID=?;", [[cd columnNames] componentsJoinedByString: @","], [cd tableName]];
		NSLog(@"Preparing statement for fetches: %@", queryString);
		result = [[[OPSQLiteStatement alloc] initWithSQL: queryString connection: self] autorelease];
		
		[fetchStatements setObject: result forKey: poClass]; // cache it

	}
	return result;
}


- (ROWID) updateRowOfClass: (Class) poClass
					 rowId: (ROWID) rid
					values: (NSDictionary*) values
/*" Returns a new row id, if rid was 0. "*/
{
	
	OPClassDescription* cd = [self descriptionForClass: poClass];
	NSArray* attributeKeys = [cd attributeNames];
	OPSQLiteStatement* updateStatement = [self updateStatementForClass: poClass];		
	
	int attrCount = [attributeKeys count];
	int i;

	for (i=0; i<attrCount; i++) {
		NSString* key = [attributeKeys objectAtIndex: i];
		id value = [values objectForKey: key];
		//NSLog(@"Binding value %@ to attribute %@ of update statement.", value, key);
		[updateStatement bindPlaceholderAtIndex: i toValue: value];
	}
	[updateStatement bindPlaceholderAtIndex: i toRowId: rid]; // fill in where clause
	
	[updateStatement execute];
	[updateStatement reset];

	if (!rid) {
		rid = sqlite3_last_insert_rowid(connection);;
		NSLog(@"Got new oid for %@ object: %lld", poClass, rid);
	}
	return rid;
}

- (ROWID) insertNewRowForClass: (Class) poClass
{
	sqlite3_stmt* insertStatement = [[self descriptionForClass: poClass] insertStatement];
	int result = sqlite3_step(insertStatement);
	if (result!=SQLITE_DONE) [self raiseSQLiteError];

	sqlite3_reset(insertStatement);
	return sqlite3_last_insert_rowid(connection);
}

- (void) deleteRowOfClass: (Class) poClass 
					rowId: (ROWID) rid
{
	sqlite3_stmt* deleteStatement = [[self descriptionForClass: poClass] deleteStatementForRowId: rid];
	int result = sqlite3_step(deleteStatement);

	if (result != SQLITE_DONE) {
		[self raiseSQLiteError];
	}
	
}

/*
- (id) init
{
    if( ![super init] )
        return nil;
    
    mPath = NULL;
    mDatabase = NULL;
    
    return self;
}
*/

- (void) dealloc
{
    [self close];
    [dbPath release];
    [super dealloc];
}

- (BOOL) open
{
    NSLog(@"Opening database at '%@'.", dbPath);
	updateStatements = [[NSMutableDictionary alloc] initWithCapacity: 10];
	insertStatements = [[NSMutableDictionary alloc] initWithCapacity: 10];
	deleteStatements = [[NSMutableDictionary alloc] initWithCapacity: 10];
	fetchStatements = [[NSMutableDictionary alloc] initWithCapacity: 10];
	
    return SQLITE_OK==sqlite3_open([dbPath UTF8String], &connection);
}

- (void) close
{
    if(!connection) return;
    	
    sqlite3_close(connection);
    connection = NULL;
	
	[updateStatements release]; updateStatements = nil; 
	[insertStatements release]; insertStatements = nil; 
	[deleteStatements release]; deleteStatements = nil; 
	[fetchStatements release];  fetchStatements  = nil; 
	
}

- (NSString*) path
{
    return dbPath;
}

- (void) performCommand: (NSString*) sql
/*" A command is a SQL statement not returning rows. "*/
{
	// Simplistic implementation. Should use a statement class/object and cache that.
	sqlite3_stmt* statement = NULL;
	sqlite3_prepare(connection, [sql UTF8String], -1, &statement, NULL);
	int result = sqlite3_step(statement);
	if (result != SQLITE_DONE) {
		[self raiseSQLiteError];
	}
}

- (void) beginTransaction
{
	if (!transactionInProgress) {
		[self performCommand: @"BEGIN TRANSACTION"];   
		NSLog(@"Beginning db transaction.");
		transactionInProgress = YES;
	}
}

- (void) commitTransaction
{
	NSAssert(transactionInProgress, @"There seems to be no transaction to commit.");
    [self performCommand: @"COMMIT TRANSACTION"];  
	NSLog(@"Committing db transaction.");
	transactionInProgress = NO;
}

- (void) rollBackTransaction
{
	if (transactionInProgress) {
		[self performCommand: @"ROLLBACK TRANSACTION"];   
		NSLog(@"Rolled back db transaction.");
		transactionInProgress = NO;
	}
}

- (int) lastErrorNumber
{
    return sqlite3_errcode(connection); 
}

- (NSString*) lastError
{
    return SQLITE_OK==sqlite3_errcode(connection) ? nil : [NSString stringWithUTF8String: sqlite3_errmsg(connection)];
}

/*

- (SQLResult*)performQuery:(NSString*)inQuery
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

- (SQLResult*)performQueryWithFormat:(NSString*)inFormat, ...
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

- (SQLStatement*) statementWithFormat: (NSString*) format
{
    return [SQLStatement statementWithFormat: format database: self];
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

@implementation NSMutableData (OPSQLiteSupport)

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

+ (NSString*) prefetchedDatabaseColumns
	/*" A comma-separated list of database column names to fetch. Those can be accessed in +newFromStatement at index two and up in a OPPersistentObject subclass to initialize instance variables. Can be used for sorting fault objects. "*/
{
	return @"";
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
        } else if (type==SQLITE_INTEGER) {
			sqlite3_bind_int64(statement, index, [self longLongValue]);
		}
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
        long long value = sqlite3_column_int64(statement, index);
		
        result = [self dateWithTimeIntervalSinceReferenceDate: value];
    }
    return result;
}

- (void) bindValueToStatement: (sqlite3_stmt*)  statement index: (int) index
{
	sqlite3_bind_int64(statement, index, (long long)[self timeIntervalSinceReferenceDate]);
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

@end




@implementation OPSQLiteStatement

- (id) initWithSQL: (NSString*) sql connection: (OPSQLiteConnection*) aConnection 
{
	if (self = [super init]) {
		
		int res = sqlite3_prepare([aConnection database], [sql UTF8String], -1, &statement, NULL);
		
		if (res!=SQLITE_OK || !statement) {
			NSLog(@"Error preparing sql statement %@ '%@': %@", self, sql, [connection lastError]);
			[self autorelease];
			return nil;
		}
		connection = [aConnection retain];
		
	}
	return self;
}

- (void) bindPlaceholderAtIndex: (int) index toValue: (id) value
/*" Index is zero-based. "*/
{
	index++;
	if (value) {
		[value bindValueToStatement: statement index: index];
	} else {
		sqlite3_bind_null(statement, index);
	}
}

- (void) bindPlaceholderAtIndex: (int) index toRowId: (ROWID) rid
{
	index++;
	if (rid) {
		sqlite3_bind_int64(statement, index, rid);
	} else {
		sqlite3_bind_null(statement, index);
	}
}

- (void) reset
{
	sqlite3_reset(statement);
}

- (void) dealloc
{
	sqlite3_finalize(statement);
	[connection release];
	[super dealloc];
}

- (sqlite3_stmt*) stmt
{
	return statement;
}

- (int) execute
/*" Raises exception on error. "*/
{
	int result = sqlite3_step(statement);
		
	if (result != SQLITE_DONE && result != SQLITE_ROW) {
		[connection raiseSQLiteError];
	}	
	return result;
}

@end