/*
 $Id: GIContentPane.h,v 1.4 2005/03/10 14:31:27 theisen Exp $

 Copyright (c) 2002 by Dirk Theisen, Axel Katerbau. All rights reserved.

 Permission to use, copy, modify and distribute this software and its documentation
 is hereby granted, provided that both the copyright notice and this permission
 notice appear in all copies of the software, derivative works or modified versions,
 and any portions thereof, and that both notices appear in supporting documentation,
 and that credit is given to Dirk Theisen and Axel Katerbau in all documents and publicity
 pertaining to direct or indirect use of this code or its derivatives.

 THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
 SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
 "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
 DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
 OR OF ANY DERIVATIVE WORK.

 Further information can be found on the project's web pages
 at http://www.objectpark.org/Ginko.html
 */

#import <Foundation/Foundation.h>
#import <OPPreferences/OPPreferences.h>

@interface GIContentPane : OPPreferencePane 
{
    IBOutlet id tableView;
    IBOutlet id tableView2;
    IBOutlet id headersTableView;
    IBOutlet NSTextField *fontDescription;
        
    //@private NSArray*        _availableHeaders;
    //@private NSMutableArray* _displayedHeaders;
    //@private NSMutableArray* _additionalHeaders;
}

- (IBAction) restoreDefaultAction: (id) sender;
  //- (IBAction) reloadHeaderData: (id) sender;
- (IBAction) showFontPanelAction: (id) sender;

- (NSArray*) allAdditionalHeadersForDisplay;
- (NSArray*) additionalHeadersForDisplay;
- (void) setAdditionalHeadersForDisplay: (NSArray*) newHeaders;


@end
