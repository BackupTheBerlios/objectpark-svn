/* 
     $Id: GITextView.m,v 1.7 2005/04/14 17:28:14 theisen Exp $

     Copyright (c) 2001 by Axel Katerbau. All rights reserved.

     Permission to use, copy, modify and distribute this software and its documentation
     is hereby granted, provided that both the copyright notice and this permission
     notice appear in all copies of the software, derivative works or modified versions,
     and any portions thereof, and that both notices appear in supporting documentation,
     and that credit is given to Axel Katerbau in all documents and publicity
     pertaining to direct or indirect use of this code or its derivatives.

     THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME OF WHICH MAY HAVE
     SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER ALLOWS FREE USE OF THIS SOFTWARE IN ITS
     "AS IS" CONDITION. THE COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
     DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE OF THIS SOFTWARE
     OR OF ANY DERIVATIVE WORK.

     Further information can be found on the project's web pages
     at http://www.objectpark.org/Ginko.html
*/

#import "GITextView.h"
#import "NSAttributedString+MessageUtils.h"
#import "NSAttributedString+Extensions.h"
#import "NSFileWrapper+OPApplefileExtensions.h"
#import "NSString+MessageUtils.h"
#import "GIUserDefaultsKeys.h"
#import "OPInternetMessageAttachmentCell.h"
#import <Foundation/NSDebug.h>

NSString *OPAttributedStringPboardType = @"OPAttributedStringPboardType";

#define TAB ((char)'\x09')
#define SPACE ((char)'\x20')

@interface GIPrintingTextView : NSTextView {
	NSString* printJobTitle;
}

- (void) setPrintJobTitle: (NSString*) newTitle;

@end

@implementation GIPrintingTextView

- (NSString*) printJobTitle
{
	return printJobTitle? printJobTitle : [super printJobTitle];
}

- (void) setPrintJobTitle: (NSString*) newTitle
{
	[printJobTitle autorelease];
	printJobTitle = [newTitle retain];
}

/*
//- (NSAttributedString *)pageHeader;
- (NSAttributedString*) pageFooter
{
	NSString* footer = @"- 1 -";
	return [[[NSAttributedString alloc] initWithString: footer] autorelease];
}
*/

- (void) dealloc
{
	[printJobTitle release];
	[super dealloc];
}

@end


@implementation GITextView
/*"Support for a new pasteboard type OPAttributedStringPboardType. It uses NSCoding for transmitting so it is not crossplatform."*/

/*
+ (void) install
{
    static BOOL isInstalled = NO;

    if (NSDebugEnabled) NSLog(@"initialize GITextView");
    if (! isInstalled)
    {
        [GITextView poseAsClass:[NSTextView class]];
        isInstalled = YES;
    }
}
*/

+ (NSAttributedString *)_attributedStringFromPasteboard:(NSPasteboard *)quotePasteboard
{
    NSAttributedString *pbContent = nil;

    NSString *pasteboardType = [quotePasteboard availableTypeFromArray:[NSArray arrayWithObjects:
        OPAttributedStringPboardType, NSRTFDPboardType, NSRTFPboardType, NSStringPboardType, nil]];

    if ([pasteboardType isEqualToString:OPAttributedStringPboardType])
    {
        NSData *pasteboardData = [quotePasteboard dataForType:OPAttributedStringPboardType];
        pbContent = [NSUnarchiver unarchiveObjectWithData:pasteboardData];
        [pbContent retain];
        if (NSDebugEnabled) NSLog(@"Attributed String = %@", pbContent);
    }
    else if ([pasteboardType isEqualToString:NSRTFDPboardType])
    {
        pbContent = [[NSMutableAttributedString allocWithZone:[self zone]] initWithRTFD:[quotePasteboard dataForType:NSRTFDPboardType] documentAttributes:NULL];
    }
    else if ([pasteboardType isEqualToString:NSRTFPboardType])
    {
        pbContent = [[NSMutableAttributedString allocWithZone:[self zone]] initWithRTF:[quotePasteboard dataForType:NSRTFPboardType] documentAttributes:NULL];
    }
    else if ([pasteboardType isEqualToString:NSStringPboardType])
    {
        pbContent = [[NSMutableAttributedString allocWithZone:[self zone]] initWithString:[quotePasteboard stringForType:NSStringPboardType]];
    }
    return [pbContent autorelease];
}

+ (NSString *)plainTextQuoteFromPasteboard:(NSPasteboard *)quotePasteboard
{
    NSAttributedString *quoteContent;

    quoteContent = [[self _attributedStringFromPasteboard:quotePasteboard] attributedStringByRemovingSourroundingWhitespacesAndNewLines];
    
    return [[quoteContent quotedStringWithLineLength:72 byIncreasingQuoteLevelBy:1] stringByRemovingAttachmentChars];
}




