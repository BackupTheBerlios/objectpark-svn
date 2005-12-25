//
//  GIFulltextIndexCenter.m
//  GinkoVoyager
//
//  Created by Axel Katerbau on 18.04.05.
//  Copyright 2005 The Objectpark Group <http://www.objectpark.org>. All rights reserved.
//

#import "GIFulltextIndexCenter.h"
#import "NSApplication+OPExtensions.h"
#import "GIApplication.h"
#import <OPDebug/OPLog.h>

@interface GIFulltextIndexCenter (JVMStuff)

+ (JNIEnv *)getJNIEnvironment;

@end

@implementation GIFulltextIndexCenter

static JNIEnv *env = nil;

+ (void)initialize
{
    env = [self getJNIEnvironment];
    /*
    NSString *lucenePath = [@":" stringByAppendingString:[[NSBundle mainBundle] pathForResource:@"lucene-1.4.3" ofType:@"jar"]];
    
    jvm = [[NSJavaVirtualMachine alloc] initWithClassPath:[[NSJavaVirtualMachine defaultClassPath] stringByAppendingString:lucenePath]];    
     */
}

+ (NSString *)fulltextIndexPath
{
    static NSString *path = nil;
    
    @synchronized(self)
    {
        if (!path) path = [[[GIApp applicationSupportPath] stringByAppendingPathComponent:@"FulltextIndex"] retain];
    }
    return path;
}

- (id)init
{
    return nil;
}

+ (jclass)documentClass
{
    jclass documentClass = NULL;

    if (! documentClass)
    {
        documentClass = (*env)->FindClass(env, "org/apache/lucene/document/Document");
        NSAssert(documentClass != NULL, @"org.apache.lucene.document.Document couldn't be found.");
    }
    
    return documentClass;
}

+ (jobject)documentNew 
{
    jobject document = NULL;
    jmethodID cid = NULL;
    
    if (! cid)
    {
        cid = (*env)->GetMethodID(env, [self documentClass], "<init>", "()V");
        NSAssert(cid != NULL, @"org.apache.lucene.document.Document constructor couldn't be found.");
    }
    
    document = (*env)->NewObject(env, [self documentClass], cid);
        
    return document;
}

+ (jclass)fieldClass
{
    jclass fieldClass = NULL;
    
    if (! fieldClass)
    {
        fieldClass = (*env)->FindClass(env, "org/apache/lucene/document/Field");
        NSAssert(fieldClass != NULL, @"org.apache.lucene.document.Field couldn't be found.");
    }
    
    return fieldClass;
}

+ (jclass)dateFieldClass
{
    jclass dateFieldClass = NULL;
    
    if (! dateFieldClass)
    {
        dateFieldClass = (*env)->FindClass(env, "org/apache/lucene/document/DateField");
        NSAssert(dateFieldClass != NULL, @"org.apache.lucene.document.DateField couldn't be found.");
    }
    
    return dateFieldClass;
}

+ (void)document:(jobject)aDocument addField:(jobject)aField
{
    jmethodID mid = NULL;
    
    if (! mid)
    {
        mid = (*env)->GetMethodID(env, [self documentClass], "add", "(Lorg/apache/lucene/document/Field;)V");
    }
    
    (*env)->CallObjectMethod(env, aDocument, mid, aField);
}

+ (void)document:(jobject)document addTextFieldWithName:(NSString *)name text:(jstring)textString
{
    jmethodID mid = NULL;
    
    if (! mid)
    {
        mid = (*env)->GetStaticMethodID(env, [self fieldClass], "Text", "(Ljava/lang/String;Ljava/lang/String;)Lorg/apache/lucene/document/Field;");
        NSAssert(mid != NULL, @"Text static method couldn't be found.");
    }
    
    jstring nameString = (*env)->NewStringUTF(env, [name UTF8String]);
    NSAssert(nameString != NULL, @"nameString not converted.");
    
    jobject result = (*env)->CallStaticObjectMethod(env, [self fieldClass], mid, nameString, textString);
    NSAssert(result != NULL, @"Text static method doesn't generate a Field object.");
    
    //(*env)->DeleteLocalRef(env, nameString);
    
    [self document:document addField:result];
}

