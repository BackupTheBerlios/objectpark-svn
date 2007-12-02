/* 
     $Id: NSFileWrapper+OPApplefileExtensions.m,v 1.3 2005/04/14 17:28:24 theisen Exp $

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

#import "NSFileWrapper+OPApplefileExtensions.h"
#import <Carbon/Carbon.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/NSDebug.h>

#define NSFILEWRAPPEREXTENSIONS OPL_DOMAIN @"NSFILEWRAPPEREXTENSIONS"


#import "NSData+Extensions.h"

#define ASEntrySize 12 // 3x uint32
#define ASHeaderSize 26

/* Apple reserves the range of entry IDs from 1 to 0x7FFFFFFF.
* Entry ID 0 is invalid.  The rest of the range is available
* for applications to define their own entry types.  "Apple does
* not arbitrate the use of the rest of the range."
*/
#define AS_DATA         1 /* data fork */
#define AS_RESOURCE     2 /* resource fork */
#define AS_REALNAME     3 /* File's name on home file system */
#define AS_COMMENT      4 /* standard Mac comment */
#define AS_ICONBW       5 /* Mac black & white icon */
#define AS_ICONCOLOR    6 /* Mac color icon */
/*                        7 *//* not used */
#define AS_FILEDATES    8 /* file dates; create, modify, etc */
#define AS_FINDERINFO   9 /* Mac Finder info & extended info */
#define AS_MACINFO      10 /* Mac file info, attributes, etc */
#define AS_PRODOSINFO   11 /* Pro-DOS file info, attrib., etc */
#define AS_MSDOSINFO    12 /* MS-DOS file info, attributes, etc */
#define AS_AFPNAME      13 /* Short name on AFP server */
#define AS_AFPINFO      14 /* AFP file info, attrib., etc */

@interface NSData (OPApplefile)

+ (id) appleFileDataWithDataDictionary: (NSDictionary*) dataDict;

@end


@implementation NSData (OPApplefile)


+ (id) appleFileDataWithDataDictionary: (NSDictionary*) dataDict
	/*" Returns an AppleSingle data structure (see RFC1740) from a dictionary of data objects, keyed with NSNumbers, representing the entryIds. "*/
{
	NSMutableData* result = [NSMutableData data];
	BOOL isAppleDouble = [[dataDict objectForKey: [NSNumber numberWithUnsignedLong: AS_DATA]] length] > 0;
	
	NSEnumerator* dke;
	NSNumber* entryId;
	
	UInt32 currentFileDataOffset = ASHeaderSize + [dataDict count] * ASEntrySize;
	
	// Append global header:
	UInt32 as_magic       = isAppleDouble ? 0x00051607 : 0x00051600;
	UInt32 as_version     = 0x00020000;
	UInt16 as_entry_count = [dataDict count];
	
	[result serializeUnsignedLong: as_magic];
	[result serializeUnsignedLong: as_version];
	[result appendZeroedBytes: 16];
	[result serializeUnsignedShort: as_entry_count];
	
	// Append all entry headers:
	dke = [dataDict keyEnumerator];
	while (entryId = [dke nextObject]) {
		NSData* value = [dataDict objectForKey: entryId];
		
		UInt32 length = [value length];
		[result serializeUnsignedLong: [entryId unsignedLongValue]]; // serialize entryId
		[result serializeUnsignedLong: currentFileDataOffset]; // serialize offset from file start
		[result serializeUnsignedLong: length]; // serialize length of entry
		currentFileDataOffset += length;
	}
	
	// Append all data values:
	dke = [dataDict keyEnumerator];
	while (entryId = [dke nextObject]) {
		NSData* entry = [dataDict objectForKey: entryId];
		[result appendData: entry];
	}
	
	return result;
}

