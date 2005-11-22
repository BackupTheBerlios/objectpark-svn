//
//  $Id:OPLog.h$
//  OPDebug
//
//  Created by Jörg Westheide on 11.07.2005.
//  Copyright 2005 Objectpark.org. All rights reserved.
//

#import <Foundation/NSDebug.h>

/*"A marker for domains so they can be automatically extracted.
   In the code it just does nothing.
   Use it like this: !{\#define MyDomain OPL_DOMAIN @"MyDomain"}"*/
#define OPL_DOMAIN

/*"A marker for aspects so they can be automatically extracted.
   In the code it just does nothing.
   Use it like this: !{\#define MyAspect OPL_ASPECT 0x0815}"*/
#define OPL_ASPECT

/*"This string is required as a prefix for environment variables that should be
   used for setting aspects for a domain by 
   !{-addAspectsFromEnvironmentWithDefinitionsFromFile:}.
   E.g. !{setenv OPL_MyDomain=MyAspect}
   "*/
#define OPDebugLogEnvPrefix @"OPL_"


/*"Disables logging for all aspects for a domain."*/
#define OPNONE    OPL_ASPECT  0
/*"Enables  logging for all aspects for a domain."*/
#define OPALL     OPL_ASPECT -1

/*"A predefined aspect for informational messages."*/
#define OPINFO    OPL_ASPECT  0x10000000
/*"A predefined aspect for warning messages."*/
#define OPWARNING OPL_ASPECT  0x20000000
/*"A predefined aspect for error messages."*/
#define OPERROR   OPL_ASPECT  0x40000000
/*"A predefined aspect for critical error messages."*/
#define OPXERROR  OPL_ASPECT  0x80000000


/*"This is the function (macro) used for logging.
   Domain and aspect describe the exact aspect that the log message format
   belongs to.
   The log message will only be output if !{NSDebugEnabled} is set and the
   aspect is set to active for the domain.

   Example:
   
   !{OPDebugLog(@"some domain", OPERROR, @"Operation xyz() returned error: %s", "ACCESS DENIED");}
   
   This will log the message 'Operation xyz() returned error: ACCESS DENIED' if
   the OPERROR aspect has been activated for the domain 'some domain'."*/
#define OPDebugLog(domain, aspects, format, ...)    {                                                                                                          \
                                                    if (NSDebugEnabled)                                                                                        \
                                                        {                                                                                                      \
                                                        OPLog *sharedInstance = [OPLog sharedInstance];                                                        \
                                                        if ([sharedInstance aspectsForDomain:domain] & aspects)                                                \
                                                            [sharedInstance log:[NSString stringWithFormat:[@"[%u] %@ (%s): " stringByAppendingString:format], \
                                                                                              ((unsigned int*)[NSThread currentThread])[1],                    \
                                                                                              domain, #aspects, ##__VA_ARGS__]];                               \
                                                        }                                                                                                      \
                                                    }

@interface OPLog : NSObject
    {
    NSMutableDictionary* settings;  /*"is the dictionary holding the current settings of aspects for the domains"*/
    }

/*"Access to the logger"*/
+ (OPLog*) sharedInstance;

/*"Modifying aspects settings"*/
- (BOOL) addAspectsFromEnvironmentWithDefinitionsFromFile:(NSString*)path;
- (void) addAspects:(long)anAspect forDomain:(NSString*)aDomain;
- (void) removeAspects:(long)anAspect forDomain:(NSString*)aDomain;

/*"Specifying all aspects"*/
- (void) setAspects:(long)aspect forDomain:(NSString*)aDomain;
- (void) removeAspectsForDomain:(NSString*)aDomain;

/*"Inquiring domain aspects"*/
- (long) aspectsForDomain:(NSString*)aDomain;

/*"Logging"*/
- (void) log:(NSString*)aMessage;

@end


