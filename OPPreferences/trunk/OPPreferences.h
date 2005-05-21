//
//  OPPreferences.h
//
//  Created by Dirk Theisen on Sat Feb 02 2002.
//  Copyright (c) 2001 Dirk Theisen. All rights reserved.
//
/*
 Permission to use, copy, modify and distribute this software and its documentation
 is hereby granted, provided that both the copyright notice and this permission
 notice appear in all copies of the software, derivative works or modified versions,
 and any portions thereof, and that both notices appear in supporting documentation,
 and that credit is given to Bjoern Bubbat in all documents and publicity
 pertaining to direct or indirect use of this code or its derivatives.

 THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
 SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
 "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
 DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
 OR OF ANY DERIVATIVE WORK.

 Further information can be found on the project's web pages
 at http://www.objectpark.org/
 */


/*
 This classes are used to create a window with preference panes, similar to Apples  preferences windows. The window conatins a toolbar listing all active preference panes with icon (default icon included) and a descritive name,
 
 A filed called ActivePrefPanes.plist in the main bundle should contain a list of active preference panes, resepctive the names of a set of nib, image and OPPreference subclass forming a the named preference pane.
 
 The file content could look like this: 
 
   (GeneralPrefs, DisplayPrefs, AdditionalPrefs, OPLicensePrefs)
 
 */


#import "OPPreferencePane.h"
#import "NSApplicationOPPreferenceSupport.h"
#import "OPPreferenceController.h"