- (NSDictionary*) applefileDataDictionary
/*" Returns a dictionary of sub-data objects keyed by applefile entryId (see RFC1740). "*/
{
	unsigned currentFileDataOffset = 0;
	
	// Read global header:
	
	UInt32 as_magic = [self deserializeUnsignedLongAt: &currentFileDataOffset];
	
	if (as_magic == 0x00051607 || as_magic == 0x00051600) {
		
		UInt32 as_version     = [self deserializeUnsignedLongAt: &currentFileDataOffset];
		currentFileDataOffset += 16; // skip 16 byte filler
		UInt16 as_entry_count = [self deserializeUnsignedShortAt: &currentFileDataOffset];
		
		if (as_version >= 0x00020000) {
			if (as_entry_count > 0) {
				NSMutableDictionary* dataDict = [NSMutableDictionary dictionary];
				
				for (int i = 0; i<as_entry_count; i++) {
					// Read an applefile entry:
					UInt32 entryId  = [self deserializeUnsignedLongAt: &currentFileDataOffset];
					UInt32 offset   = [self deserializeUnsignedLongAt: &currentFileDataOffset];
					UInt32 length   = [self deserializeUnsignedLongAt: &currentFileDataOffset];
					NSData* subData = [self subdataWithRange: NSMakeRange(offset, length)];
					
					[dataDict setObject: subData forKey: [NSNumber numberWithUnsignedLong: entryId]];
				}
				
				return dataDict;
			}
		}
	}

	return nil; // invalid header magic - throw?
}


