//
//  OPSQLiteConnection.h
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

#import <AppKit/AppKit.h>
#include <sqlite3.h>
#import "OPPersistenceConstants.h"

@class OPPersistentObject;
@class OPSQLiteStatement;
@class OPAttributeDescription;

@interface OPSQLiteConnection : NSObject {
    
    sqlite3* connection;
    NSString* dbPath;
    NSString* dbName;

	BOOL transactionInProgress;
	
	NSMutableDictionary* insertStatements; // keyed by Class
	NSMutableDictionary* updateStatements; // keyed by Class
	NSMutableDictionary* deleteStatements; // keyed by Class
	NSMutableDictionary* fetchStatements;  // keyed by Class
	
	NSMutableDictionary* fetchRelationStatements; // not used yet
	
	NSMutableDictionary* addRelationStatements; // keyed by JoinTableName
	NSMutableDictionary* removeRelationStatements; // keyed by JoinTableName
	
}

- (sqlite3*) database;

- (id) initWithFile: (NSString*) inPath;

- (BOOL) open;
- (void) close;
- (NSString*) path;
- (NSString*) name; 

- (BOOL) beginTransaction;
- (void) commitTransaction;
- (void) rollBackTransaction;
- (BOOL) transactionInProgress;

- (ROWID) insertNewRowForClass: (Class) poClass;

- (OPSQLiteStatement*) updateStatementForClass: (Class) poClass;
- (OPSQLiteStatement*) fetchStatementForClass: (Class) poClass;
- (OPSQLiteStatement*) addStatementForJoinTableName: (NSString*) joinTableName
									firstColumnName: (NSString*) firstColumnName 
								   secondColumnName: (NSString*) secondColumName;

- (OPSQLiteStatement*) removeStatementForJoinTableName: (NSString*) joinTableName
									   firstColumnName: (NSString*) firstColumnName 
									  secondColumnName: (NSString*) secondColumName;

- (int) lastErrorNumber;
- (NSString*) lastError;

- (void) performCommand: (NSString*) sql;

- (ROWID) updateRowOfClass: (Class) poClass
					 rowId: (ROWID) rid
					values: (NSDictionary*) values;

- (void) deleteRowOfClass: (Class) poClass 
					rowId: (ROWID) rid;

- (NSDictionary*) attributesForRowId: (ROWID) rid
							 ofClass: (Class) persistentClass;

- (OPSQLiteStatement*) fetchStatementForClass: (Class) poClass
										rowId: (ROWID) rid
								 relationship: (NSString*) key;

- (void) raiseSQLiteError; // for internal use only


@end

@interface NSObject (OPSQLiteSupport)

+ (BOOL) canPersist;

+ (id) newFromStatement: (sqlite3_stmt*) statement index: (int) index;
- (void) bindValueToStatement: (sqlite3_stmt*)  statement index: (int) index;

@end

@interface OPSQLiteStatement: NSObject {
	OPSQLiteConnection* connection;
	NSString* sqlString;
	@private sqlite3_stmt* statement;

}

+ (NSArray*) runningStatements;

- (void) bindPlaceholderAtIndex: (int) index toValue: (id) value;
- (void) bindPlaceholderAtIndex: (int) index toRowId: (ROWID) rid;

- (id) initWithSQL: (NSString*) sql connection: (OPSQLiteConnection*) connection;
- (int) execute;
- (void) reset;
//- (sqlite3_stmt*) stmt;


@end