+ (void)document:(jobject)document addKeywordFieldWithName:(NSString *)name text:(jstring)textString
{
    jmethodID mid = NULL;
    
    if (! mid)
    {
        mid = (*env)->GetStaticMethodID(env, [self fieldClass], "Keyword", "(Ljava/lang/String;Ljava/lang/String;)Lorg/apache/lucene/document/Field;");
        NSAssert(mid != NULL, @"Keyword static method couldn't be found.");
    }

    jstring nameString = (*env)->NewStringUTF(env, [name UTF8String]);
    NSAssert(nameString != NULL, @"nameString not converted.");

    jobject result = (*env)->CallStaticObjectMethod(env, [self fieldClass], mid, nameString, textString);
    NSAssert(result != NULL, @"Keyword static method doesn't generate a Field object.");
    
    //(*env)->DeleteLocalRef(env, nameString);

    [self document:document addField:result];
}

NSString *stringFromJstring(jstring aJstring) {
    const char *str;
    str = (*env)->GetStringUTFChars(env, aJstring, NULL);
    if (str == NULL) {
        return NULL; /* OutOfMemoryError already thrown */
    }
    
    NSString *result = [[NSString alloc] initWithCString:str encoding:NSUTF8StringEncoding];
    (*env)->ReleaseStringUTFChars(env, aJstring, str);
    
    return result;
}

+ (NSString *)objectToString:(jobject)anObject
{
    jmethodID mid = NULL;

    if (! mid)
    {
        mid = (*env)->GetMethodID(env, (*env)->GetObjectClass(env, anObject), "toString", "()Ljava/lang/String;");
        NSAssert(mid != NULL, @"toString not found");
    }
    
    jstring javaResult = (*env)->CallObjectMethod(env, anObject, mid);
    NSString *result = stringFromJstring(javaResult);
    //(*env)->DeleteLocalRef(env, javaResult);
    
    return result;
}

+ (jstring)dateFieldTimeToString:(unsigned long long)millis
{
    jmethodID mid = NULL;
    
    if (! mid)
    {
        mid = (*env)->GetStaticMethodID(env, [self dateFieldClass], "timeToString", "(J)Ljava/lang/String;");
        NSAssert(mid != NULL, @"timeToString static method couldn't be found.");
        jthrowable exc = (*env)->ExceptionOccurred(env);
        if (exc) 
        {
            /* We don't do much with the exception, except that
            we print a debug message for it, clear it. */
            (*env)->ExceptionDescribe(env);
            (*env)->ExceptionClear(env);
        }
    }
    
    jlong javaMillis = (jlong)millis;
    jstring result = (*env)->CallStaticObjectMethod(env, [self dateFieldClass], mid, javaMillis);
    jthrowable exc = (*env)->ExceptionOccurred(env);
    if (exc) 
    {
        /* We don't do much with the exception, except that
        we print a debug message for it, clear it. */
        (*env)->ExceptionDescribe(env);
        (*env)->ExceptionClear(env);
    }
    NSAssert(result != NULL, @"timeToString static method doesn't generate a string object.");
    
    return result;
}

+ (jobject)luceneDocumentFromMessage:(id)aMessage
{
    NSParameterAssert(aMessage != nil);
    
    jobject document = [self documentNew];
    
    // message id
    NSString *messageId = [aMessage valueForKey:@"messageId"];
    NSAssert([messageId length] > 0, @"fatal error: message id not present.");
    jstring messageIdJavaString = (*env)->NewStringUTF(env, [messageId UTF8String]);
    NSAssert(messageIdJavaString != NULL, @"textString not converted.");

    [self document:document addKeywordFieldWithName:@"id" text:messageIdJavaString];
    
    //(*env)->DeleteLocalRef(env, messageIdJavaString);
    
    // date
    NSCalendarDate *date = [aMessage valueForKey:@"date"];
    double millis = (double)([date timeIntervalSince1970] * 1000.0);
    @try
    {
        jstring dateJavaString = [self dateFieldTimeToString:(unsigned long long)millis];
        [self document:document addKeywordFieldWithName:@"date" text:dateJavaString];
        //(*env)->DeleteLocalRef(env, dateJavaString);
    }
    @catch(NSException *localException)
    {
        NSLog(@"Date %@ could not be fulltext indexed", date);
    }
    
    // subject
    NSString *subject = [aMessage valueForKey:@"subject"];
    if (![subject length]) subject = @"";
    jstring subjectJavaString = (*env)->NewStringUTF(env, [subject UTF8String]);
    [self document:document addKeywordFieldWithName:@"subject" text:subjectJavaString];
    //(*env)->DeleteLocalRef(env, subjectJavaString);
    
    // author
    NSString *author = [aMessage valueForKey:@"senderName"];
    jstring authorJavaString = (*env)->NewStringUTF(env, [author UTF8String]);
    [self document:document addKeywordFieldWithName:@"author" text:authorJavaString];
    //(*env)->DeleteLocalRef(env, authorJavaString);
    
    // body
    NSString *body = [aMessage valueForKey:@"messageBodyAsPlainString"];
    jstring bodyJavaString = (*env)->NewStringUTF(env, [body UTF8String]);
    [self document:document addTextFieldWithName:@"body" text:bodyJavaString];
    //(*env)->DeleteLocalRef(env, bodyJavaString);
    
    return document;
}

