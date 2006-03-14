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
#import <OPDebug/OPLog.h>

#define NSFILEWRAPPEREXTENSIONS OPL_DOMAIN @"NSFILEWRAPPEREXTENSIONS"

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

NSString *OPFileResourceForkData = @"OPFileResourceForkData";
NSString *OPFinderInfo = @"OPFinderInfo";

@implementation NSFileWrapper (OPApplefileExtensions)

- (id)initWithPath: (NSString*) path forksAndFinderInfo:(BOOL)forksAndFinderInfo
/*"
   If forksAndFinderInfo is YES then adds the resource fork and the finder info 
   to the file's attributes.
"*/
{
    if(! [self initWithPath:path])
        return nil;
    
    if (forksAndFinderInfo) // post process the file wrapper to add the resource fork and finder info
    {
        [self addForksAndFinderInfoWithPath:path];
    }
    
    return self;
}

- (void) addForksAndFinderInfoWithPath: (NSString*) path
/*"Adds resource fork and finder info to the file attributes."*/
{
    if (NSDebugEnabled) NSLog(@"addForksAndFinderInfoWithPath:%@", path);
    
    // if directory/folder descent
    if ([self isDirectory])
    {
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
        }
        else
        {
            finderInfo = [NSData dataWithBytes:catalogInfo.finderInfo length:sizeof(FInfo)];
        }
        
        /*  deprecated stuff
        // fsRef -> fsSpec
        // http://homepage.mac.com/troy_stephens/software/objects/IconFamily/
        err = FSGetCatalogInfo(&fsRef, kFSCatInfoNone, NULL, NULL, &fsSpec, NULL);
        if (err != noErr)
        {
            NSLog(@"Unable to get an FSSpec for the file %@ (err = %d).", path, err);
        }
        else
        {
            // get Finder info if given:
            
            
            err = FSpGetFInfo(&fsSpec, &fndrInfo);
            if (err != noErr)
            {
                NSLog(@"Unable to set finder info of file %@ (err = %d).", path, err);
            }
            else
            {
                finderInfo = [NSData dataWithBytes:&fndrInfo length:sizeof(FInfo)];
            }
        }
        */
        
        // add resource fork to attributes
        {
            // set resource fork data as attribute
            NSMutableDictionary *attributes;
    
            attributes = [[self fileAttributes] mutableCopy];
            
            if (resourceForkData)
            {
if (NSDebugEnabled) NSLog(@"adding resource fork.");
            
                [attributes setObject: resourceForkData forKey:OPFileResourceForkData];
            }
            
            if (finderInfo)
            {
                FInfo *fInfo;
                NSNumber *type, *creator;

if (NSDebugEnabled) NSLog(@"adding finder info.");
                            
                fInfo = (FInfo *)[finderInfo bytes];
                type = [NSNumber numberWithUnsignedLong:fInfo->fdType];
                creator = [NSNumber numberWithUnsignedLong:fInfo->fdCreator];
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
}

//#warning axel->all: This is not atomic at the moment. Regardless of the atomicFlag.
- (BOOL)writeForksToFile: (NSString*) path atomically:(BOOL)atomicFlag updateFilenames:(BOOL)updateNamesFlag
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
    
    if (! [self writeToFile:path atomically:atomicFlag updateFilenames:updateNamesFlag])
        return NO;
    
    // take care of resource fork
    
    // check if resource fork exists
    if (! (resourceForkData = [[self fileAttributes] objectForKey:OPFileResourceForkData]))
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
    if (finderInfo = [[self fileAttributes] objectForKey:OPFinderInfo])
    {
        if (NSDebugEnabled) NSLog(@"Setting FinderInfo.");   
        
        FSCatalogInfo catalogInfo;
        FInfo fndrInfo;
                        
        [finderInfo getBytes:&fndrInfo length:sizeof(FInfo)];
            
#warning help needed here! probably not correct!
        *(catalogInfo.finderInfo) = (UInt8 *)&fndrInfo;
        
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

@end