- (void) print: (id) sender
{
	NSPrintInfo* printInfo = [NSPrintInfo sharedPrintInfo];
	[printInfo setHorizontalPagination: NSFitPagination];
    [printInfo setVerticallyCentered: NO];
	[printInfo setTopMargin: 60.0]; // 72 should be one inch

	NSRect bounds;
	bounds.size = [printInfo paperSize];
	// We scale the textview by the factor (pagewidth/hor.margins), if we do not substract the margins because we fit horizontally to the page .
	bounds.origin.x = 0.0; //[printInfo leftMargin];
	bounds.origin.y = 0.0; //[printInfo topMargin];
	//bounds.size.width -= bounds.origin.x+[printInfo rightMargin];
	
	GIPrintingTextView* printView = [[[GIPrintingTextView alloc] initWithFrame: bounds] autorelease];
	
	[[printView textStorage] beginEditing];
	[[printView textStorage] appendAttributedString: [self textStorage]];
	[[printView textStorage] endEditing];
	[printView setPrintJobTitle: [[self window] title]];
	
	[printView print: sender];
}

- (void)_removeUnsupportedAttributesInRange:(NSRange)range
{
    NSTextStorage *ts = [self textStorage];
    
    [ts beginEditing];
    [ts removeAttribute:NSFontAttributeName range:range];
    [ts removeAttribute:NSForegroundColorAttributeName range:range];
    [ts removeAttribute:NSUnderlineStyleAttributeName range:range];
    [ts removeAttribute:NSSuperscriptAttributeName range:range];
    [ts removeAttribute:NSBackgroundColorAttributeName range:range];
    [ts removeAttribute:NSBaselineOffsetAttributeName range:range];
    //[ts removeAttribute:NSFontAttributeName range:range];    // do we need to set the selected font?
    [ts endEditing];
}


- (void)paste:(id)sender
{
// ##WARNING This method disables some attributes to be pasted. This has to be configurable at one time in order to allow "styled" texts.
    NSRange pasteRange;

    pasteRange = [self rangeForUserTextChange];
    [super paste:sender];
    pasteRange.length = [self rangeForUserTextChange].location-pasteRange.location;

    [self _removeUnsupportedAttributesInRange:pasteRange];
}

- (void)pasteAsQuotation:(id)sender
{
    NSAttributedString *quoteContent;
    NSString *quote;

    quoteContent = [[self class] _attributedStringFromPasteboard:[NSPasteboard generalPasteboard]];
    quote = [[quoteContent quotedStringWithLineLength:72 byIncreasingQuoteLevelBy:1] stringByRemovingAttachmentChars];
    
    if ([quote length])
    {
        [self insertText:quote];
    }
}