+ (jclass)standardAnalyzerClass
{
    jclass analyzerClass = NULL;
    
    if (! analyzerClass)
    {
        analyzerClass = (*env)->FindClass(env, "org/apache/lucene/analysis/standard/StandardAnalyzer");
        NSAssert(analyzerClass != NULL, @"org.apache.lucene.analysis.standard.StandardAnalyzer couldn't be found.");
    }
    
    return analyzerClass;
}

+ (jobject)standardAnalyzerNew
{
    jobject analyzer = NULL;
    jmethodID cid = NULL;
    
    if (! cid)
    {
        cid = (*env)->GetMethodID(env, [self standardAnalyzerClass], "<init>", "()V");
        NSAssert(cid != NULL, @"org.apache.lucene.analysis.standard.StandardAnalyzer constructor couldn't be found.");
    }
    
    analyzer = (*env)->NewObject(env, [self standardAnalyzerClass], cid);
    NSAssert(analyzer != NULL, @"org.apache.lucene.analysis.standard.StandardAnalyzer couldn't be instantiated.");
    
    return analyzer;
}

+ (jclass)indexWriterClass
{
    jclass indexWriterClass = NULL;
    
    if (! indexWriterClass)
    {
        indexWriterClass = (*env)->FindClass(env, "org/apache/lucene/index/IndexWriter");
        NSAssert(indexWriterClass != NULL, @"org.apache.lucene.index.IndexWriter couldn't be found.");
    }
    
    return indexWriterClass;
}

+ (jobject)indexWriter
/*" Private method. Should only be used inside a synchronized context. "*/
{
    jboolean shouldCreateNewIndex = YES;
        
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self fulltextIndexPath]]) shouldCreateNewIndex = NO;
    
    jmethodID cid = NULL;
    
    if (! cid)
    {
        cid = (*env)->GetMethodID(env, [self indexWriterClass], "<init>", "(Ljava/lang/String;Lorg/apache/lucene/analysis/Analyzer;Z)V");
        NSAssert(cid != NULL, @"(Ljava/lang/String;Lorg/apache/lucene/analysis/Analyzer;Z) constructor couldn't be found.");
    }
    
    jstring javaIndexPath = NULL;
    
    javaIndexPath = (*env)->NewStringUTF(env, [[self fulltextIndexPath] UTF8String]);
    jthrowable exc = (*env)->ExceptionOccurred(env);
    if (exc) 
    {
        /* We don't do much with the exception, except that
        we print a debug message for it, clear it. */
        (*env)->ExceptionDescribe(env);
        (*env)->ExceptionClear(env);
    }
    
    jobject analyzer = [self standardAnalyzerNew];
    
    //NSLog(@"ANALYZER CLASS = %s", (*env)->GetObjectClass(env, analyzer));
    
    jobject indexWriter = (*env)->NewObject(env, [self indexWriterClass], cid, javaIndexPath, analyzer, shouldCreateNewIndex);
    //(*env)->DeleteLocalRef(env, javaIndexPath);
    
    return indexWriter;
}

+ (void)indexWriter:(jobject)writer addDocument:(jobject)document
{    
    jclass indexWriterClass = (*env)->FindClass(env, "org/apache/lucene/index/IndexWriter");
    NSAssert(indexWriterClass != NULL, @"org.apache.lucene.index.IndexWriter couldn't be found.");
    
    jmethodID mid = (*env)->GetMethodID(env, indexWriterClass, "addDocument", "(Lorg/apache/lucene/document/Document;)V");
    NSAssert(mid != NULL, @"addDocument method couldn't be found.");

    (*env)->CallVoidMethod(env, writer, mid, document);
    
    jthrowable exc = (*env)->ExceptionOccurred(env);
    if (exc) 
    {
        /* We don't do much with the exception, except that
        we print a debug message for it, clear it. */
        (*env)->ExceptionDescribe(env);
        (*env)->ExceptionClear(env);
    }
}

