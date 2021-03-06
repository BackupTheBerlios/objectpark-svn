//
//  GIPasswordController.h
//  GinkoVoyager
//
//  Created by Axel Katerbau on 10.06.05.
//  Copyright 2005 Objectpark Group. All rights reserved.
//

#import <AppKit/AppKit.h>

@class GIAccount;

@interface GIPasswordController : NSObject 
{
    GIAccount *account;
    BOOL isIncomingPassword;
    NSMutableDictionary *result;
    
    IBOutlet NSWindow *window;
    IBOutlet NSTextField *titleField;
    IBOutlet NSTextField *subtitleField;
    IBOutlet NSTextField *userNameField;
    IBOutlet NSTextField *serverNameField;
    IBOutlet NSSecureTextField *passwordField;
    IBOutlet NSButton *storeInKeychainCheckbox;
}

- (id)initWithParamenters:(NSMutableDictionary *)someParameters;

- (IBAction)OKAction:(id)sender;
- (IBAction)cancelAction:(id)sender;

@end