@end


   /* applefile.h - Data structures used by AppleSingle/AppleDouble
    * file format
    *
    * Written by Lee Jones, 22-Oct-1993
    *
    * For definitive information, see "AppleSingle/AppleDouble
    * Formats for Foreign Files Developer's Note"; Apple Computer
    * Inc.; (c) 1990.
    *
    * Other details were added from:
    *   Inside Macintosh [old version], volumes II to VI,
    *   Apple include files supplied with Think C 5.0.1,
    *   Microsoft MS-DOS Programmer's Reference, version 5, and
    *   Microsoft C 6.00a's dos.h include file.
    *
    * I don't have ProDOS or AFP Server documentation so related
    * entries may be a bit skimpy.
    *
    * Edit history:
    *
    * when       who  why

    * ---------  ---  ------------------------------------------
    * 22-Oct-93  LMJ  Pull together from Inside Macintosh,
    *                 Developer's Note, etc
    * 26-Oct-93  LMJ  Finish writing first version and list
    *                 references
    * 06-Feb-94  EEF  Very minor cleanup
    * 06-Oct-01  AMK  modified for use in a Cocoa application
    *                 (most likely not crossplatform anymore)
    *                 Original appleheader.h can be found in
    *                 RFC 1740
    */
    

   /*
    * Masks for finder flag bits (field fdFlags in struct
    * FInfo).
    */

   #define F_fOnDesk       0x0001 /* file is on desktop (HFS only) */
   #define F_maskColor     0x000E /* color coding (3 bits) */
   /*                      0x0010 *//* reserved (System 7) */
   #define F_fSwitchLaunch 0x0020 /* reserved (System 7) */
   #define F_fShared       0x0040 /* appl available to multiple users */
   #define F_fNoINITs      0x0080 /* file contains no INIT resources */
   #define F_fBeenInited   0x0100 /* Finder has loaded bundle res. */
   /*                      0x0200 *//* reserved (System 7) */
   #define F_fCustomIcom   0x0400 /* file contains custom icon */
   #define F_fStationary   0x0800 /* file is a stationary pad */
   #define F_fNameLocked   0x1000 /* file can't be renamed by Finder */
   #define F_fHasBundle    0x2000 /* file has a bundle */
   #define F_fInvisible    0x4000 /* file's icon is invisible */
   #define F_fAlias        0x8000 /* file is an alias file (System 7) */

   /* Pieces used by AppleSingle & AppleDouble (defined later). */

   /* matrix of entry types and their usage:
    *
    *                   Macintosh    Pro-DOS    MS-DOS    AFP server
    *                   ---------    -------    ------    ----------
    *  1   AS_DATA         xxx         xxx       xxx         xxx
    *  2   AS_RESOURCE     xxx         xxx
    *  3   AS_REALNAME     xxx         xxx       xxx         xxx

    *
    *  4   AS_COMMENT      xxx
    *  5   AS_ICONBW       xxx
    *  6   AS_ICONCOLOR    xxx
    *
    *  8   AS_FILEDATES    xxx         xxx       xxx         xxx
    *  9   AS_FINDERINFO   xxx
    * 10   AS_MACINFO      xxx
    *
    * 11   AS_PRODOSINFO               xxx
    * 12   AS_MSDOSINFO                          xxx
    *
    * 13   AS_AFPNAME                                        xxx
    * 14   AS_AFPINFO                                        xxx
    * 15   AS_AFPDIRID                                       xxx
    */

   /* entry ID 1, data fork of file - arbitrary length octet string */

   /* entry ID 2, resource fork - arbitrary length opaque octet string;
    *              as created and managed by Mac O.S. resoure manager
    */

   /* entry ID 3, file's name as created on home file system - arbitrary
    *              length octet string; usually short, printable ASCII
    */

   /* entry ID 4, standard Macintosh comment - arbitrary length octet
    *              string; printable ASCII, claimed 200 chars or less
    */

   /* This is probably a simple duplicate of the 128 octet bitmap
    * stored as the 'ICON' resource or the icon element from an 'ICN#'
    * resource.
    */


   /* entry ID 6, "standard" Macintosh color icon - several competing
    *              color icons are defined.  Given the copyright dates
    * of the Inside Macintosh volumes, the 'cicn' resource predominated
    * when the AppleSingle Developer's Note was written (most probable
    * candidate).  See Inside Macintosh, Volume V, pages 64 & 80-81 for

    * a description of 'cicn' resources.
    *
    * With System 7, Apple introduced icon families.  They consist of:
    *      large (32x32) B&W icon, 1-bit/pixel,    type 'ICN#',
    *      small (16x16) B&W icon, 1-bit/pixel,    type 'ics#',
    *      large (32x32) color icon, 4-bits/pixel, type 'icl4',
    *      small (16x16) color icon, 4-bits/pixel, type 'ics4',
    *      large (32x32) color icon, 8-bits/pixel, type 'icl8', and
    *      small (16x16) color icon, 8-bits/pixel, type 'ics8'.
    * If entry ID 6 is one of these, take your pick.  See Inside
    * Macintosh, Volume VI, pages 2-18 to 2-22 and 9-9 to 9-13, for
    * descriptions.
    */

   /* entry ID 7, not used */

   /* Times are stored as a "signed number of seconds before of after
    * 12:00 a.m. (midnight), January 1, 2000 Greenwich Mean Time (GMT).
    * Applications must convert to their native date and time
    * conventions." Any unknown entries are set to 0x80000000
    * (earliest reasonable time).
    */


   typedef struct ASMsdosInfo ASMsdosInfo;

   #define AS_DOS_NORMAL   0x00 /* normal file (all bits clear) */
   #define AS_DOS_READONLY 0x01 /* file is read-only */
   #define AS_DOS_HIDDEN   0x02 /* hidden file (not shown by DIR) */
   #define AS_DOS_SYSTEM   0x04 /* system file (not shown by DIR) */
   #define AS_DOS_VOLID    0x08 /* volume label (only in root dir) */
   #define AS_DOS_SUBDIR   0x10 /* file is a subdirectory */
   #define AS_DOS_ARCHIVE  0x20 /* new or modified (needs backup) */

   /* entry ID 13, short file name on AFP server - arbitrary length
    *              octet string; usualy printable ASCII starting with
    *              '!' (0x21)

    */


   /*
    * FINAL REMINDER: the Motorola 680x0 is a big-endian architecture!
    */

   /* End of applefile.h */

NSString *OPFileResourceForkData = @"OPFileResourceForkData";
NSString *OPFinderInfo = @"OPFinderInfo";

@implementation NSFileWrapper (OPApplefileExtensions)

