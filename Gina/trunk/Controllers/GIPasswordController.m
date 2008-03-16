//
//  GIPasswordController.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 10.06.05.
//  Copyright 2005 Objectpark Group. All rights reserved.
//

#import "GIPasswordController.h"
#import <Foundation/NSDebug.h>
#import "GIUserDefaultsKeys.h"
#import "GIApplication.h"
#import "GIAccount.h"


@implementation GIPasswordController

- (id)initWithParamenters:(NSMutableDictionary *)someParameters
{
    self = [super init];
    NSParameterAssert(someParameters != nil);
    
    account = [[someParameters objectForKey:@"account"] retain];
    isIncomingPassword = [[someParameters objectForKey:@"isIncoming"] boolValue];
    result = [[someParameters objectForKey:@"result"] retain];
    
    [NSBundle loadNibNamed:@"Password" owner:self];
    [self retain]; // balanced in -windowWillClose:
    
    return self;
}

- (void) dealloc
{
    [account release];
    [result release];
    [super dealloc];
}

- (NSString *)serverTypeString
{
    NSString *serverType = @"UNKNOWN";
    
    if (isIncomingPassword) 
	{
        switch([account incomingServerType]) 
		{
            case POP3:
                serverType = @"POP3";
                break;
            case POP3S:
                serverType = @"POP3S";
                break;
            case NNTP:
                serverType = @"NNTP";
                break;
            case NNTPS:
                serverType = @"NNTPS";
                break;
            default:
                break;
        }
    } 
	else 
	{
		// outgoing password

        switch([account incomingServerType]) 
		{
            case SMTP:
                serverType = @"SMTP";
                break;
            case SMTPS:
                serverType = @"SMTPS";
                break;
            case SMTPTLS:
                serverType = @"SMTP/TLS";
                break;
            default:
                break;
        }
    }
    return serverType;
}

- (NSString *)serviceTypeString
{
    NSString *serviceType = @"UNKNOWN";
    
    if (isIncomingPassword) 
	{
        switch([account incomingServerType]) 
		{
            case POP3:
            case POP3S:
                serviceType = @"EMail";
                break;
            case NNTP:
            case NNTPS:
                serviceType = @"News";
                break;
            default:
                break;
        }
    } 
	else 
	{
		// outgoing password
        serviceType = @"EMail";
    }
    
    return serviceType;
}

- (void)awakeFromNib
{
    [titleField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%@ Password Needed", @"password panel"), [self serviceTypeString]]];
    
    [subtitleField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"for %@ account \"%@\"", @"password panel"), [self serverTypeString], [account name]]];
    
    [userNameField setStringValue:isIncomingPassword ? [account valueForKey:@"incomingUsername"] : [account valueForKey: @"outgoingUsername"]];
    
    [serverNameField setStringValue: isIncomingPassword ? [account valueForKey:@"incomingServerName"] : [account valueForKey:@"outgoingServerName"]];
    
    [storeInKeychainCheckbox setState:[[[NSUserDefaults standardUserDefaults] objectForKey:DisableKeychainForPasswortDefault] boolValue] ? NSOffState : NSOnState];
        
    [window center];
    [window makeKeyAndOrderFront:self];
}

- (void)windowWillClose:(NSNotification *)notification 
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self autorelease]; // balance self-retaining
}

- (IBAction)OKAction:(id)sender
{
    if (NSDebugEnabled) NSLog(@"OKAction");
    
    @synchronized(result) 
	{
        [result setObject:[passwordField stringValue] forKey:@"password"];
        [result setObject:[NSNumber numberWithBool:YES] forKey:@"finished"];
    }
    
    if ([storeInKeychainCheckbox state] == NSOnState) 
	{
        if (isIncomingPassword) 
		{
            [account setIncomingPassword:[passwordField stringValue]];
        } 
		else 
		{
			// outgoing
            [account setOutgoingPassword:[passwordField stringValue]];
        }
    }
    
    [[NSUserDefaults standardUserDefaults] setBool:[storeInKeychainCheckbox state] == NSOnState ? NO : YES forKey:DisableKeychainForPasswortDefault];

    [window close];
}

- (IBAction)cancelAction:(id)sender
{
    if (NSDebugEnabled) NSLog(@"cancelAction");
    
    @synchronized(result) 
	{
        [result setObject:[NSNumber numberWithBool:YES] forKey:@"finished"];
    }
    
    [window close];
}

@end
