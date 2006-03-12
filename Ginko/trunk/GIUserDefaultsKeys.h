/*
 *  UserDefaultsKeys.h
 *  GinkoVoyager
 *
 *  Created by Dirk Theisen on 22.12.04.
 *  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
 *
 */

extern NSString* OpenMessageGroups;
extern NSString *MessageRendererFontName;
extern NSString *MessageRendererFontSize;
extern NSString *MessageRendererShouldRenderAttachmentsInlineIfPossible;
extern NSString *ShowAllHeaders;
extern NSString *ContentTypePreferences;
extern NSString *GroupsDrawerMode;
extern NSString *HeadersShown;
extern NSString *AdditionalHeadersShown;
extern NSString *SentMessageGroupURLString;
extern NSString *DefaultMessageGroupURLString;
extern NSString *DraftsMessageGroupURLString;
extern NSString *QueuedMessageGroupURLString;
extern NSString *SpamMessageGroupURLString;
extern NSString *TrashMessageGroupURLString;
extern NSString *DisableKeychainForPasswortDefault;
extern NSString *ImportPanelLastDirectory;
extern NSString *AutomaticActivityPanelEnabled;
extern NSString *FulltextIndexChangeCount;
extern NSString *SearchHitLimit;
extern NSString *JunkReplySubjectPrefixes;

extern NSArray *allAdditionalHeadersForDisplay();
extern void registerDefaultDefaults();

#define DEFAULTSEARCHHITLIMIT 200