/*
 *  UserDefaultsKeys.c
 *  GinkoVoyager
 *
 *  Created by Dirk Theisen on 22.12.04.
 *  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
 *
 */

#import "GIUserDefaultsKeys.h"

NSString* OpenMessageGroups = @"OpenMessageGroups";
NSString *MessageRendererFontName = @"MessageRendererFontName";
NSString *MessageRendererFontSize = @"MessageRendererFontSize";
NSString *MessageRendererShouldRenderAttachmentsInlineIfPossible = @"MessageRendererShouldRenderAttachmentsInlineIfPossible";
NSString *UseAlternateDateDisplayInMessageLists = @"UseAlternateDateDisplayInMessageLists";
NSString *ShowAllHeaders = @"ShowAllHeaders";
NSString *ContentTypePreferences = @"ContentTypePreferences";
NSString *GroupsDrawerMode = @"GroupsDrawerMode";
NSString *HeadersShown = @"GIHeadersShown";
NSString *AdditionalHeadersShown  = @"GIAdditionalHeadersShown";
NSString *SentMessageGroupURLString = @"SentMessageGroupURLString";
NSString *DefaultMessageGroupURLString = @"DefaultMessageGroupURLString";
NSString *DraftsMessageGroupURLString = @"DraftsMessageGroupURLString";
NSString *QueuedMessageGroupURLString = @"QueuedMessageGroupURLString";
NSString *SpamMessageGroupURLString = @"SpamMessageGroupURLString";
NSString *TrashMessageGroupURLString = @"TrashMessageGroupURLString";
NSString *ImportPanelLastDirectory = @"ImportPanelLastDirectory";
NSString *AutomaticActivityPanelEnabled = @"AutomaticActivityPanelEnabled";
NSString *FulltextIndexChangeCount = @"FulltextIndexChangeCount";
NSString *EarliestSendTimes = @"EarliestSendTimes";
NSString *AskAgainToBecomeDefaultMailApplication = @"AskAgainToBecomeDefaultMailApplication";
NSString *SoonRipeMessagesShouldBeSent = @"SoonRipeMessagesShouldBeSent";
NSString *SoonRipeMessageMinutes = @"SoonRipeMessageMinutes";
NSString *DefaultProfileURLString = @"DefaultProfileURLString";
NSString *ContinuousSpellCheckingEnabled = @"ContinuousSpellCheckingEnabled";

NSString *DisableKeychainForPasswortDefault = @"DisableKeychainForPasswortDefault";

NSString *SearchHitLimit = @"SearchHitLimit";
NSString *JunkReplySubjectPrefixes = @"JunkReplySubjectPrefixes";
NSString* RecentThreadListWindowPositions = @"RecentThreadListWindowPositions";
NSString *AttachmentSaveFolder = @"AttachmentSaveFolder";
NSString *ReuseThreadListWindowByDefault = @"ReuseThreadListWindowByDefault";
NSString *DateOfLastMessageRetrieval = @"DateOfLastMessageRetrieval";

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
    NSValueTransformer *archiverTransformer = [NSValueTransformer valueTransformerForName:NSUnarchiveFromDataTransformerName];
    
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
        
        [NSArray arrayWithObjects:@"Antw: ", nil], JunkReplySubjectPrefixes,
        
        [NSArray array], AdditionalHeadersShown,
               
        [NSArray arrayWithObjects:
            @"multipart/mixed",
            @"text/enriched",
            @"text/plain",
            @"text/html",
            nil], ContentTypePreferences,
        
        // setting default sort ordering for phrases list in phrase browser:
        [archiverTransformer reverseTransformedValue:[NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:@"phrasename" ascending:YES] autorelease]]], @"phrasesortdescriptors",
    
        [NSNumber numberWithInt:DEFAULTSEARCHHITLIMIT], SearchHitLimit,
        
		[NSNumber numberWithBool:YES], AskAgainToBecomeDefaultMailApplication, 
				
		[NSNumber numberWithBool:YES], SoonRipeMessagesShouldBeSent,
		
		[NSNumber numberWithInt:30], SoonRipeMessageMinutes,
		
		[NSNumber numberWithBool:YES], NSPrintHeaderAndFooter,
		
        nil, nil];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults: appDefaults];
}