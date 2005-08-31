/* 
     $Id: OPApplefileContentCoder.m,v 1.6 2005/05/03 10:26:50 theisen Exp $

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
*/

#import <AppKit/AppKit.h>
#import "OPApplefileContentCoder.h"
#import "NSString+MessageUtils.h"
#import "NSAttributedString+MessageUtils.h"
#import "NSFileWrapper+OPApplefileExtensions.h"
#import "EDMessagePart+OPExtensions.h"
#import "OPMultimediaContentCoder.h"
#import "EDTextFieldCoder.h"
#import "MPWDebug.h"

@interface OPMultimediaContentCoder (PrivateAPI)
- (id)_encodeDataWithClass:(Class)targetClass;
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

#pragma options align=mac68k
    
   /* Following items define machine specific size (for porting). */

   typedef char            xchar8;         /* 8-bit field */
   typedef char            schar8;         /* signed 8-bit field */
   typedef unsigned char   uchar8;         /* unsigned 8-bit field */
   typedef short           xint16;         /* 16-bit field */
   typedef unsigned short  uint16;         /* unsigned 16-bit field */
   typedef long            xint32;         /* 32-bit field */
   typedef long            sint32;         /* signed 32-bit field */
   typedef unsigned long   uint32;         /* unsigned 32-bit field */

   /* REMINDER: the Motorola 680x0 is a big-endian architecture! */

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

   struct ASHeader /* header portion of AppleSingle */
   {
               /* AppleSingle = 0x00051600; AppleDouble = 0x00051607 */

       uint32 magicNum; /* internal file type tag */
       uint32 versionNum; /* format version: 2 = 0x00020000 */
       uchar8 filler[16]; /* filler, currently all bits 0 */
       uint16 numEntries; /* number of entries which follow */
   }; /* ASHeader */

   typedef struct ASHeader ASHeader;

   struct ASEntry /* one AppleSingle entry descriptor */
   {
       uint32 entryID; /* entry type: see list, 0 invalid */
       uint32 entryOffset; /* offset, in octets, from beginning */
                                   /* of file to this entry's data */
       uint32 entryLength; /* length of data in octets */
   }; /* ASEntry */

   typedef struct ASEntry ASEntry;

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

   #define AS_AFPDIRID     15 /* AFP directory ID */

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

   struct ASIconBW /* entry ID 5, standard Mac black and white icon */
   {
       uint32 bitrow[32]; /* 32 rows of 32 1-bit pixels */
   }; /* ASIconBW */

   typedef struct ASIconBW ASIconBW;

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

   struct ASFileDates      /* entry ID 8, file dates info */
   {
       sint32 create; /* file creation date/time */
       sint32 modify; /* last modification date/time */
       sint32 backup; /* last backup date/time */
       sint32 access; /* last access date/time */
   }; /* ASFileDates */

   typedef struct ASFileDates ASFileDates;

   /* See older Inside Macintosh, Volume II, page 115 for
    * PBGetFileInfo(), and Volume IV, page 155, for PBGetCatInfo().
    */

   /* entry ID 9, Macintosh Finder info & extended info */
   struct ASFinderInfo
   {
       FInfo ioFlFndrInfo; /* PBGetFileInfo() or PBGetCatInfo() */
       FXInfo ioFlXFndrInfo; /* PBGetCatInfo() (HFS only) */
   }; /* ASFinderInfo */

   typedef struct ASFinderInfo ASFinderInfo;

   struct ASMacInfo        /* entry ID 10, Macintosh file information */
   {

       uchar8 filler[3]; /* filler, currently all bits 0 */
       uchar8 ioFlAttrib; /* PBGetFileInfo() or PBGetCatInfo() */
   }; /* ASMacInfo */

   typedef struct ASMacInfo ASMacInfo;

   #define AS_PROTECTED    0x0002 /* protected bit */
   #define AS_LOCKED       0x0001 /* locked bit */

   /* NOTE: ProDOS-16 and GS/OS use entire fields.  ProDOS-8 uses low
    * order half of each item (low byte in access & filetype, low word
    * in auxtype); remainder of each field should be zero filled.
    */

   struct ASProdosInfo     /* entry ID 11, ProDOS file information */
   {
       uint16 access; /* access word */
       uint16 filetype; /* file type of original file */
       uint32 auxtype; /* auxiliary type of the orig file */
   }; /* ASProDosInfo */

   typedef struct ASProdosInfo ASProdosInfo;

   /* MS-DOS file attributes occupy 1 octet; since the Developer Note
    * is unspecific, I've placed them in the low order portion of the
    * field (based on example of other ASMacInfo & ASProdosInfo).
    */

   struct ASMsdosInfo      /* entry ID 12, MS-DOS file information */
   {
       uchar8 filler; /* filler, currently all bits 0 */
       uchar8 attr; /* _dos_getfileattr(), MS-DOS */
                                   /* interrupt 21h function 4300h */
   }; /* ASMsdosInfo */

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

   struct ASAfpInfo   /* entry ID 12, AFP server file information */
   {
       uchar8 filler[3]; /* filler, currently all bits 0 */
       uchar8 attr; /* file attributes */
   }; /* ASAfpInfo */

   typedef struct ASAfpInfo ASAfpInfo;

   #define AS_AFP_Invisible    0x01 /* file is invisible */
   #define AS_AFP_MultiUser    0x02 /* simultaneous access allowed */
   #define AS_AFP_System       0x04 /* system file */
   #define AS_AFP_BackupNeeded 0x40 /* new or modified (needs backup) */

   struct ASAfpDirId       /* entry ID 15, AFP server directory ID */
   {
       uint32 dirid; /* file's directory ID on AFP server */
   }; /* ASAfpDirId */

   typedef struct ASAfpDirId ASAfpDirId;

   /*
    * The format of an AppleSingle/AppleDouble header
    */
   struct AppleSingle /* format of disk file */
   {
       ASHeader header; /* AppleSingle header part */
       ASEntry  entry[1]; /* array of entry descriptors */
   /* uchar8  filedata[]; *//* followed by rest of file */
   }; /* AppleSingle */

   typedef struct AppleSingle AppleSingle;

   /*
    * FINAL REMINDER: the Motorola 680x0 is a big-endian architecture!
    */

   /* End of applefile.h */


