//
//  $Id:OPLog.m$
//  OPDebug
//
//  Created by Jörg Westheide on 11.07.2005.
//  Copyright 2005 Objectpark.org. All rights reserved.
//

#import "OPLog.h"
#import "NSThread+OPThreadNames.h"


@implementation OPLog : NSObject
/*"The OPLog class provides a mechanism to control the extent of information logged.
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
   
   #Example:
   
   !{OPDebugLog(@"some domain", OPERROR, @"This is the log message format");}
   
   To specify which messages should be logged one has to tell the logger
   (retrieved by the #{!{+sharedInstance}} method)
   which %aspects are active for which %domain (default is none).
   This is done either with the #{!{-setAspects:forDomain:}} method or with the
   #{!{-addAspects:forDomain:}} method which can also be used activate an aspect
   independent of what other aspects have been activated.
   
   #Example:
   
   !{[[OPDebugLog sharedInstance] setAspects:OPXERROR|OPERROR forDomain:@"Some Domain"];}
   
   If you are familiar with (hierarchical) debug levels and are missing them
   you can easily create them by activating all aspects that are relevant for
   the level in question (like in the above example).
   "*/


static OPLog *sharedInstance;

/*"Returns the single instance of the logger object."*/
+ (OPLog*) sharedInstance
    {
    if (!sharedInstance)
        sharedInstance = [[self alloc] init];
        
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
    
    
/*"This method examines the environment for variables starting with a prefix 
   defined by !{OPDebugLogEnvPrefix}.
   It then treats the rest of the name as the domain which is looked up in the
   domains dictionary specified in the definitions file at path.
   If the domain does not exist in the dictionary the environment variable is
   ignored.
   Otherwise the value of the variable is interpreted as a comma separated list 
   (surrounding white space is allowed) of values which are looked up in the 
   aspects dictionary of the definition file.
   If it is found its associated (numeric) aspects are added to the domain.
   If not the value is compared to the aspect names predefined in OPLog.h
   (!{OPINFO}, !{OPWARNING}, !{OPERROR}, !{OPXERROR}, !{OPNONE}, or !{OPALL})
   and if it matches the corresponding aspect is added.
   As a last resort the value of the environment variable is interpreted as a
   numerical value (decimal or hex representation allowed) and added as aspect 
   if successful.
   If that fails the environment variable is ignored.
   
   Returns !{NO} if the definitions file could not be read (file error or not a
   valid plist), !{YES} otherwise.
   
   #{Examples:}
   
   _{Environment: !{OPDL_MyDomain1=OPINFO}}
   _{Domains-dictionary: !{{\}}}
   
   The environment variable is ignored since there is no definition for
   MyDomain1 in the domains dictionary
   
   _{Environment: !{OPDL_MyDomain1=OPXERROR,OPERROR}}
   _{Domains-dictionary: !{{MyDomain1 = MyBasicDomain; \}}}
   
   The aspects !{OPXERROR} and !{OPERROR} are added to the active aspects of 
   domain MyBasicDomain.
   
   _{Environment: !{OPDL_MyDomain2=0x00000100}}
   _{Domains-dictionary: !{{MyDomain2 = MySpartanicDomain; \}}}
   
   The aspect 256 (0x100) is added to the active aspects of domain
   MySpartanicDomain.
   
   _{Environment: !{OPDL_MyDomain3=MyAspect}}
   _{Domains-dictionary: !{{MyDomain3 = MyFantasticDomain; \}}}
   _{Aspects-dictionary is !{{MyAspect = 256; \}}}

   The aspect 256 (0x100) is added to the active aspects of domain
   MyFantasticDomain.
   
   OK, but look at this one:
   
   _{Environment: !{OPDL_MyDomain4=OPALL}}
   _{Domains-dictionary: !{{MyDomain4 = MyWeirdDomain; \}}}
   _{Aspects-dictionary: !{{OPALL = 7; \}}}
   The aspects 1, 2, and 4 are added to the active aspects of domain
   MyWeirdDomain.
   
   Why this?
   
   OPALL is a predefined value (associated with -1).
   But since it is also defined in the aspects dictionary this definition takes
   precedence over the predefined one. The value is 7 which is 1+2+4 and as
   aspects correlate to bits, adding an aspect value of 7 means adding the three
   aspects 1, 2, and 4.
   
   #{The definitions file:}
   
   The definitions file is a plist file containing the following structure
   (nested dictionaries):
   
   !{{domains = {MyDomain1 = MyBasicDomain; }; aspects = {MyAspect = 256}; }};
   
   The easiest way to create such a plist file is to mark all your domain
   \#defines in the project with the !{OPL_DOMAIN} marker between the name and
   its associated value (e.g. !{\#define MyDomain1 OPL_DOMAIN @"MyBasicDomain"})
   and all aspect definitions with the !{OPL_ASPECT} marker (e.g. 
   !{\#define MyAspect OPL_ASPECT 256}), and then run the !{extractAspects.pl}
   script provided in the resources folder. It is designed to be quite fast so
   you can run it from a shell script phase during the build process which will
   automatically update your definitions on every build.
   "*/
- (BOOL) addAspectsFromEnvironmentWithDefinitionsFromFile:(NSString*)path
    {
    NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:[path stringByExpandingTildeInPath]];
    if (config == nil)
        {
        NSLog(@"Config file '%@' not found!?!", [path stringByExpandingTildeInPath]);
        return NO;
        }
    
    NSDictionary *domainDefs = [config objectForKey:@"domains"];
    NSDictionary *aspectDefs = [config objectForKey:@"aspects"];
    
    NSDictionary *env = [[NSProcessInfo processInfo] environment];
    NSString *varName;
    
    NSEnumerator *envVars = [env keyEnumerator];
    while (varName = [envVars nextObject])
        {
        if ([varName hasPrefix:OPDebugLogEnvPrefix])
            {
            NSString *domainName  = [varName substringFromIndex:[OPDebugLogEnvPrefix length]];
            NSString *domainValue = [domainDefs objectForKey:domainName];
            
            if (domainValue == nil)
                continue;
                
            NSString *aspectName; //   = [[env objectForKey:varName] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSEnumerator *aspectNames  = [[[env objectForKey:varName] componentsSeparatedByString:@","] objectEnumerator];
            while (aspectName = [[aspectNames nextObject] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]])
                {
                NSNumber *aspectValue = [aspectDefs objectForKey:aspectName];
                
                long value = 0;
                
                // value from successfull lookup
                if (aspectValue)
                    value = [aspectValue intValue];
                    
                // predefined aspect names
                else if ([aspectName isEqualToString:@"OPALL"])
                    value = OPALL;
                else if ([aspectName isEqualToString:@"OPINFO"])
                    value = OPINFO;
                else if ([aspectName isEqualToString:@"OPWARNING"])
                    value = OPWARNING;
                else if ([aspectName isEqualToString:@"OPERROR"])
                    value = OPERROR;
                else if ([aspectName isEqualToString:@"OPXERROR"])
                    value = OPXERROR;
                else if ([aspectName isEqualToString:@"OPNONE"])
                    value = OPNONE;
                    
                // numerical values
                else if ([aspectName hasPrefix:@"0x"] && [[NSScanner scannerWithString:aspectName] scanHexInt:(unsigned*) &value])
                    /*NSLog(@"Found hex number with value %d", value)*/;
                else if ([[NSScanner scannerWithString:aspectName] scanInt:(int*) &value])
                    /*NSLog(@"Found dez number with value %d", value)*/;
                else
                
                // unknown aspects
                    {
                    NSLog(@"Ignoring unknown aspect value %@ for log domain %@.", aspectName, domainName);
                    continue;
                    }
                    
                NSLog(@"Adding aspect %@ (0x%x) for domain %@", aspectName, value, domainValue);
                [self addAspects:value forDomain:domainValue];
                }
            }
        }
        
    return YES;
    }
    
    
/*"Does the actual logging (of aMessage)."*/
- (void) log:(NSString*)aMessage
    {
    NSLog(@"[%@] %@", [[NSThread currentThread] name], aMessage);
    }
    
    
/*""*/
- (NSString*) description
    {
    return [NSString stringWithFormat:@"<OPLog 0x%x, settings: %@>", self, settings];
    }
@end
