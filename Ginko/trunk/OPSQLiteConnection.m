//
//  OPSQLiteConnection.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 22.07.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "OPSQLiteConnection.h"
#import "OPClassDescription.h"
//#import "OPAttributeDescription.h"

@implementation OPSQLiteConnection


+ (void) initialize
{
}

- (void) raiseSQLiteError
{
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
		classDescriptions = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (OPClassDescription*) descriptionForClass: (Class) poClass
{
	OPClassDescription* result = [classDescriptions objectForKey: poClass];
	if (!result) {
		// Create and cache the classDescription:
		result = [[[OPClassDescription alloc] initWithPersistentClass: poClass] autorelease];
		NSLog(@"Created ClassDescription %@", result);
		[result createStatementsForConnection: self]; // create necessary SQL-Statements
		[classDescriptions setObject: result forKey: poClass];
	}
	return result;
}


- (NSDictionary*) attributesForOid: (OID) oid
						   ofClass: (Class) persistentClass
{
    NSMutableDictionary* result = nil;
	OPClassDescription* cd = [self descriptionForClass: persistentClass];
    sqlite3_stmt* statement = [cd fetchStatementForRowId: oid];

    if (sqlite3_step(statement) == SQLITE_ROW) {
        
		// We got a raw row, loop over all attributes and create a dictionary:
		
		NSArray* attributes = cd->attributeDescriptions;
        int attrCount = [attributes count];
        int i = 0;
		NSLog(@"Processing attributeDescriptions %@", attributes);
        result = [NSMutableDictionary dictionaryWithCapacity: attrCount];
        while (i<attrCount) {
            OPAttributeDescription* desc = [attributes objectAtIndex: i];
            id value = [desc->theClass newFromStatement: statement index: i];
            NSLog(@"Read attribute %@ (%@): %@",desc->name, desc->theClass, value);
            if (value) {
                [result setObject: value forKey: desc->name];
            } else {
                NSLog(@"No value for attribute %@", desc);
            }
            i++;
        }
    } else {
        NSLog(@"*** SQLite error: %@", [self lastError]);  
    }
    return result;
}

- (void) updateObject: (OPPersistentObject*) object
{
	sqlite3_stmt* insertStatement = [[self descriptionForClass: [object class]] insertStatementForObject: object];	
	int result = sqlite3_step(insertStatement);
	
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
	[classDescriptions release];
    [super dealloc];
}

- (BOOL) open
{
    NSLog(@"Opening database at '%@'.", dbPath);
    return SQLITE_OK==sqlite3_open([dbPath UTF8String], &connection);
}

- (void) close
{
    if(!connection) return;
    
    sqlite3_close(connection);
    connection = NULL;
}

- (NSString*) path
{
    return dbPath;
}

- (unsigned long long) lastInsertedRowId
{
    return (unsigned long long) sqlite3_last_insert_rowid(connection);
}

- (void) performCommand: (NSString*) sql
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
    [self performCommand: @"BEGIN TRANSACTION"];   
}

- (void) commitTransaction
{
    [self performCommand: @"COMMIT TRANSACTION"];   
}

- (void) rollBackTransaction
{
    [self performCommand: @"ROLLBACK TRANSACTION"];   
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
{
	return NO; // General objects cannot persist. Subclasses change this.
}

+ (id) newFromStatement: (sqlite3_stmt*) statement index: (int) index
/*" Returns an autoreleased instance, initialized with the sqlite column value at the sepcified index. Defaults to a string. "*/
{
    const char* utf8TextResult = (char*)sqlite3_column_text(statement, index);
    id result = nil;
    if (utf8TextResult) {
        result = [NSString stringWithUTF8String: utf8TextResult];
    }
    return result;
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
