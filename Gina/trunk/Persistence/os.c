/*
** 2005 November 29
**
** The author disclaims copyright to this source code.  In place of
** a legal notice, here is a blessing:
**
**    May you do good and not evil.
**    May you find forgiveness for yourself and forgive others.
**    May you share freely, never taking more than you give.
**
******************************************************************************
**
** This file contains OS interface code that is common to all
** architectures.
*/
#define _SQLITE_OS_C_ 1
#include "sqliteInt.h"
#include "os.h"
#undef _SQLITE_OS_C_

/*
 ** If the following function pointer is not NULL and if
 ** SQLITE_ENABLE_IOTRACE is enabled, then messages describing
 ** I/O active are written using this function.  These messages
 ** are intended for debugging activity only.
 */
void (*sqlite3_io_trace)(const char*, ...) = 0;

/*
 ** If the following global variable points to a string which is the
 ** name of a directory, then that directory will be used to store
 ** temporary files.
 **
 ** See also the "PRAGMA temp_store_directory" SQL command.
 */
char *sqlite3_temp_directory = 0;

/*
 ** Memory allocation routines that use SQLites internal memory
 ** memory allocator.  Depending on how SQLite is compiled, the
 ** internal memory allocator might be just an alias for the
 ** system default malloc/realloc/free.  Or the built-in allocator
 ** might do extra stuff like put sentinals around buffers to 
 ** check for overruns or look for memory leaks.
 **
 ** Use sqlite3_free() to free memory returned by sqlite3_mprintf().
 */
void sqlite3_free(void *p){ if( p ) sqlite3OsFree(p); }
void *sqlite3_malloc(int nByte){ return nByte>0 ? sqlite3OsMalloc(nByte) : 0; }
void *sqlite3_realloc(void *pOld, int nByte){ 
	if( pOld ){
		if( nByte>0 ){
			return sqlite3OsRealloc(pOld, nByte);
		}else{
			sqlite3OsFree(pOld);
			return 0;
		}
	}else{
		return sqlite3_malloc(nByte);
	}
}

/*
 ** Invoke the given busy handler.
 **
 ** This routine is called when an operation failed with a lock.
 ** If this routine returns non-zero, the lock is retried.  If it
 ** returns 0, the operation aborts with an SQLITE_BUSY error.
 */
int sqlite3InvokeBusyHandler(BusyHandler *p){
	int rc;
	if( p==0 || p->xFunc==0 || p->nBusy<0 ) return 0;
	rc = p->xFunc(p->pArg, p->nBusy);
	if( rc==0 ){
		p->nBusy = -1;
	}else{
		p->nBusy++;
	}
	return rc; 
}

/*
** The following routines are convenience wrappers around methods
** of the OsFile object.  This is mostly just syntactic sugar.  All
** of this would be completely automatic if SQLite were coded using
** C++ instead of plain old C.
*/
int sqlite3OsClose(OsFile **pId){
  OsFile *id;
  if( pId!=0 && (id = *pId)!=0 ){
    return id->pMethod->xClose(pId);
  }else{
    return SQLITE_OK;
  }
}
int sqlite3OsOpenDirectory(OsFile *id, const char *zName){
  return id->pMethod->xOpenDirectory(id, zName);
}
int sqlite3OsRead(OsFile *id, void *pBuf, int amt){
  return id->pMethod->xRead(id, pBuf, amt);
}
int sqlite3OsWrite(OsFile *id, const void *pBuf, int amt){
  return id->pMethod->xWrite(id, pBuf, amt);
}
int sqlite3OsSeek(OsFile *id, i64 offset){
  return id->pMethod->xSeek(id, offset);
}
int sqlite3OsTruncate(OsFile *id, i64 size){
  return id->pMethod->xTruncate(id, size);
}
int sqlite3OsSync(OsFile *id, int fullsync){
  return id->pMethod->xSync(id, fullsync);
}
void sqlite3OsSetFullSync(OsFile *id, int value){
  id->pMethod->xSetFullSync(id, value);
}
int sqlite3OsFileSize(OsFile *id, i64 *pSize){
  return id->pMethod->xFileSize(id, pSize);
}
int sqlite3OsLock(OsFile *id, int lockType){
  return id->pMethod->xLock(id, lockType);
}
int sqlite3OsUnlock(OsFile *id, int lockType){
  return id->pMethod->xUnlock(id, lockType);
}
int sqlite3OsCheckReservedLock(OsFile *id){
  return id->pMethod->xCheckReservedLock(id);
}
int sqlite3OsSectorSize(OsFile *id){
  int (*xSectorSize)(OsFile*) = id->pMethod->xSectorSize;
  return xSectorSize ? xSectorSize(id) : SQLITE_DEFAULT_SECTOR_SIZE;
}

#if defined(SQLITE_TEST) || defined(SQLITE_DEBUG)
  /* These methods are currently only used for testing and debugging. */
  int sqlite3OsFileHandle(OsFile *id){
    return id->pMethod->xFileHandle(id);
  }
  int sqlite3OsLockState(OsFile *id){
    return id->pMethod->xLockState(id);
  }
#endif

#ifdef SQLITE_ENABLE_REDEF_IO
/*
** A function to return a pointer to the virtual function table.
** This routine really does not accomplish very much since the
** virtual function table is a global variable and anybody who
** can call this function can just as easily access the variable
** for themselves.  Nevertheless, we include this routine for
** backwards compatibility with an earlier redefinable I/O
** interface design.
*/
struct sqlite3OsVtbl *sqlite3_os_switch(void){
  return &sqlite3Os;
}
#endif
