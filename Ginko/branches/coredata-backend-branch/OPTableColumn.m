/*
 $Id: OPTableColumn.m,v 1.1 2005/05/09 08:14:08 mikesch Exp $

 Copyright (c) 2003 by Axel Katerbau. All rights reserved.

 Permission to use, copy, modify and distribute this software and its documentation
 is hereby granted, provided that both the copyright notice and this permission
 notice appear in all copies of the software, derivative works or modified versions,
 and any portions thereof, and that both notices appear in supporting documentation,
 and that credit is given to Axel Katerbau in all documents and publicity
 pertaining to direct or indirect use of this code or its derivatives.

 THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
 SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
 "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
 DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
 OR OF ANY DERIVATIVE WORK.

 Further information can be found on the project's web pages
 at http://www.objectpark.org/Ginko.html
 */

#import "OPTableColumn.h"


@implementation OPTableColumn

- (id)dataCellForRow:(int)row
{
    id delegate;
    id result = nil;
    NSTableView *tv;

    tv = [self tableView];
    delegate = [tv delegate];
    
    if ([delegate respondsToSelector:@selector(tableView:dataCellForTableColumn:row:)])
    {
        if (row >= 0)
        {
            result = [delegate tableView:tv dataCellForTableColumn:self row:row];
        }
    }

    if (! result)
    {
        result = [super dataCellForRow:row];
    }

    return result;
}

@end
