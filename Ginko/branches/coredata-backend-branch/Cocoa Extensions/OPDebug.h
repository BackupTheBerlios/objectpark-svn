/* 
     OPDebug.h created by theisen on Sat 19-Jan-2002
     $Id: OPDebug.h,v 1.1 2004/12/23 16:45:48 theisen Exp $

     Copyright (c) 2001 by Dirk Theisen. All rights reserved.

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
*/

#import <Foundation/NSDebug.h>

// Example Usage:
//
// OPDebugLog1(DefaultsDB, OPWARNING, @"Defaults DB field %@ not initialized", field);

//#warning Commandline parameter parsing currently unimplemented.

// Predefined log levels:
#define OPALL 0
#define OPINFO 20
#define OPWARNING 40
#define OPERROR 60
#define OPXERROR 80
#define OPNONE 120

// This one is only here for compatibility with MPWDebugLog 
// which can be replaced by ODebugLogX:
#define OPDebugLogX if (NSDebugEnabled) NSLog

extern void debug_init();
extern char*  op_debug_setting;
extern char** op_debug_domain;

#define OPDebugCondition(domain,level) if (NSDebugEnabled && op_debug_setting[domain]<=level)
//#define eprintf(args...) fprintf (stderr, args)

//#define OPCondLog(cond,args...) if(cond) NSLog(args)
//#define OPXDebugLog(domain, level, format,args...) if (NSDebugEnabled && op_debug_setting[domain]<=level) NSLog(@"%s %d (is %d)(%s): " format, #level, level, op_debug_setting[domain], #domain, args) 

#define OPDebugLog( domain, level, format)                                  { OPDebugCondition(domain,level) NSLog(@"%s (%s): " format, #level, #domain); }
#define OPDebugLog1(domain, level, format, par1)                            { OPDebugCondition(domain,level) NSLog(@"%s (%s): " format, #level, #domain, par1); }
#define OPDebugLog2(domain, level, format, par1, par2)                      { OPDebugCondition(domain,level) NSLog(@"%s (%s): " format, #level, #domain, par1, par2); }
#define OPDebugLog3(domain, level, format, par1, par2, par3)                { OPDebugCondition(domain,level) NSLog(@"%s (%s): " format, #level, #domain, par1, par2, par3); }
#define OPDebugLog4(domain, level, format, par1, par2, par3, par4)          { OPDebugCondition(domain,level) NSLog(@"%s (%s): " format, #level, #domain, par1, par2, par3, par4); }
#define OPDebugLog5(domain, level, format, par1, par2, par3, par4, par5)    { OPDebugCondition(domain,level) NSLog(@"%s (%s): " format, #level, #domain, par1, par2, par3, par4, par5); }

//#define DEFINE(var, val) #define var val\n

#define SETDEBUGLEVEL(domain, level) op_debug_setting[domain]=level;op_debug_domain[domain]=#domain; NSLog(@"Setting debuglevel of domain %s to %d.", #domain, level)

#include "DebugConfig.h"

// Provide some defaults...
#ifndef OPDEBUGDOMAINMAX
#define OPDEBUGDOMAINMAX 64
#endif
#ifndef OPDEBUGLEVELCONFIG
#define OPDEBUGLEVELCONFIG
#endif

// Inline code including two global variables
#define op_debug_init_code \
char*  op_debug_setting = NULL; \
char** op_debug_domain  = NULL; \
void debug_init() { \
    op_debug_setting = malloc(sizeof(char)*OPDEBUGDOMAINMAX); \
    op_debug_domain  = malloc(sizeof(char*)*OPDEBUGDOMAINMAX); \
    bzero(op_debug_domain, sizeof(char*)*OPDEBUGDOMAINMAX); \
    OPDEBUGLEVELCONFIG \
    OPDebugLog1(TESTDEBUG, OPALL, @"Objectpark debugging support %s.", "enabled"); \
    OPDebugLog(TESTDEBUG, OPINFO, @"This is an info test!"); \
    OPDebugLog(TESTDEBUG, OPWARNING, @"This is a warning test!"); \
    OPDebugLog(TESTDEBUG, OPERROR, @"This is a error test!"); \
    OPDebugLog(TESTDEBUG, OPXERROR, @"This is a critical error test!"); \
}




