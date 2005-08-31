/* MPWDebug.h created by theisen on Sun 31-Dec-2000 */

#import <Foundation/NSDebug.h>

#define MPWAssertFail(command) \
{ \
    BOOL _mpwthrown_ = NO; \
    NS_DURING \
        command; \
    NS_HANDLER \
        _mpwthrown_ = YES; \
    NS_ENDHANDLER \
    NSAssert(_mpwthrown_, @"MPWAssertFail: Expected Exception not thrown."); \
}

#define MPWParameterAssert NSParameterAssert
#define MPWAssertNotNil(cond) NSAssert((cond), @"(cond) should never be nil.");

#define MPWAssertIsEqual(obj1,obj2) NSAssert4([(obj1) isEqual: (obj2)],@"Object at 0x%x(%@) should be equal to 0x%x(%@)", (obj1), (obj1), (obj2), (obj2))

#define MPWAssertNotEqual(obj1,obj2) NSAssert4(![(obj1) isEqual: (obj2)],@"Object at 0x%x(%@) should be equal to 0x%x(%@)", (obj1), (obj1), (obj2), (obj2))

#define MPWAssertSame(val1,val2) NSAssert3((val1)==(val2),@"%@: (val1) (%d) should be the same as (val2) (%d)", NSStringFromSelector(_cmd), (val1), (val2))

#define MPWAssertNotSame(val1,val2) NSAssert2((val1)!=(val2),@"(val1) (%d) should not be equal to (val2) (%d)", (val1), (val2))

#define MPWMethodNotImplemented() [NSException raise: @"OPMethodNotImplemented" format: @"Invocation of unimplemented %@ method %@.", [self class], NSStringFromSelector(_cmd)]

#define MPWFunctionNotImplemented() [NSException raise: @"OPFunctionImplementationMissingException" format: @""];

#define MPWDebugLog if (NSDebugEnabled) NSLog

#define MPWClassIsAbstract() [NSException raise: @"MPWClassIsAbstract" format: @"Class %@ is abstract. Create instances of subclasses only. (method %@).", [self class], NSStringFromSelector(_cmd)]
