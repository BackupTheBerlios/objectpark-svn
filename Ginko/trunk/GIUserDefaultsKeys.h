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
extern NSString *UseAlternateDateDisplayInMessageLists;
extern NSString *ShowAllHeaders;
extern NSString *ShowRawSource;
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
extern NSString *EarliestSendTimes;
extern NSString *AskAgainToBecomeDefaultMailApplication;
extern NSString *SoonRipeMessagesShouldBeSent;
extern NSString *SoonRipeMessageMinutes;
extern NSString *DefaultProfileURLString;
extern NSString *ContinuousSpellCheckingEnabled;
extern NSString* RecentThreadListWindowPositions;
extern NSString *AttachmentSaveFolder;
extern NSString *ReuseThreadListWindowByDefault;
extern NSString *DateOfLastMessageRetrieval;
extern NSString *ShowThreadInfoPanel;
extern NSString *SelectFirstUnreadMessageInThread;

extern NSArray *allAdditionalHeadersForDisplay();
extern void registerDefaultDefaults();

#define DEFAULTSEARCHHITLIMIT 200