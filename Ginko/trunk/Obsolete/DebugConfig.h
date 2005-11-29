// This file defines the debug parameters for the current application.

// This first set defines the debug domains for the current application.
// Be sure those indexes do not overlap.
// OPDEBUGDOMAINMAX defines the maximum index allowed (default: 64)

#define OPDEBUGDOMAINMAX 64
#define TESTDEBUG 0
#define NNTPDEBUG 1
#define POPDEBUG 2
#define SMTPDEBUG 3
#define STREAMDEBUG 4
#define SSLDEBUG 5
#define FILTERDEBUG 6     // used in GinkoNG
#define JOBDEBUG 7        // used in GinkoNG
#define KEYCHAINDEBUG 8   // used in GinkoNG
#define MESSAGEDEBUG 9

// This set defines the debug levels applicable to each domain.
// Individual developers can overwrite this settings by setting
// the corresponding environment variables to the level they
// need.
// Predefined debug levels are:
// OPNONE, OPINFO, OPWARNING, OPERROR, OPXERROR
#define OPDEBUGLEVELCONFIG \
SETDEBUGLEVEL(TESTDEBUG, OPNONE); \
SETDEBUGLEVEL(NNTPDEBUG, OPALL); \
SETDEBUGLEVEL(POPDEBUG, OPALL); \
SETDEBUGLEVEL(SMTPDEBUG, OPALL); \
SETDEBUGLEVEL(STREAMDEBUG, OPALL); \
SETDEBUGLEVEL(SSLDEBUG, OPALL); \
SETDEBUGLEVEL(FILTERDEBUG, OPALL); \
SETDEBUGLEVEL(JOBDEBUG, OPALL); \
SETDEBUGLEVEL(KEYCHAINDEBUG, OPALL); \
SETDEBUGLEVEL(MESSAGEDEBUG, OPALL);
