/*
 *  UserDefaultsKeys.h
 *  GinkoVoyager
 *
 *  Created by Dirk Theisen on 22.12.04.
 *  Copyright 2004 Objectpark Group <http://www.objectpark.org>. All rights reserved.
 *
 */

extern NSString *MessageRendererFontName;
extern NSString *MessageRendererFontSize;
extern NSString *MessageRendererShouldRenderAttachmentsInlineIfPossible;
extern NSString *ShowAllHeaders;
extern NSString *ContentTypePreferences;
extern NSString *GroupsDrawerMode;
extern NSString *HeadersShown;
extern NSString *AdditionalHeadersShown;
extern NSString *OutgoingMessageGroupURLString;
extern NSString *DefaultMessageGroupURLString;
extern NSString *DraftsMessageGroupURLString;
extern NSString *DisableKeychainForPasswortDefault;

extern NSArray *allAdditionalHeadersForDisplay();


extern void registerDefaultDefaults();