- (void) addForksAndFinderInfoWithPath: (NSString*) path
/*"Adds resource fork and finder info to the file attributes."*/
{
    if (NSDebugEnabled) NSLog(@"addForksAndFinderInfoWithPath:%@", path);
    
    // if directory/folder descent
    if ([self isDirectory]) {
        NSEnumerator *enumerator;
        id key;
        
        enumerator = [[self fileWrappers] keyEnumerator];
        while (key = [enumerator nextObject])
        {
            NSFileWrapper *fileWrapper;
            
            fileWrapper = [[self fileWrappers] objectForKey:key];
            [fileWrapper addForksAndFinderInfoWithPath:[path stringByAppendingPathComponent:[fileWrapper filename]]];
        }
    }
    
    // add resource fork and finder info
    {
        CFURLRef url;
        Boolean success;
        OSErr err;
        FSRef fsRef;
        //FSSpec fsSpec;
        HFSUniStr255 forkName;
        SInt16 refNum;
        NSData *resourceForkData = nil, *finderInfo = nil;
        
        // create fsRef
        url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)path, kCFURLPOSIXPathStyle, false);
        success = CFURLGetFSRef(url, &fsRef);
        CFRelease(url);
        if (! success) 
        {
            [NSException raise: NSInvalidArgumentException format: @"Unable to get a FSRef from the path %@.", path];
        }
        
        err = FSGetResourceForkName(&forkName);
        if (err != noErr) 
        {
            [NSException raise: NSInvalidArgumentException format: @"Unable to get resource fork name (err = %d)", err];
        }
        
        // try to open resource fork
        err = FSOpenFork(&fsRef, forkName.length, forkName.unicode, fsCurPerm, &refNum);
        if (err == noErr) 
        {
            SInt64 forkSize;
            ByteCount actualCount;
            
            void *buffer;
            
            // get fork size
            err = FSGetForkSize(refNum, &forkSize);
            if (err != noErr) 
            {
                NSLog(@"Unable to get resource fork size (err = %d) from path %@", err, path);
                return;
            }
            
            if (forkSize > 0)
            {
                buffer = malloc(forkSize);
                
                // read fork
                err = FSReadFork(refNum, fsFromStart, 0, forkSize, buffer, &actualCount);
                if (err != noErr)
                {
                    NSLog(@"Unable to read resource fork of file %@ (err = %d).", path, err);
                    free(buffer);
                    return;
                }
				
                resourceForkData = [NSData dataWithBytes:buffer length:actualCount];
				
                if (NSDebugEnabled) NSLog(@"resource fork with length = %lu", actualCount);
                
                free(buffer);
            }
            
            // close resource fork
            err = FSCloseFork(refNum);
            if (err != noErr)
            {
                NSLog(@"Unable to close resource fork of file %@ (err = %d).", path, err);
                return;
            }
        }
		
        // add Finder info
        FSCatalogInfo catalogInfo;
        
        err = FSGetCatalogInfo(&fsRef, kFSCatInfoFinderInfo, &catalogInfo, NULL, NULL, NULL);
        if (err != noErr)
        {
            NSLog(@"Unable to get an FSSpec for the file %@ (err = %d).", path, err);
        } else {
            finderInfo = [NSData dataWithBytes:catalogInfo.finderInfo length:sizeof(FInfo)];
        }
	
        
        // add resource fork to attributes
		
		// set resource fork data as attribute
		NSMutableDictionary* attributes = [[self fileAttributes] mutableCopy];
		
		if (resourceForkData) {
			if (NSDebugEnabled) NSLog(@"adding resource fork.");
			[attributes setObject: resourceForkData forKey:OPFileResourceForkData];
		}
		
		if (finderInfo) {
			
			if (NSDebugEnabled) NSLog(@"adding finder info.");
			
			FInfo*    fInfo   = (FInfo *)[finderInfo bytes];
			NSNumber* type    = [NSNumber numberWithUnsignedLong:fInfo->fdType];
			NSNumber* creator = [NSNumber numberWithUnsignedLong:fInfo->fdCreator];
			//            [attributes setObject: type forKey:NSFileHFSTypeCode];
			//            [attributes setObject: creator forKey:NSFileHFSCreatorCode];
			//    #warning axel->axel: report NSFileWrapper bug (type and creator are not set and resource forks not supported)
			//
			[attributes setObject: finderInfo forKey:OPFinderInfo];
		}
		
		[self setFileAttributes:attributes]; 
		[attributes release];		
    }
}

- (id) initWithPath: (NSString*) path forksAndFinderInfo: (BOOL) forksAndFinderInfo
/*" If forksAndFinderInfo is YES then adds the resource fork and the finder info 
	 to the file's attributes. "*/
{
    if (! [self initWithPath: path]) return nil;
    
     // post-process the file wrapper to add the resource fork and finder info
	if (forksAndFinderInfo) {
        [self addForksAndFinderInfoWithPath: path];
    }
    
    return self;
}

