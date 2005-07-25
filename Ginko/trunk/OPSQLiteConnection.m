//
//  OPSQLiteConnection.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 22.07.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "OPSQLiteConnection.h"


@implementation OPSQLiteConnection

#define MAX_PERSISTENT_CLASSES 50

static sqlite3_stmt* getAttributesStatements[MAX_PERSISTENT_CLASSES]; // warning! limit on number of persistent classes

+ (void) initialize
{
    // Clear statement cache:
    memset(getAttributesStatements, 0, MAX_PERSISTENT_CLASSES * sizeof(sqlite3_stmt*));
}

- (sqlite3*) database
{
    return connection;
}

- (id) initWithFile: (NSString*) inPath
{
    if(self = [super init]) {
    
        dbPath = [inPath copy];
        connection = NULL;
    }
    return self;
}

- (NSDictionary*) attributeDictForTable: (NSString*) tableName
                             attributes: (NSArray*) attrNames
                                   keys: (NSArray*) keys
                                  types: (NSArray*) types
                                    oid: (OID) oid
{
    NSMutableDictionary* attributes = nil;
    CID cid = CIDFromOID(oid);
    sqlite3_stmt* statement = getAttributesStatements[cid];
    if (!statement) {
        NSString* queryString = [NSString stringWithFormat: @"select %@ from %@ where ROWID=?;", [attrNames componentsJoinedByString: @","], tableName];
        NSAssert([attrNames count] == [keys count], @"key and attribute name arrays must match.");
        NSLog(@"Prepating statement for query: %@", queryString);
        sqlite3_prepare(connection, [queryString UTF8String], -1, &statement, NULL);
        if (!statement) NSLog(@"Error preparing statement: %@", [self lastError]);
        getAttributesStatements[cid] = statement; // cache it for later use
        NSLog(@"Created getAttribute-Statement 0x%x for table %@", statement, tableName);
    } else NSLog(@"Using cached statement.");
    sqlite3_reset(statement);
    sqlite3_bind_int64(statement, 1, LIDFromOID(oid));
    if (sqlite3_step(statement) == SQLITE_ROW) {
        
        int keyCount = [keys count];
        int i = 0;

        attributes = [NSMutableDictionary dictionaryWithCapacity: keyCount];
        while (i<keyCount) {
            NSString* key = [keys objectAtIndex: i];
            id value = [[types objectAtIndex: i] newFromStatement: statement index: i];
            NSLog(@"Read attribute %@ (%@): %@", key, [types objectAtIndex: i], value);
            if (value) {
                [attributes setObject: value forKey: key];
            } else {
                //NSLog(@"No value for key %@", key);
            }
            i++;
        }
    } else {
        NSLog(@"*** SQLite error: %@", [self lastError]);  
    }
    return attributes;
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

- (void) beginTransaction
{
    [self performQuery: @"BEGIN TRANSACTION"];   
}

- (void) commitTransaction
{
    [self performQuery: @"COMMIT TRANSACTION"];   
}

- (void) rollBackTransaction
{
    [self performQuery: @"ROLLBACK TRANSACTION"];   
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

@implementation NSObject (OPSQLiteSupport)

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
