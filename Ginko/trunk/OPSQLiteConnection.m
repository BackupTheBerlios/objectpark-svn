//
//  OPSQLiteConnection.m
//  GinkoVoyager
//
//  Created by Dirk Theisen on 22.07.05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "OPSQLiteConnection.h"


@implementation OPSQLiteConnection

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
                                    oid: (long long) oid
{
    NSString* queryString = [NSString stringWithFormat: @"select ROWID, %@ from %@ where ROWID = %d", [attrNames componentsJoinedByString: @","], tableName, oid];
    int keyCount = [keys count];
    NSLog(@"Will issue query: %@", queryString);
    NSMutableDictionary* attributes = [NSMutableDictionary dictionaryWithCapacity: keyCount];
    int i = 0;
    while (i<keyCount) {
        NSString* key = [keys objectAtIndex: i];
        
        id value = @"Need to fetch value.";
        
        [attributes setObject: value forKey: key];
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

- (long long) lastInsertedRowId
{
    return sqlite3_last_insert_rowid(connection);
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