+ (void)indexWriterClose:(jobject)writer
{
    jclass indexWriterClass = (*env)->FindClass(env, "org/apache/lucene/index/IndexWriter");
    NSAssert(indexWriterClass != NULL, @"org.apache.lucene.index.IndexWriter couldn't be found.");
    
    jmethodID mid = (*env)->GetMethodID(env, indexWriterClass, "close", "()V");
    NSAssert(mid != NULL, @"close method couldn't be found.");
    
    (*env)->CallVoidMethod(env, writer, mid);
}

+ (void)indexWriterOptimize:(jobject)writer
{
    jmethodID mid = NULL;
    
    if (! mid)
    {
        mid = (*env)->GetMethodID(env, [self indexWriterClass], "optimize", "()V");
        NSAssert(mid != NULL, @"optimize method couldn't be found.");
    }
    
    (*env)->CallVoidMethod(env, writer, mid);
}

+ (void)addMessages:(NSArray *)someMessages
{
    @synchronized(self)
    {
        if ((*env)->PushLocalFrame(env, 50) < 0) {NSLog(@"Out of memory!"); exit(1);}
        jobject indexWriter = [self indexWriter];
        NSAssert(indexWriter != NULL, @"IndexWriter could not be created.");
        
        @try
        {
            NSEnumerator *enumerator = [someMessages objectEnumerator];
            id message;
            int counter = 1;
            while (message = [enumerator nextObject])
            {;
                @try
                {
                    if ((*env)->PushLocalFrame(env, 500) < 0) {NSLog(@"Out of memory!"); break;}
                    jobject doc = [self luceneDocumentFromMessage:message];
                    NSLog(@"\nmade document = %@\n", [self objectToString:doc]);
                    NSLog(@"\nmade document no = %d\n", counter++);

                    [self indexWriter:indexWriter addDocument:doc];
                }
                @catch (NSException *localException)
                {
                    @throw localException;
                }
                @finally
                {
                    (*env)->PopLocalFrame(env, NULL);
                }
            }
        }
        @catch (NSException *localException)
        {
            @throw localException;
        }
        @finally
        {
            [self indexWriterClose:indexWriter];
            (*env)->PopLocalFrame(env, NULL);
        }
    }
}

+ (void)removeMessagesWithIds:(NSArray *)someMessageIds
{
    if ([someMessageIds count])
    {;
        @synchronized(self)
        {
            JNIEnv *env = [self getJNIEnvironment];
            jclass cls;
            jmethodID mid;
            jstring jstr;
            jclass stringClass;
            jobjectArray args;
            
            cls = (*env)->FindClass(env, "Prog");
            if (cls == NULL) {
                exit(4);
            }
            
            mid = (*env)->GetStaticMethodID(env, cls, "main",
                                            "([Ljava/lang/String;)V");
            if (mid == NULL) {
                exit(1);
            }
            jstr = (*env)->NewStringUTF(env, " from C!");
            if (jstr == NULL) {
                exit(2);
            }
            stringClass = (*env)->FindClass(env, "java/lang/String");
            args = (*env)->NewObjectArray(env, 1, stringClass, jstr);
            if (args == NULL) {
                exit(3);
            }
            (*env)->CallStaticVoidMethod(env, cls, mid, args);
            
            /*
             //LuceneFSDirectory *directory = [LuceneFSDirectoryClass getDirectory:[self fulltextIndexPath] :NO];
             //id javaString = [[NSClassFromString(@"java.lang.StringBuffer") newWithSignature:@"(Ljava/lang/String;)", [self fulltextIndexPath]] autorelease];
             //LuceneIndexReader *indexReader = [LuceneIndexReaderClass open:[self fulltextIndexPath]];
             id javaString = [[NSClassFromString(@"java.lang.StringBuffer") newWithSignature:@"(Ljava/lang/String;)", [self fulltextIndexPath]] autorelease];
             
             LuceneIndexReader *indexReader = [LuceneIndexReaderClass open:javaString];
             NSAssert(indexReader != nil, @"Could not create Lucene index reader.");
             
             @try
             {
                 NSEnumerator *enumerator = [someMessageIds objectEnumerator];
                 NSString *messageId;
                 
                 while (messageId = [enumerator nextObject])
                 {
                     //LuceneTerm *term = [[LuceneTermClass newWithSignature:@"(Ljava/lang/String;Ljava/lang/String;)", @"id", messageId] autorelease];
                     
                     id fld = [[NSClassFromString(@"java.lang.StringBuffer") newWithSignature:@"(Ljava/lang/String;)", @"id"] autorelease];
                     id txt = [[NSClassFromString(@"java.lang.StringBuffer") newWithSignature:@"(Ljava/lang/String;)", messageId] autorelease];
                     
                     int count = [indexReader delete:fld :txt];
                     NSAssert(count <= 1, @"Fatal error: Deleted more than one message for a single message id from fulltext index.");
                 }
             }
             @catch (NSException *localException)
             {
                 @throw localException;
             }
             @finally
             {
                 [indexReader close];
             }
             */
        }
    }
}

