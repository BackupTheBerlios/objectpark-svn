//
//  OPClassDescription.h
//
//  Created by Dirk Theisen on 27.07.05.
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

#import <Cocoa/Cocoa.h>
#include <sqlite3.h>
#import "OPPersistenceConstants.h"

@class OPSQLiteConnection;
@class OPPersistentObject;
@class OPAttributeDescription;

@interface OPClassDescription : NSObject {
	@public
	Class persistentClass;
	NSArray* attributeDescriptions;
	NSString* columnList; // comma-separated list of column names	
}

- (id) initWithPersistentClass: (Class) poClass;

- (OPAttributeDescription*) attributeWithName: (NSString*) name;
- (NSArray*) allAttributes; 

- (NSString*) tableName;
//- (NSArray*) simpleAttributeNames;
- (NSMutableArray*) columnNames;



@end

#import <Cocoa/Cocoa.h>

@interface OPAttributeDescription : NSObject {
	@public // Made public for fast access only. Never change those. These objects are immutable.
	NSString* name;
	NSString* columnName;
	Class theClass; // The class to use for the attribute. Either NSString, NSNumber, NSData or NSDate or any OPPerstistentObject (subclass)
					// more stuff for relationships:
	Class targetClass; // for relationships
	NSString* foreignKeyColumnName; // for 1:n relationships 
	NSString* joinTableName;
	NSString* queryString;
}


- (id) initWithName: (NSString*) aName properties: (NSDictionary*) dict;
- (NSString*) queryString;
- (Class) attributeClass;
- (BOOL) isRelationship;


@end

@interface NSObject (OPClassDescription)

+ (OPClassDescription*) persistentClassDescription;

@end