@implementation OPApplefileContentCoder

+ (BOOL)canDecodeMessagePart:(EDMessagePart *)mpart
{
    return [mpart isApplefile];
}

+ (BOOL)canEncodeAttributedString:(NSAttributedString *)anAttributedString atIndex:(int)anIndex effectiveRange:(NSRangePointer)effectiveRange
/*"
   Decides if anAttributedString can be encoded starting at anIndex. If YES is returned effectiveRange 
   designates the range which can be encoded by this class. If NO is returned effectiveRange indicates
   the range which can not be encoded by this class.
   
   OPApplefileContentCoder can encode files that must contain a resource fork but no data fork 
   (for both OPAppleDoubleContentCoder has to be used).
   
   Nevertheless, OPApplefileContentCoder is used by OPAppleDoubleContentCoder with files that
   contain both a resource fork and a data fork. But - surprise - only the resource fork will
   be encoded. The magic number will be set accordingly (either to AppleSingle or AppleDouble).
"*/
{
    NSRange limitRange;
    NSTextAttachment *attachment;

//if (NSDebugEnabled) NSLog(@"OPApplefileContentCoder canEncodeAttributedString:");

    limitRange = NSMakeRange(anIndex, 1);
    
    attachment = [anAttributedString attribute:NSAttachmentAttributeName atIndex:anIndex longestEffectiveRange:effectiveRange inRange:limitRange];
    
    if (attachment)
    {
        NSFileWrapper *fileWrapper;
        
        fileWrapper = [attachment fileWrapper];
        
//#warning axel->all: no symbolic links at this time
        if ([fileWrapper isRegularFile])
        {
            if ( ([[fileWrapper regularFileContents] length] == 0) // no data fork...
                && ([[fileWrapper fileAttributes] objectForKey:OPFileResourceForkData] != nil) ) // ...but resource fork
            {
                return YES;
            }
        }
    }
    
    return NO;
}