+ (void)optimize
{
    @synchronized(self)
    {;
        @try
        {
            if ((*env)->PushLocalFrame(env, 50) < 0) {NSLog(@"Out of memory!"); exit(1);}
            jobject indexWriter = [self indexWriter];
            [self indexWriterOptimize:indexWriter];
            [self indexWriterClose:indexWriter];
        }
        @catch (NSException *localException)
        {
            @throw localException;
        }
        @finally
        {
            (*env)->PopLocalFrame(env, NULL);
        }
    }
}

+ (jclass)indexSearcherClass
{
    jclass indexSearcherClass = NULL;
    
    if (! indexSearcherClass)
    {
        indexSearcherClass = (*env)->FindClass(env, "org/apache/lucene/search/IndexSearcher");
        NSAssert(indexSearcherClass != NULL, @"org.apache.lucene.search.IndexSearcher couldn't be found.");
    }
    
    return indexSearcherClass;
}

+ (jobject)indexSearcherNew
{
    jmethodID cid = NULL;
    
    if (! cid)
    {
        cid = (*env)->GetMethodID(env, [self indexSearcherClass], "<init>", "(Ljava/lang/String;)V");
        NSAssert(cid != NULL, @"(Ljava/lang/String;) constructor couldn't be found.");
    }
    
    jstring javaIndexPath = NULL;
    
    javaIndexPath = (*env)->NewStringUTF(env, [[self fulltextIndexPath] UTF8String]);
        
    jobject indexSearcher = (*env)->NewObject(env, [self indexSearcherClass], cid, javaIndexPath);
    
    return indexSearcher;
}

+ (jobject)indexSearcher:(jobject)searcher search:(jobject)aQuery
{
    jmethodID mid = NULL;
    
    if (! mid)
    {
        mid = (*env)->GetMethodID(env, [self indexSearcherClass], "search", "(Lorg/apache/lucene/search/Query;)Lorg/apache/lucene/search/Hits;");
        NSAssert(mid != NULL, @"search not found");
    }
    
    jobject result = (*env)->CallObjectMethod(env, searcher, mid, aQuery);
    
    return result;
}

+ (jclass)queryParserClass
{
    jclass queryParserClass = NULL;
    
    if (! queryParserClass)
    {
        queryParserClass = (*env)->FindClass(env, "org/apache/lucene/queryParser/QueryParser");
        NSAssert(queryParserClass != NULL, @"org.apache.lucene.queryParser.QueryParser couldn't be found.");
    }
    
    return queryParserClass;
}

+ (jobject)queryParserClassParseQueryString:(jstring)aQueryString defaultField:(jstring)defaultFieldName analyzer:(jstring)anAnalyzer
{
    jmethodID mid = NULL;
    
    if (! mid)
    {
        mid = (*env)->GetStaticMethodID(env, [self queryParserClass], "parse", "(Ljava/lang/String;Ljava/lang/String;Lorg/apache/lucene/analysis/Analyzer;)Lorg/apache/lucene/search/Query;");
        NSAssert(mid != NULL, @"parse static method couldn't be found.");
    }
        
    jobject result = (*env)->CallStaticObjectMethod(env, [self queryParserClass], mid, aQueryString, defaultFieldName, anAnalyzer);
    NSAssert(result != NULL, @"parse static method doesn't generate a Query object.");
        
    return result;
}