//#warning axel->all: This is not atomic at the moment. Regardless of the atomicFlag.
- (BOOL) writeForksToFile: (NSString*) path atomically: (BOOL) atomicFlag updateFilenames: (BOOL) updateNamesFlag
/*"
   In addition to the data fork it also writes the resource fork data given in the 
   attributes dictionary under the key OPFileResourceForkData and the finder info given
   under the key OPFinderInfo.
"*/
{
    CFURLRef url;
    Boolean success;
    OSErr err;
    FSRef fsRef;
    HFSUniStr255 forkName;
    SInt16 refNum;
    NSData *resourceForkData, *finderInfo;
    
    if (! [self writeToFile:path atomically: atomicFlag updateFilenames: updateNamesFlag])
        return NO;
    
    // take care of resource fork
    
    // check if resource fork exists
    if (! (resourceForkData = [[self fileAttributes] objectForKey: OPFileResourceForkData]))
        return YES;	// nothing to do
    
    // create resource fork and write resource data in it
    
    if (NSDebugEnabled) NSLog(@"Resource path = %@", path);
    
    // create fsRef
    url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)path, kCFURLPOSIXPathStyle, false);
    success = CFURLGetFSRef(url, &fsRef);
    CFRelease(url);
    
    if (! success) 
    {
        [NSException raise: NSInvalidArgumentException format: @"Unable to get a FSRef from the path %@.", path];
    }
    
    err = FSGetResourceForkName(&forkName);
    if (err != noErr) 
    {
        [NSException raise: NSInvalidArgumentException format: @"Unable to get resource fork name (err = %d)", err];
    }
    
    // create resource fork
    err = FSCreateFork(&fsRef, forkName.length, forkName.unicode);
    if (err != noErr)
    {
        [NSException raise: NSInvalidArgumentException format: @"Unable to create resource fork for file %@ (err = %d).", path, err];
    }
    
    // open resource fork
    err = FSOpenFork(&fsRef, forkName.length, forkName.unicode, fsCurPerm, &refNum);
    if (err != noErr) 
    {
        [NSException raise: NSInvalidArgumentException format: @"Unable to open resource fork from file %@ (err = %d).", path, err];
    }
    
    // write resource fork
    err = FSWriteFork(refNum, fsFromStart, 0, [resourceForkData length], [resourceForkData bytes], NULL);
    if (err != noErr)
    {
        [NSException raise: NSInvalidArgumentException format: @"Unable to write resource fork of file %@ (err = %d).", path, err];
    }
    
    // close resource fork
    err = FSCloseFork(refNum);
    if (err != noErr)
    {
        [NSException raise: NSInvalidArgumentException format: @"Unable to close resource fork of file %@ (err = %d).", path, err];
    }
    
    // take care of Finder info
    if (finderInfo = [[self fileAttributes] objectForKey: OPFinderInfo])
    {
        if (NSDebugEnabled) NSLog(@"Setting FinderInfo.");   
        
        FSCatalogInfo catalogInfo;
        FInfo fndrInfo;
                        
        [finderInfo getBytes:&fndrInfo length:sizeof(FInfo)];
            
        // inspired by MoreFilesX.c <http://www.ncbi.nlm.nih.gov/IEB/ToolBox/C_DOC/source/corelib/morefile/MoreFilesX.c>
        BlockMoveData(&fndrInfo, catalogInfo.finderInfo, sizeof(FInfo));
        
        OSErr err = FSSetCatalogInfo(&fsRef, kFSCatInfoFinderInfo, &catalogInfo);
        if (err != noErr)
        {
            [NSException raise:NSInvalidArgumentException format:@"Unable to set finder info of file %@ (err = %d).", path, err];
        }
        
        /* old and deprecated stuff
        // fsRef -> fsSpec
        // http://homepage.mac.com/troy_stephens/software/objects/IconFamily/
        err = FSGetCatalogInfo(&fsRef, kFSCatInfoNone, NULL, NULL, &fsSpec, NULL);
        if (err != noErr)
        {
            [NSException raise: NSInvalidArgumentException format: @"Unable to get an FSSpec for the file %@ (err = %d).", path, err];
        }
        
        // set Finder info
        fndrInfoPtr = &((ASFinderInfo *)[finderInfo bytes])->ioFlFndrInfo;
        
        err = FSpSetFInfo(&fsSpec, fndrInfoPtr);
        if (err != noErr)
        {
            [NSException raise: NSInvalidArgumentException format: @"Unable to set finder info of file %@ (err = %d).", path, err];
        }
        
        */
    }
    
    return YES;
}

