//
//  NSWorkspace+OPExtensions.m
//  Gina
//
//  Created by Dirk Theisen on 07.07.06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "NSWorkspace+OPExtensions.h"


@implementation NSWorkspace (OPExtensions)

- (NSString*) downloadDirectory 
/*" Returns the user's std. download directory path taken from Internet Config. "*/
{ 
	// Code modified from Uli Kusterer's UKPathUtilities:
	ICInstance	 inst = NULL; 
	ICFileSpec	 fSpec; 
	long length = kICFileSpecHeaderSize; 
	FSRef fref; 
	unsigned char fpath[PATH_MAX] = { 0 }; 
	if (ICStart(&inst, 0L ) != noErr) goto cleanup; 
	ICGetPref(inst, kICDownloadFolder, NULL, &fSpec, &length); 
	ICStop(inst); 
	if (FSpMakeFSRef( &fSpec.fss, &fref ) != noErr ) goto cleanup; 
	if (FSRefMakePath( &fref, fpath, 1024 ) != noErr ) goto cleanup; 
cleanup: ;
	if (fpath[0] == 0) return [NSHomeDirectory() stringByAppendingPathComponent: @"Desktop"];
	return [NSString stringWithUTF8String: (char*)fpath]; 
}

@end