+ (jobject)hitsForQueryString:(NSString *)aQueryString
{
    jobject hits = NULL;
    
    @synchronized(self)
    {;
        @try
        {
            if ((*env)->PushLocalFrame(env, 250) < 0) {NSLog(@"Out of memory!"); exit(1);}
            jobject indexSearcher = [self indexSearcherNew];

            jobject standardAnalyzer = [self standardAnalyzerNew];
            jstring aQueryJavaString = (*env)->NewStringUTF(env, [aQueryString UTF8String]);
            jstring defaultFieldName = (*env)->NewStringUTF(env, "body");
            
            jobject query = [self queryParserClassParseQueryString:aQueryJavaString defaultField:defaultFieldName analyzer:standardAnalyzer];
            
            NSLog(@"query = %@", [self objectToString:query]);   
            
            hits = [self indexSearcher:indexSearcher search:query];
            
            NSLog(@"hits = %@", [self objectToString:hits]);   
        }
        @catch (NSException *localException)
        {
            @throw localException;
        }
        @finally
        {
            (*env)->PopLocalFrame(env, NULL);
        }        
    }
    
    return hits;
}

+ (int)hitsLength:(jobject)hits
{
    if ((*env)->PushLocalFrame(env, 50) < 0) {NSLog(@"Out of memory!"); exit(1);}
    
    jmethodID mid = NULL;
    
    if (! mid)
    {
        mid = (*env)->GetMethodID(env, (*env)->GetObjectClass(env, hits), "length", "()I");
        NSAssert(mid != NULL, @"length not found");
    }
    
    jint result = (*env)->CallIntMethod(env, hits, mid);
    
    (*env)->PopLocalFrame(env, NULL);
    
    return (int)result;
}

@end

#include <sys/stat.h>
#include <sys/resource.h>
#include <pthread.h>
#include <CoreFoundation/CoreFoundation.h>
#include "utils.h"

@implementation GIFulltextIndexCenter (JVMStuff)

