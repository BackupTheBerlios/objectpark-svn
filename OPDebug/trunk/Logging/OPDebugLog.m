//
//  $Id:OPDebug.m$
//  OPNetwork
//
//  Created by Jörg Westheide on 11.07.2005.
//  Copyright 2005 Objectpark.org. All rights reserved.
//

#import "OPDebugLog.h"


static OPDebugLog *sharedInstance;


@implementation OPDebugLog : NSObject
/*"The OPDebugLog class provides a mechanism to control the extent of information logged.
   It utilizes !{NSLog} for logging and uses the !{NSDebugEnabled} variable as a global
   on-off switch so you need to set this variable.
   For logging independent of that variable you should use !{NSLog} directly.
   
   There are two items used for fine grained control of whether a message should be printed,
   %domains and %aspects:
   
   The %domain is intended to separate the parts of a project (subprojects or even finer).
   It can be any NSString.
   
   The %aspects allow for a fine grained specification of the messages that should be logged
   and are always used in conjunction with a domain.
   %Aspects are a bit vector with each bit representing a single aspect.
   
   In order to determine whether a message should be logged every log message has to be
   associated with a %domain and an %aspect.
   Therefore the !{OPDebugLog} function (macro) takes the %domain and the %aspect as its
   first two parameters, followed by a format for the message itself.
   
   Example:
   
   !{OPDebugLog(@"some domain", OPERROR, @"This is the log message format");}
   
   To specify which messages should be logged one has to tell the debug logger
   (retrieved by the !{+sharedInstance} method)
   which %aspects are active for which %domain (default is none).
   This is done either with the !{-setAspects:forDomain:} method or with the
   !{-addAspects:forDomain:} method which can also be used activate an aspect
   independent of what other aspects have been activated.
   
   Example:
   
   !{[[OPDebugLog sharedInstance] setAspects:OPXERROR|OPERROR forDomain:@"Some Domain"];}
   
   If you are familiar with (hierarchical) debug levels and are missing them
   you can easily create them by activating all aspects that are relevant for
   the level in question (like in the above example).
   "*/

/*"Returns the single instance of the debug logger object."*/
+ (OPDebugLog*) sharedInstance
    {
    if (!sharedInstance)
        sharedInstance = [[OPDebugLog alloc] init];
        
    return sharedInstance;
    }
    
    
/*"The designated initializer for instances."*/
- (id) init
    {
    if (self = [super init])
        settings = [[NSMutableDictionary alloc] init];
        
    return self;
    }
    

/*"Activates the logging of anAspect for aDomain in addition to the previously activated."*/
- (void) addAspects:(long)anAspect forDomain:(NSString*)aDomain
    {
    long aspects = [[settings objectForKey:aDomain] longValue];
    
    aspects |= anAspect;
    
    [settings setObject:[NSNumber numberWithLong:aspects] forKey:aDomain];
    }
    
    
/*"Dectivates the logging of anAspect for aDomain while not changing the setting for other aspects."*/
- (void) removeAspects:(long)anAspect forDomain:(NSString*)aDomain
    {
    long aspects = [[settings objectForKey:aDomain] longValue];
    
    aspects &= anAspect;
    
    [settings setObject:[NSNumber numberWithLong:aspects] forKey:aDomain];
    }
    
    
/*"Sets the active aspects for aDomain to aspect."*/
- (void) setAspects:(long)aspects forDomain:(NSString*)aDomain
    {
    [settings setObject:[NSNumber numberWithLong:aspects] forKey:aDomain];
    }
    
    
/*"Deactivates all aspects for aDomain."*/
- (void) removeAspectsForDomain:(NSString*)aDomain
    {
    [settings removeObjectForKey:aDomain];
    }
    
    
/*"Returns the current active aspects for aDomain."*/
- (long) aspectsForDomain:(NSString*)aDomain
    {
    return [[settings objectForKey:aDomain] longValue];
    }
    
    
@end