- (NSData *)_appleSingeDoubleFromFileWrapper:(NSFileWrapper *)aFileWrapper
/*"
   Creates data containing an AppleSingle/AppleDouble structure with 3 entries:
     - resource fork
     - finder info
     - realname
"*/
{
    uint32 resourceForkSize, realnameSize, totalSize, currentFileDataOffset;
    uint16 numEntries = 0, currentEntryIndex;
    NSData *resourceForkData, *finderInfo, *realnameData;
    BOOL isAppleDouble = NO;
    NSDictionary *fileAttributes;
    NSData *result = nil;
    AppleSingle *appleSingle;
    
    fileAttributes = [aFileWrapper fileAttributes];
    
    // resource fork
    resourceForkData = [fileAttributes objectForKey:OPFileResourceForkData];
    resourceForkSize = [resourceForkData length];
    
    // finder info
    finderInfo = [fileAttributes objectForKey:OPFinderInfo];
    
    // realname
    realnameData = [[aFileWrapper filename] dataUsingEncoding:NSMacOSRomanStringEncoding allowLossyConversion:YES];
    
    realnameSize = [realnameData length];
        
    // is AppleDouble
    isAppleDouble = [[aFileWrapper regularFileContents] length] != 0;
    
    // calculate total size of the structure
    totalSize = sizeof(ASHeader);
    
    if (resourceForkData) 
    {
        totalSize += sizeof(ASEntry); // one entry for the resource fork
        totalSize += resourceForkSize;
        numEntries++;
    }
    
    if (finderInfo) 
    {
        totalSize += sizeof(ASEntry); // one entry for the finder info
        totalSize += sizeof(ASFinderInfo);
        numEntries++;
    }
    
    if (realnameData) // one entry for the realname
    {
        totalSize += sizeof(ASEntry); // one entry for the finder info
        totalSize += realnameSize;
        numEntries++;
    }
    
    currentFileDataOffset = sizeof(ASHeader) + numEntries * sizeof(ASEntry);
    currentEntryIndex = 0;
    
    // create structure
    appleSingle = malloc(totalSize);
    
    // fill structure
    
    // -- fill ASHeader
    {
        ASHeader *header;
        
        header = &(appleSingle->header);
        
        if (isAppleDouble)
            header->magicNum = 0x00051607;
        else
            header->magicNum = 0x00051600;
        
        header->versionNum = 0x00020000;
        
        memset(&(header->filler), 0, 16);
        
        header->numEntries = numEntries;
    }
    
    // -- fill ASEntrys and filedata
    
    // ---- AS_REALNAME
    if (realnameData)
    {
        ASEntry *entry;
        
        entry = &(appleSingle->entry[currentEntryIndex++]);
        
        entry->entryID = AS_REALNAME;
        entry->entryOffset = currentFileDataOffset;
        entry->entryLength = realnameSize;
        
        // fill in data
        memcpy(((void *)appleSingle) + currentFileDataOffset, [realnameData bytes], [realnameData length]);
        
        currentFileDataOffset += realnameSize;
    }
    
    // ---- AS_FINDERINFO
    if (finderInfo)
    {
        ASEntry *entry;
        ASFinderInfo *asFinderInfo;
        
        entry = &(appleSingle->entry[currentEntryIndex++]);
        
        entry->entryID = AS_FINDERINFO;
        entry->entryOffset = currentFileDataOffset;
        entry->entryLength = sizeof(ASFinderInfo);
        
        asFinderInfo = ((void *)appleSingle) + currentFileDataOffset;
        
        // clear data
        memset(asFinderInfo, 0, sizeof(ASFinderInfo));
        
        // fill in data
        memcpy(&(asFinderInfo->ioFlFndrInfo), [finderInfo bytes], [finderInfo length]);
//#warning "axel->all: FXInfo is missing... ' hope that doesn't matter as it's not required for non HFS filesystems."
        
        currentFileDataOffset += sizeof(ASFinderInfo);
    }
    
    // ---- AS_RESOURCE
    if (realnameData)
    {
        ASEntry *entry;
        
        entry = &(appleSingle->entry[currentEntryIndex++]);
        
        entry->entryID = AS_RESOURCE;
        entry->entryOffset = currentFileDataOffset;
        entry->entryLength = resourceForkSize;
        
        // fill in data
        memcpy(((void *)appleSingle) + currentFileDataOffset, [resourceForkData bytes], [resourceForkData length]);
        
        currentFileDataOffset += resourceForkSize;
    }
    
    result = [NSData dataWithBytes:appleSingle length:totalSize];
    
    free(appleSingle);
    
    return result;
}

- (id)initWithFileWrapper:(NSFileWrapper *)aFileWrapper
{
    NSString *theFilename;
    NSDictionary *attributes;
    NSNumber *posixPermissions;

    NSParameterAssert([aFileWrapper isRegularFile]);
    
    if (! (theFilename = [aFileWrapper filename]))
    {
        theFilename = [aFileWrapper preferredFilename];
    }
            
    // get the permissions
    attributes = [aFileWrapper fileAttributes];
    posixPermissions = [attributes objectForKey:NSFilePosixPermissions];
    
    if (posixPermissions)
    {
        xUnixMode = [[NSString xUnixModeString:[posixPermissions intValue]] retain];
    }

	[self setContentType:@"application/applefile"];
    return [super initWithData:[self _appleSingeDoubleFromFileWrapper:aFileWrapper] filename:theFilename];
}

- (id)_encodeSubpartsWithClass:(Class)targetClass subtype:(NSString *)subtype
{
    id messagePart = [super _encodeDataWithClass:targetClass];
        
    [messagePart setContentType:@"application/applefile" withParameters:[messagePart contentTypeParameters]];
         
    return messagePart;
}

