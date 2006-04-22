//
//  OPSASL.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 21.04.06.
//  Copyright 2006 Objectpark Group. All rights reserved.
//

#import "OPSASL.h"
#include <string.h>
#include <sasl.h>

/* callbacks supported by OPSASL. */
static sasl_callback_t callbacks[] = 
{
	{
		SASL_CB_GETREALM, NULL, NULL  /* we'll just use an interaction if this comes up */
	}, 
	{
		SASL_CB_USER, NULL, NULL      /* we'll just use an interaction if this comes up */
	}, 
	{
		SASL_CB_AUTHNAME, NULL, NULL /* A mechanism should call getauthname_func if it needs the authentication name */
	}, 
	{ 
		SASL_CB_PASS, NULL, NULL      /* Call getsecret_func if need secret */
	}, 
	{
		SASL_CB_LIST_END, NULL, NULL
	}
};

@implementation OPSASL

+ (void)initialize
{
	static BOOL initialized = NO;
	
	if (! initialized)
	{
		initialized = YES;
		sasl_client_init(callbacks);
	}
}

@end
