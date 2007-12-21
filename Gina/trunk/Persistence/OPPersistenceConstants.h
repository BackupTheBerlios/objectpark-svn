//  Copyright 2005 Dirk Theisen <d.theisen@objectpark.org>. All rights reserved.
//
//
//  OPPersistence - a persistent object library for Cocoa.
//
//  For non-commercial use, you can redistribute this library and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your option) any later version.
//
//  This library is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//  Lesser General Public License for more details:
//
//  <http://www.gnu.org/copyleft/lesser.html#SEC1>
//
//  You should have received a copy of the GNU Lesser General Public
//  License along with this library; if not, write to the Free Software
//  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
//
//  For commercial use, commercial licenses and redistribution licenses
//  are available - including support - from the author,
//  Dirk Theisen <d.theisen@objectpark.org> for a reasonable fee.
//
//  DEFINITION Commercial use
//  This library is used commercially whenever the library or derivative work
//  is charged for more than the price for shipping and handling.
//

//#include <stdlib.h>
//#include <string.h>
//#include <unistd.h>
//#import <OPDebug/OPLog.h>

// Class ID (CID), index in the transient class table
//#define CID unsigned

/*
 * OID - object id // 64 bit int
 * CID - class/type id, 1 byte wide
 * LID - local object id, 1 word-1 bytes wide
 * LID and CID can be encoded into an OID and back.
 */
#define OID UInt64 
#define NILOID (OID)0L
#define ROWID UInt64

#define LID OID
#define LIDBITS 56
#define CID unsigned short
#define CIDFromOID(x) (((OID)x)>>LIDBITS)
#define LIDFromOID(x) ((((OID)x)<<8)>>8)
#define MakeOID(c,l)  ((((OID)c)<<LIDBITS)+l)

// Debug Domain
#define OPPERSISTENCE OPL_DOMAIN @"OPPersistence"