- (NSData*) applefileContentsIncludingDataFork: (BOOL) includeDataFork
/*" Creates data containing an AppleSingle/AppleDouble structure with 3 entries:
	resource fork, finder info, realname.
    The receiver must be a regularFile. If the includeDataFork is YES, an
    AppleDouble header is generated and the data fork included. AppleSingle, otherwise.
	"*/
{
	NSMutableDictionary* dataDict = [NSMutableDictionary dictionary];
	NSDictionary* fileAttributes = [self fileAttributes];
	
	// resource fork
	NSData* resourceForkData = [fileAttributes objectForKey: OPFileResourceForkData];
	if (resourceForkData) [dataDict setObject: resourceForkData forKey: [NSNumber numberWithInt: AS_RESOURCE]];
	
	// finder info
	NSData* finderInfo = [fileAttributes objectForKey: OPFinderInfo];
	if (finderInfo) [dataDict setObject: finderInfo forKey: [NSNumber numberWithInt: AS_FINDERINFO]];
	
	// realname
	NSData* realnameData = [[self filename] dataUsingEncoding: NSMacOSRomanStringEncoding allowLossyConversion: YES];
	if (realnameData) [dataDict setObject: realnameData forKey: [NSNumber numberWithInt: AS_REALNAME]];
	
	if (includeDataFork) {
		NSData* dataFork = [self regularFileContents];
		if ([dataFork length]) [dataDict setObject: dataFork forKey: [NSNumber numberWithInt: AS_DATA]];
	}
	
	NSData* result = [NSData appleFileDataWithDataDictionary: dataDict];
	return result;
}

- (id) initRegularFileWithContents: (NSData*) dataFork
				 applefileContents: (NSData*) applefileData
/*" Handles both AppleSingle and AppleDouble representations. Pass nil dataFork for AppleSingle. "*/
{
	NSDictionary* dataDictionary = [applefileData applefileDataDictionary];
	
	// Now we can access all entries by entryId (NSNumber):
	
	if (! dataFork) {
		dataFork = [dataDictionary objectForKey: [NSNumber numberWithUnsignedLong: AS_DATA]];
	}
	
	if (self = [self initRegularFileWithContents: dataFork]) {
		
		if (dataDictionary) {
			NSMutableDictionary* attrs = [[self fileAttributes] mutableCopy];
			NSData* finderInfo = [dataDictionary objectForKey: [NSNumber numberWithUnsignedLong: AS_FINDERINFO]];
			NSData* resourceFork = [dataDictionary objectForKey: [NSNumber numberWithUnsignedLong: AS_RESOURCE]];
			NSData* filenameData = [dataDictionary objectForKey: [NSNumber numberWithUnsignedLong: AS_REALNAME]];
			
			NSString* filename = nil;
			
			if (filenameData) {
				filename = [[NSString alloc] initWithData: filenameData encoding: NSMacOSRomanStringEncoding];
				[self setFilename: filename];
				[filename release];
			}
			
			if (resourceFork) {
				[attrs setObject: resourceFork forKey: OPFileResourceForkData];
			}
			
			if (finderInfo) {
				[attrs setObject: finderInfo forKey: OPFinderInfo];
			}
			
			[self setFileAttributes: attrs];
			[attrs release];
		}
		return self;
	}
	
	[self autorelease];
	return nil;
}

- (NSData*) resourceForkContents
{
	return [[self fileAttributes] objectForKey: OPFileResourceForkData];
}

- (NSData*) finderInfo
{
	return [[self fileAttributes] objectForKey: OPFinderInfo];
}

@end