- (NSArray *)writablePasteboardTypes
{
    return [[super writablePasteboardTypes] arrayByAddingObject:OPAttributedStringPboardType];
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard type:(NSString *)type
{
    if ([type isEqualToString:OPAttributedStringPboardType])
    {
        NSAttributedString *selection;
        NSData *selectionAsData;
        BOOL result;

        // Serious CAUTION.
        // Only non mutable NSAttributedStrings support archiving of custom attributes!
        // This seems to be a bug on Apple's side!
        selection = [[[[self textStorage] attributedSubstringFromRange:[self selectedRange]] copy] autorelease];

/*        selectionAsData = [[NSArchiver archivedDataWithRootObject:selection] retain];

        [selectionAsData release];*/
        selectionAsData = [NSArchiver archivedDataWithRootObject:selection];

        result = [pboard setData:selectionAsData forType:OPAttributedStringPboardType];

        return result;
    }
    return [super writeSelectionToPasteboard:pboard type:type];
}

- (BOOL)readSelectionFromPasteboard:(NSPasteboard *)pboard type:(NSString *)type
{
    if ([type isEqualToString:NSFilenamesPboardType]) // resource fork and finder info if given
    {
        NSArray *filenames;
        NSString *filename;
        NSEnumerator *enumerator;
        NSMutableAttributedString* result;
        
        if (NSDebugEnabled) NSLog(@"add resource fork and finder info to NSFileWrapper if given.");
        
        filenames = [pboard propertyListForType:NSFilenamesPboardType];
        NSAssert([filenames isKindOfClass:[NSArray class]], @"filenames not in required format.");
        
        result = [[NSMutableAttributedString alloc] init];
        
        enumerator = [filenames objectEnumerator];
        while (filename = [enumerator nextObject])
        {
            NSFileWrapper *fileWrapper;
            NSTextAttachment *attachment;
            
            if (NSDebugEnabled) NSLog(@"Filename = %@", filename);
            
            // make file wrapper from filename
            fileWrapper = [[NSFileWrapper alloc] initWithPath:filename forksAndFinderInfo:YES];
            
            // make text attachment from file wrapper
            attachment = [[NSTextAttachment alloc] initWithFileWrapper:fileWrapper];
            
			//NSCell* c = [attachment attachmentCell];
			
			//if ([c isKindOfClass: [NSTextAttachmentCell class])
			OPInternetMessageAttachmentCell* aCell = [[OPInternetMessageAttachmentCell alloc] initImageCell: [[NSWorkspace sharedWorkspace] iconForFile: filename]];
			//[aCell setTitle: @"TestTitle"];
			//[aCell setInfoString: @"TestInfo"];
			[aCell setAttachment: attachment];
			[attachment setAttachmentCell: aCell];
			
			[aCell release];
			
            // append text attachment to result attributedstring
            [result appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
            [attachment release];
            [fileWrapper release];
        }

        [[self textStorage] beginEditing];
        
        //NSLog(@"Inserting %@ into %@ at range %@.", result, [self textStorage], NSStringFromRange([self rangeForUserTextChange]));

        // Finally, paste in text:
        if ([result length])
        {
            [[self textStorage] replaceCharactersInRange:[self rangeForUserTextChange] withAttributedString:result];
        }
        //NSLog(@"Inserted %@ into %@.", result, [self textStorage]);

        [[self textStorage] endEditing];

        [result release];
        return YES;
    } 
	else 
	{
        return [super readSelectionFromPasteboard:pboard type:type];
    }
}

- (void)toggleContinuousSpellChecking:(id)sender
/*" Invokes functionality of superclass and sends an OPContinuousSpellCheckingDidToggleNotification notification additionally. "*/
{
    [super toggleContinuousSpellChecking:sender];

	[[NSUserDefaults standardUserDefaults] setBool:[self isContinuousSpellCheckingEnabled] forKey:ContinuousSpellCheckingEnabled];
}

+ (NSMenu*) attachmentMenu
{
	static NSMenu* attachmentMenu = nil;
	if (!attachmentMenu) {
		attachmentMenu = [[self defaultMenu] copy];
		[attachmentMenu insertItemWithTitle: @"Save to Download Folder" 
									 action: @selector(saveAttachmentToDownloadFolder:) 
							  keyEquivalent: @"" 
									atIndex: 0];		
		[attachmentMenu insertItemWithTitle: @"Save..." 
									 action: @selector(saveAttachment:) 
							  keyEquivalent: @"" 
									atIndex: 0];
	}
	return attachmentMenu;
}

- (NSTextAttachment*) selectedAttachment
{
	NSTextAttachment* attachment = [[self textStorage] attribute: NSAttachmentAttributeName atIndex: [self selectedRange].location effectiveRange: NULL];
	return attachment;
}

- (void) saveAttachmentToDownloadFolder: (id) sender
{
	NSTextAttachment* attachment = [self selectedAttachment];
	NSLog(@"Will -saveAttachment: %@", attachment);
	NSFileWrapper* fwrapper = [attachment fileWrapper];
	if (fwrapper) {
		NSString* downloadFolder = @"/tmp";
		NSString* fullpath = [downloadFolder stringByAppendingPathComponent: [fwrapper filename]];
		[fwrapper writeToFile: fullpath atomically: NO updateFilenames: NO];
		
		[[NSWorkspace sharedWorkspace] selectFile: fullpath 
						 inFileViewerRootedAtPath: downloadFolder];
	}
}


- (NSMenu*) menuForEvent: (NSEvent*) theEvent
{
	NSMenu* result = [super menuForEvent: theEvent];
	
	if ([self selectedAttachment]) {
		// The user right-clicked on an attachment:
		result = [[self class] attachmentMenu];
	}
	return result;
}


- (void)keyDown:(NSEvent *)theEvent
/*" Enables in the case of a non editable text view the use of the spacebar. "*/
{
    if (! [self isEditable])
    {
        NSString *characters = [theEvent characters];
		
		if ([characters length]) 
		{
			unichar firstChar = [characters characterAtIndex:0];
			id delegate = [self delegate];
			int modifierFlags = [theEvent modifierFlags];
			
			switch (firstChar)
			{
				case SPACE:
					if ([delegate respondsToSelector:@selector(textView:spaceKeyPressedWithModifierFlags:)])
					{
						[delegate textView:self spaceKeyPressedWithModifierFlags:modifierFlags];
					}
					break;
				case TAB:
					if ([self nextKeyView]) 
					{
						[[self window] makeFirstResponder:[self nextKeyView]];
						//NSLog(@"switched first responder to %@: %d", [self nextKeyView], result);            
					}
					return;
					break;
				default:
					break;
			}
		}
    }

    [super keyDown:theEvent];
}

@end

