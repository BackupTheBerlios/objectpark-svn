#include <stdlib.h>
#include <string.h>
#include <unistd.h>


// Class ID (CID), index in the transient class table
#define CID unsigned

/*
 * OID - object id // 64 bit int
 * CID - class/type id, 1 byte wide
 * LID - local object id, 1 word-1 bytes wide
 * LID and CID can be encoded into an OID and back.
 */
#define OID long long 
#define LIDBITS 56
#define CIDFromOID(x) (x>>LIDBITS)
#define LIDFromOID(x) ((x<<8)>>8)
#define MakeOID(c,o)  ((((OID)c)<<LIDBITS)+o)