/*Starts a JVM using the options,classpath,main class, and args stored in a VMLauchOptions structure */ 
static JNIEnv *startupJava(VMLaunchOptions *launchOptions) {    
    int result = 0;
    JNIEnv *env;
    JavaVM *theVM;
    
//    VMLaunchOptions *launchOptions = (VMLaunchOptions*)options;
    
    /* default vm args */
    JavaVMInitArgs	vm_args;
    
    /*
     To invoke Java 1.4.1 or the currently preferred JDK as defined by the operating system (1.4.2 as of the release of this sample and the release of Mac OS X 10.4) nothing changes in 10.4 vs 10.3 in that when a JNI_VERSION_1_4 is passed into JNI_CreateJavaVM as the vm_args.version it returns the current preferred JDK.
     
     To specify the current preferred JDK in a family of JVM's, say the 1.5.x family, applications should set the environment variable JAVA_JVM_VERSION to 1.5, and then pass JNI_VERSION_1_4 into JNI_CreateJavaVM as the vm_args.version. To get a specific Java 1.5 JVM, say Java 1.5.0, set the environment variable JAVA_JVM_VERSION to 1.5.0. For Java 1.6 it will be the same in that applications will need to set the environment variable JAVA_JVM_VERSION to 1.6 to specify the current preferred 1.6 Java VM, and to get a specific Java 1.6 JVM, say Java 1.6.1, set the environment variable JAVA_JVM_VERSION to 1.6.1.
     
     To make this sample bring up the current preferred 1.5 JVM, set the environment variable JAVA_JVM_VERSION to 1.5 before calling JNI_CreateJavaVM as shown below.  Applications must currently check for availability of JDK 1.5 before requesting it.  If your application requires JDK 1.5 and it is not found, it is your responsibility to report an error to the user. To verify if a JVM is installed, check to see if the symlink, or directory exists for the JVM in /System/Library/Frameworks/JavaVM.framework/Versions/ before setting the environment variable JAVA_JVM_VERSION.
     
     If the environment variable JAVA_JVM_VERSION is not set, and JNI_VERSION_1_4 is passed into JNI_CreateJavaVM as the vm_args.version, JNI_CreateJavaVM will return the current preferred JDK. Java 1.4.2 is the preferred JDK as of the release of this sample and the release of Mac OS X 10.4.
     */
	{
		CFStringRef targetJVM = CFSTR("1.5");
		CFBundleRef JavaVMBundle;
		CFURLRef    JavaVMBundleURL;
		CFURLRef    JavaVMBundlerVersionsDirURL;
		CFURLRef    TargetJavaVM;
		UInt8 pathToTargetJVM [PATH_MAX] = "\0";
		struct stat sbuf;
		
		
		// Look for the JavaVM bundle using its identifier
		JavaVMBundle = CFBundleGetBundleWithIdentifier(CFSTR("com.apple.JavaVM") );
		
		if(JavaVMBundle != NULL) {
			// Get a path for the JavaVM bundle
			JavaVMBundleURL = CFBundleCopyBundleURL(JavaVMBundle);
			CFRelease(JavaVMBundle);
			
			if(JavaVMBundleURL != NULL) {
				// Append to the path the Versions Component
				JavaVMBundlerVersionsDirURL = CFURLCreateCopyAppendingPathComponent(kCFAllocatorDefault,JavaVMBundleURL,CFSTR("Versions"),true);
				CFRelease(JavaVMBundleURL);
				
				if(JavaVMBundlerVersionsDirURL != NULL) {
					// Append to the path the target JVM's Version
					TargetJavaVM = CFURLCreateCopyAppendingPathComponent(kCFAllocatorDefault,JavaVMBundlerVersionsDirURL,targetJVM,true);
					CFRelease(JavaVMBundlerVersionsDirURL);
					
					if(TargetJavaVM != NULL) {
						if(CFURLGetFileSystemRepresentation (TargetJavaVM,true,pathToTargetJVM,PATH_MAX )) {
							// Check to see if the directory, or a sym link for the target JVM directory exists, and if so set the
							// environment variable JAVA_JVM_VERSION to the target JVM.
							if(stat((char*)pathToTargetJVM,&sbuf) == 0) {
								// Ok, the directory exists, so now we need to set the environment var JAVA_JVM_VERSION to the CFSTR targetJVM
								// We can reuse the pathToTargetJVM buffer to set the environement var.
								if(CFStringGetCString(targetJVM,(char*)pathToTargetJVM,PATH_MAX,kCFStringEncodingUTF8))
									setenv("JAVA_JVM_VERSION", (char*)pathToTargetJVM,1);
							}
						}
                        CFRelease(TargetJavaVM);
					}
				}
			}
		}
	}
	
    /* JNI_VERSION_1_4 is used on Mac OS X to indicate the 1.4.x and later JVM's */
    vm_args.version	= JNI_VERSION_1_4;
    vm_args.options	= launchOptions->options;
    vm_args.nOptions = launchOptions->nOptions;
    vm_args.ignoreUnrecognized	= JNI_TRUE;
    
    /* start a VM session */    
    result = JNI_CreateJavaVM(&theVM, (void**)&env, &vm_args);
    
    if ( result != 0 ) {
        fprintf(stderr, "[JavaAppLauncher Error] Error starting up VM.\n");
        exit(result);
    }
    
    return env;
}

+ (JNIEnv *)getJNIEnvironment
{
    static JNIEnv *env = NULL;
    
    if (! env)
    {
        /* Allocated the structure that will be used to return the launch options */
        VMLaunchOptions *vmLaunchOptions = malloc(sizeof(VMLaunchOptions));
        vmLaunchOptions->nOptions = 1;
        JavaVMOption *option = malloc(vmLaunchOptions->nOptions * sizeof(JavaVMOption));
        vmLaunchOptions->options = option;
        option->extraInfo = NULL;
        
        NSString *opt = [@"-Djava.class.path=" stringByAppendingString:[[NSBundle mainBundle] pathForResource:@"lucene-1.4.3" ofType:@"jar"]];
        
        NSLog(@"option = %@", opt);
        
        CFIndex optionStringSize = CFStringGetMaximumSizeForEncoding(CFStringGetLength((CFStringRef)opt), kCFStringEncodingUTF8);
        option->optionString = malloc(optionStringSize+1);
        /* Now copy the option into the the optionString char* buffer in a UTF8 encoding */
        if(!CFStringGetCString((CFStringRef)opt, (char *)option->optionString, optionStringSize, kCFStringEncodingUTF8)) {
            fprintf(stderr, "[JavaAppLauncher Error] Error parsing JVM options.\n");
            exit(-1);
        }        
        
        env = startupJava(vmLaunchOptions);
    }
    
    return env;
}

@end