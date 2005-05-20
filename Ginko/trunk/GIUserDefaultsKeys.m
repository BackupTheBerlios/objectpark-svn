/*
 *  UserDefaultsKeys.c
 *  GinkoVoyager
 *
 *  Created by Dirk Theisen on 22.12.04.
 *  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
 *
 */

#import "GIUserDefaultsKeys.h"

NSString *MessageRendererFontName = @"MessageRendererFontName";
NSString *MessageRendererFontSize = @"MessageRendererFontSize";
NSString *MessageRendererShouldRenderAttachmentsInlineIfPossible = @"MessageRendererShouldRenderAttachmentsInlineIfPossible";
NSString *ShowAllHeaders          = @"ShowAllHeaders";
NSString *ContentTypePreferences  = @"ContentTypePreferences";
NSString *GroupsDrawerMode        = @"GroupsDrawerMode";
NSString *HeadersShown            = @"GIHeadersShown";
NSString *AdditionalHeadersShown  = @"GIAdditionalHeadersShown";
NSString *OutgoingMessageGroupURLString = @"OutgoingMessageGroupURLString";
NSString *DefaultMessageGroupURLString = @"DefaultMessageGroupURLString";
NSString *DraftsMessageGroupURLString = @"DraftsMessageGroupURLString";

NSArray* allAdditionalHeadersForDisplay()
{
    return [NSArray arrayWithObjects:
        @"Organization",
        @"X-Newsreader", 
        @"X-Mailer", 
        @"User-Agent",
        @"X-Complaints-To",
        @"Content-Type", 
        @"Content-Transfer-Encoding",
        @"Lines",
        @"Xref",
        @"Path",
        @"Delivered-To",
        @"Precedence",
        @"List-Id",
        @"List-Archive",
        @"List-Help",
        @"X-Profile",
        @"X-Sender",
        @"X-Accept-Language",
        nil];
}

void registerDefaultDefaults()
{    
    NSDictionary* appDefaults = [NSDictionary
        dictionaryWithObjectsAndKeys:
        [NSArray arrayWithObjects:
            @"From",
            @"Newsgroups",
            @"Subject",
            @"To",
            @"Cc",
            @"Bcc",
            @"Reply-To",
            @"Date",
            nil], HeadersShown,
        
        [NSArray array], AdditionalHeadersShown,
               
        [NSArray arrayWithObjects:
            @"multipart/mixed",
            @"text/enriched",
            @"text/plain",
            @"text/html",
            nil], ContentTypePreferences,
        
        nil, nil];
    
    
     ;
    
    [[NSUserDefaults standardUserDefaults] registerDefaults: appDefaults];
}