- (NSData *)_dataForEntryID:(uint32)entryID
/*"
Returns the entry out of the applesingle/appledouble data. E.g. data fork or resource fork.
For possible parameter values see applefile.h.
  "*/
{
    AppleSingle *appleSingle;
    uint16 numEntries, i;
    ASEntry *entries;
    NSData *result = nil;
    
    appleSingle = (AppleSingle *)[data bytes];

    NSAssert( ((appleSingle->header).magicNum == 0x00051600) 
        || ((appleSingle->header).magicNum == 0x00051607), 
        @"Not a AppleSingle or AppleDouble.");
    
    // check version number
    NSAssert((appleSingle->header).versionNum >= 0x00020000, @"AppleSingle version number < 2. Not decodable.");
    
    // search in all entries for the given entry ID
    numEntries = (appleSingle->header).numEntries;
    
//    if (NSDebugEnabled) NSLog(@"sizeof(ASHeader) = %d = 26", sizeof(ASHeader));
//    if (NSDebugEnabled) NSLog(@"sizeof(ASHeader) = %d = 26", sizeof(ASHeader));
    
//    entries = (ASEntry *) ([data bytes] + 26);
    entries = appleSingle->entry;
    
    for (i = 0; i < numEntries; i++)
    {
//        if (NSDebugEnabled) NSLog(@"entry with ID = %u", entries[i].entryID);
        
        if (entries[i].entryID == entryID) 
        {
//            if (NSDebugEnabled) NSLog(@"Range = %@", NSStringFromRange(NSMakeRange(entries[i].entryOffset, entries[i].entryLength)));
            result = [data subdataWithRange:NSMakeRange(entries[i].entryOffset, entries[i].entryLength)]; 
        }
    }
    
    if (! result)
    {
        if (NSDebugEnabled) NSLog(@"entry %lu not found", entryID);
    }
    
    return result;
}

- (NSFileWrapper *)fileWrapper
{
    NSString *preferredFilename = nil;
    NSString *rawPreferredFilename;
    NSFileWrapper *result;
    NSData *dataFork, *resourceFork, *finderInfo, *realnameData;
    
    // get data fork
    if (! (dataFork = [self _dataForEntryID:AS_DATA]))
        dataFork = [NSData data];
        
    resourceFork = [self _dataForEntryID:AS_RESOURCE];
    finderInfo = [self _dataForEntryID:AS_FINDERINFO];
    realnameData = [self _dataForEntryID:AS_REALNAME];
    
    // prefer content type parameter filename but fallback to applesingle realname if not present
    rawPreferredFilename = [self filename];

    if (rawPreferredFilename != nil)
    {
        // use coder
        preferredFilename = [(EDTextFieldCoder *)[EDTextFieldCoder decoderWithFieldBody:rawPreferredFilename] text];
    }
    else
    {
        if (realnameData)
        {
            preferredFilename = [[[NSString alloc] initWithData:realnameData encoding:NSMacOSRomanStringEncoding] autorelease];
        }
        else
            preferredFilename = @"unknown attachment";
    }
    
    result = [[[NSFileWrapper alloc] initRegularFileWithContents:dataFork] autorelease];
    [result setPreferredFilename:preferredFilename]; // file name
    
    if (resourceFork || finderInfo)
    {
        // set resource fork data as attribute
        NSMutableDictionary *attributes;

        attributes = [[result fileAttributes] mutableCopy];
        
        if (resourceFork)
            [attributes setObject:resourceFork forKey:OPFileResourceForkData];
            
        if (finderInfo)
        {
            FInfo *fInfo;
            NSNumber *type, *creator;
            
            fInfo = (FInfo *)[finderInfo bytes];
            type = [NSNumber numberWithUnsignedLong:fInfo->fdType];
            creator = [NSNumber numberWithUnsignedLong:fInfo->fdCreator];
//            [attributes setObject:type forKey:NSFileHFSTypeCode];
//            [attributes setObject:creator forKey:NSFileHFSCreatorCode];
//#warning axel->axel: report NSFileWrapper bug (type and creator are not set and resource forks not supported)
            //
            [attributes setObject:finderInfo forKey:OPFinderInfo];
        }
        
        [result setFileAttributes:attributes]; 
        [attributes release];
    }
    
    return result;
}

- (NSAttributedString *)attributedString
{
    NSMutableAttributedString *result;
    
    result = [[[NSMutableAttributedString alloc] init] autorelease];

    [result appendAttachmentWithFileWrapper:[self fileWrapper]];
    
    return result;
}

@end
