//---------------------------------------------------------------------------------------
//  EDPlainTextContentCoder.h created by erik on Sun 18-Apr-1999
//  @(#)$Id: EDPlainTextContentCoder.h,v 1.2 2004/12/23 18:06:12 theisen Exp $
//
//  This file is part of the Alexandra Newsreader Project. ED3000 and the supporting
//  ED frameworks are free software; you can redistribute and/or modify them under
//  the terms of the GNU General Public License, version 2 as published by the Free
//  Software Foundation.
//---------------------------------------------------------------------------------------



#import "EDContentCoder.h"


@interface EDPlainTextContentCoder : EDContentCoder 
{
    NSString* text;
    BOOL      dataMustBe7Bit;
}

- (id)initWithText: (NSString*) text;
- (NSString*) text;

- (void) setDataMustBe7Bit:(BOOL)flag;
- (BOOL) dataMustBe7Bit;

- (id) initWithAttributedString: (NSAttributedString*) anAttributedString;
- (NSAttributedString*) attributedString;

@end
