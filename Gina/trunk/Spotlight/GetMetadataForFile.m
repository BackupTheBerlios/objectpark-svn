#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h> 
#import <Foundation/Foundation.h>
#import <InternetMessage/OPInternetMessage.h>
#import <InternetMessage/EDMessagePart+OPExtensions.h>
#import <InternetMessage/EDTextFieldCoder.h>
#import "NSString+MessageUtils.h"

/* -----------------------------------------------------------------------------
 Step 1
 Set the UTI types the importer supports
 
 Modify the CFBundleDocumentTypes entry in Info.plist to contain
 an array of Uniform Type Identifiers (UTI) for the LSItemContentTypes 
 that your importer can handle
 
 ----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
 Step 2 
 Implement the GetMetadataForFile function
 
 Implement the GetMetadataForFile function below to scrape the relevant
 metadata from your document and return it as a CFDictionary using standard keys
 (defined in MDItem.h) whenever possible.
 ----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
 Step 3 (optional) 
 If you have defined new attributes, update the schema.xml file
 
 Edit the schema.xml file to include the metadata keys that your importer returns.
 Add them to the <allattrs> and <displayattrs> elements.
 
 Add any custom types that your importer requires to the <attributes> element
 
 <attribute name="com_mycompany_metadatakey" type="CFString" multivalued="true"/>
 
 ----------------------------------------------------------------------------- */



/* -----------------------------------------------------------------------------
 Get metadata attributes from file
 
 This function's job is to extract useful information your file format supports
 and return it as a dictionary
 ----------------------------------------------------------------------------- */

Boolean GetMetadataForFile(void *thisInterface, 
						   CFMutableDictionaryRef attributes, 
						   CFStringRef contentTypeUTI,
						   CFStringRef pathToFile)
{
	static BOOL frameworksLoaded = NO;
	if (! frameworksLoaded) {
		
		NSString* importerPath = [[NSBundle bundleWithIdentifier: @"org.objectpark.GinaMDImporter"] bundlePath];
		NSString* applicationPath = [[[importerPath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
		NSString* path1 = [applicationPath stringByAppendingPathComponent:@"/Frameworks/OPNetwork.framework"];
		NSString* path2 = [applicationPath stringByAppendingPathComponent:@"/Frameworks/InternetMessage.framework"];
		
		[[NSBundle bundleWithPath:path1] load];
		[[NSBundle bundleWithPath:path2] load];
		//		NSLog(@"path1 = %@", path1);
		//		NSLog(@"path2 = %@", path2);
		frameworksLoaded = YES;
	}
	
    /* Pull any available metadata from the file at the specified path */
    /* Return the attribute keys and attribute values in the dict */
    /* Return TRUE if successful, FALSE if there was no data provided */
    
	//	NSLog(@"Gina Spotlight importer: Trying to index %@", pathToFile);
	NSData *transferData = [NSData dataWithContentsOfFile:(NSString *)pathToFile];
	assert(transferData != nil);
	
	OPInternetMessage *message = [[OPInternetMessage alloc] initWithTransferData:transferData];
	assert(message != nil);
	
	NSString *originalSubject = [message originalSubject];
	[(NSMutableDictionary *)attributes setObject:originalSubject forKey:(NSString *)kMDItemSubject];
	[(NSMutableDictionary *)attributes setObject:originalSubject forKey:(NSString *)kMDItemDisplayName];	
	
	NSString *textContent = [message contentAsPlainString];
	if (textContent) [(NSMutableDictionary*)attributes setObject:textContent forKey:(id)kMDItemTextContent];
	
	NSString *author = [message author];
	if (author) [(NSMutableDictionary *)attributes setObject:[NSArray arrayWithObject:author] forKey:(NSString *)kMDItemAuthors];

	NSArray *authorEmailAddresses = [[[EDTextFieldCoder decoderWithFieldBody:[message bodyForHeaderField:@"from"]] text] addressListFromEMailString];
	if (authorEmailAddresses) [(NSMutableDictionary *)attributes setObject:authorEmailAddresses forKey:(NSString *)kMDItemAuthorEmailAddresses];

	NSDate *date = [message date];
	if (date) 
	{
		[(NSMutableDictionary *)attributes setObject:date forKey:(NSString *)kMDItemContentCreationDate];
		[(NSMutableDictionary *)attributes setObject:date forKey:(NSString *)kMDItemLastUsedDate];
	}
	
	/*
	NSArray *recipients = [message realnameListFromAllRecipients];
	if (recipients) [(NSMutableDictionary *)attributes setObject:recipients forKey:(NSString *)kMDItemRecipients];
	
	NSArray *recipientEmailAddresses = [message addressListFromAllRecipients];
	if (recipientEmailAddresses) [(NSMutableDictionary *)attributes setObject:recipientEmailAddresses forKey:(NSString *)kMDItemRecipientEmailAddresses];
	*/
	
	NSString *messageId = [message bodyForHeaderField:@"message-id"];
	[(NSMutableDictionary *)attributes setObject:messageId forKey:(NSString *)kMDItemIdentifier];

	[message release];
	
	return YES;
}
