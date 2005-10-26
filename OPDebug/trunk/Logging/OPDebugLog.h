//
//  $Id:OPDebug.h$
//  OPNetwork
//
//  Created by Jörg Westheide on 11.07.2005.
//  Copyright 2005 Objectpark.org. All rights reserved.
//

#import <Foundation/NSDebug.h>


/*"Disables logging for all aspects for a domain."*/
#define OPNONE      0
/*"Enables  logging for all aspects for a domain."*/
#define OPALL      -1

/*"A predefined aspect for informational messages."*/
#define OPINFO      1
/*"A predefined aspect for warning messages."*/
#define OPWARNING   2
/*"A predefined aspect for error messages."*/
#define OPERROR     4
/*"A predefined aspect for critical error messages."*/
#define OPXERROR    8


/*"This is the function (macro) used for logging.
   Domain and aspect describe the exact aspect that the log message format
   belongs to.
   The log message will only be output if !{NSDebugEnabled} is set and the
   aspect is set to active for the domain.

   Example:
   
   !{OPDebugLog(@"some domain", OPERROR, @"Operation xyz() returned error: %s", "ACCESS DENIED");}
   
   This will log the message 'Operation xyz() returned error: ACCESS DENIED' if
   the OPERROR aspect has been activated for the domain 'some domain'."*/
#define OPDebugLog(domain, aspects, format, ...)    {                                                                                        \
                                                    if (NSDebugEnabled)                                                                      \
                                                        {                                                                                    \
                                                        OPDebugLog *sharedInstance = [OPDebugLog sharedInstance];                            \
                                                        if ([sharedInstance aspectsForDomain:domain] & aspects)                              \
                                                            [sharedInstance log:[NSString stringWithFormat:[@"[%u] %@ (%s): " stringByAppendingString:format],         \
                                                                                              ((unsigned int*)[NSThread currentThread])[1],  \
                                                                                              domain, #aspects, ##__VA_ARGS__]];             \
                                                        }                                                                                    \
                                                    }

@interface OPDebugLog : NSObject
    {
    NSMutableDictionary* settings;  /*"is the dictionary holding the current settings of aspects for the domains"*/
    }

/*"Access to the logger"*/
+ (OPDebugLog*) sharedInstance;

/*"Modifying aspects settings"*/
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


