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
#import "OPObjectPair.h"
#import "NSString+Extensions.h"
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
    jthrowable exc = (*env)->ExceptionOccurred(env);
    if (exc) 
    {
        /* We don't do much with the exception, except that
        we print a debug message for it, clear it. */
        (*env)->ExceptionDescribe(env);
        (*env)->ExceptionClear(env);
    }
    
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
    
    (*env)->CallVoidMethod(env, aDocument, mid, aField);
}

+ (jstring)document:(jobject)aDocument get:(jstring)aFieldName
{
    jmethodID mid = NULL;
    
    if (! mid)
    {
        mid = (*env)->GetMethodID(env, [self documentClass], "get", "(Ljava/lang/String;)Ljava/lang/String;");
    }
    
    jstring result = (*env)->CallObjectMethod(env, aDocument, mid, aFieldName);
    NSAssert(result != NULL, @"get with no result.");
    
    return result;
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
    
    jthrowable exc = (*env)->ExceptionOccurred(env);
    if (exc) 
    {
        /* We don't do much with the exception, except that
        we print a debug message for it, clear it. */
        (*env)->ExceptionDescribe(env);
        (*env)->ExceptionClear(env);
    }
    
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
    jthrowable exc = (*env)->ExceptionOccurred(env);
    if (exc) 
    {
        /* We don't do much with the exception, except that
        we print a debug message for it, clear it. */
        (*env)->ExceptionDescribe(env);
        (*env)->ExceptionClear(env);
    }
    
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
    
    // id
    NSString *oidString = [[NSNumber numberWithUnsignedLongLong:[aMessage oid]] description];
    jstring oidJavaString = (*env)->NewStringUTF(env, [oidString UTF8String]);
    jthrowable exc = (*env)->ExceptionOccurred(env);
    if (exc) 
    {
        /* We don't do much with the exception, except that
        we print a debug message for it, clear it. */
        (*env)->ExceptionDescribe(env);
        (*env)->ExceptionClear(env);
    }
    NSAssert(oidJavaString != NULL, @"textString not converted.");

    [self document:document addKeywordFieldWithName:@"id" text:oidJavaString];
        
    // thread-id
    oidString = [[NSNumber numberWithUnsignedLongLong:[[aMessage thread] oid]] description];
    oidJavaString = (*env)->NewStringUTF(env, [oidString UTF8String]);
    exc = (*env)->ExceptionOccurred(env);
    if (exc) 
    {
        /* We don't do much with the exception, except that
        we print a debug message for it, clear it. */
        (*env)->ExceptionDescribe(env);
        (*env)->ExceptionClear(env);
    }
    NSAssert(oidJavaString != NULL, @"textString not converted.");
    
    [self document:document addKeywordFieldWithName:@"thread" text:oidJavaString];
    
    // date
    NSCalendarDate *date = [aMessage valueForKey:@"date"];
    double millis = (double)([date timeIntervalSince1970] * 1000.0);
    @try
    {
        jstring dateJavaString = [self dateFieldTimeToString:(unsigned long long)millis];
        jthrowable exc = (*env)->ExceptionOccurred(env);
        if (exc) 
        {
            /* We don't do much with the exception, except that
            we print a debug message for it, clear it. */
            (*env)->ExceptionDescribe(env);
            (*env)->ExceptionClear(env);
        }
        [self document:document addKeywordFieldWithName:@"date" text:dateJavaString];
    }
    @catch(NSException *localException)
    {
        NSLog(@"Date %@ could not be fulltext indexed", date);
    }
    
    // subject
    NSString *subject = [aMessage valueForKey:@"subject"];
    if (subject) 
    {
        jstring subjectJavaString = (*env)->NewStringUTF(env, [subject UTF8String]);
        exc = (*env)->ExceptionOccurred(env);
        if (exc) 
        {
            /* We don't do much with the exception, except that
            we print a debug message for it, clear it. */
            (*env)->ExceptionDescribe(env);
            (*env)->ExceptionClear(env);
        }
        
        [self document:document addTextFieldWithName:@"subject" text:subjectJavaString];
    }
    
    // author
    NSString *author = [aMessage valueForKey:@"senderName"];
    if (author)
    {
        jstring authorJavaString = (*env)->NewStringUTF(env, [author UTF8String]);
        exc = (*env)->ExceptionOccurred(env);
        if (exc) 
        {
            /* We don't do much with the exception, except that
            we print a debug message for it, clear it. */
            (*env)->ExceptionDescribe(env);
            (*env)->ExceptionClear(env);
        }
        
        [self document:document addTextFieldWithName:@"author" text:authorJavaString];
    }
    
    // body
    NSString *body = [aMessage valueForKey:@"messageBodyAsPlainString"];
    if (body)
    {
        jstring bodyJavaString = (*env)->NewStringUTF(env, [body UTF8String]);
        exc = (*env)->ExceptionOccurred(env);
        if (exc) 
        {
            /* We don't do much with the exception, except that
            we print a debug message for it, clear it. */
            (*env)->ExceptionDescribe(env);
            (*env)->ExceptionClear(env);
        }
        
        
        [self document:document addTextFieldWithName:@"body" text:bodyJavaString];
    }    
    
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
        
    jobject indexWriter = (*env)->NewObject(env, [self indexWriterClass], cid, javaIndexPath, analyzer, shouldCreateNewIndex);
    
    exc = (*env)->ExceptionOccurred(env);
    if (exc) 
    {
        /* We don't do much with the exception, except that
        we print a debug message for it, clear it. */
        (*env)->ExceptionDescribe(env);
        (*env)->ExceptionClear(env);
    }
    
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

+ (void)addMessages:(NSEnumerator *)messageEnumerator
{
    @synchronized(self)
    {
        NSAutoreleasePool *pool = nil;
        if ((*env)->PushLocalFrame(env, 50) < 0) {NSLog(@"Out of memory!"); exit(1);}
        jobject indexWriter = [self indexWriter];
        NSAssert(indexWriter != NULL, @"IndexWriter could not be created.");
        
        @try
        {
            pool = [[NSAutoreleasePool alloc] init];
            id message;
            int counter = 1;
            while (message = [messageEnumerator nextObject])
            {
                @try
                {
                    if ((*env)->PushLocalFrame(env, 250) < 0) {NSLog(@"Out of memory!");}
                    
                    jobject doc = [self luceneDocumentFromMessage:message];
                    //NSLog(@"\nmade document = %@\n", [self objectToString:doc]);
                    NSLog(@"\nmade document no = %d\n", counter++);
                    [self indexWriter:indexWriter addDocument:doc];
                    if ((counter % 1000) == 0) 
                    {
                        NSLog(@"optimizing index\n");
                        [self indexWriterOptimize:indexWriter];
                    }
                    
                    [message setValue: [NSNumber numberWithBool: YES] forKey:@"isFulltextIndexed"];
                }
                @catch (NSException *localException)
                {
                    @throw localException;
                }
                @finally
                {
                    (*env)->PopLocalFrame(env, NULL);
                    [pool release];
                    pool = [[NSAutoreleasePool alloc] init];
                }
            }
        }
        @catch (NSException *localException)
        {
            @throw localException;
        }
        @finally
        {
            [self indexWriterOptimize:indexWriter];
            [self indexWriterClose:indexWriter];
            [pool release];
            (*env)->PopLocalFrame(env, NULL);
        }
    }
}

+ (jclass)indexReaderClass
{
    jclass indexReaderClass = NULL;
    
    if (! indexReaderClass)
    {
        indexReaderClass = (*env)->FindClass(env, "org/apache/lucene/index/IndexReader");
        NSAssert(indexReaderClass != NULL, @"org.apache.lucene.index.IndexReader couldn't be found.");
    }
    
    return indexReaderClass;
}

+ (jobject)indexReaderOpen:(jstring)path
{
    jmethodID mid = NULL;
    
    if (! mid)
    {
        mid = (*env)->GetStaticMethodID(env, [self indexReaderClass], "open", "(Ljava/lang/String;)Lorg/apache/lucene/index/IndexReader;");
        NSAssert(mid != NULL, @"open static method couldn't be found.");
    }
        
    jobject result = (*env)->CallStaticObjectMethod(env, [self indexReaderClass], mid, path);
    NSAssert(result != NULL, @"open static method doesn't generate a IndexReader object.");
        
    return result;
}

+ (void)indexReaderClose:(jobject)reader
{
    jmethodID mid = (*env)->GetMethodID(env, [self indexReaderClass], "close", "()V");
    NSAssert(mid != NULL, @"close method couldn't be found.");
    
    (*env)->CallVoidMethod(env, reader, mid);
}

+ (jclass)termClass
{
    jclass termClass = NULL;
    
    if (! termClass)
    {
        termClass = (*env)->FindClass(env, "org/apache/lucene/index/Term");
        NSAssert(termClass != NULL, @"org.apache.lucene.index.Term couldn't be found.");
    }
    
    return termClass;
}

+ (jint)indexReader:(jobject)reader delete:(jobject)term
{
    jmethodID mid = (*env)->GetMethodID(env, [self indexReaderClass], "delete", "(Lorg/apache/lucene/index/Term;)I");
    NSAssert(mid != NULL, @"delete method couldn't be found.");
    
    jint result = 0;
    result = (*env)->CallIntMethod(env, reader, mid, term);

    jthrowable exc = (*env)->ExceptionOccurred(env);
    if (exc) 
    {
        /* We don't do much with the exception, except that
        we print a debug message for it, clear it. */
        (*env)->ExceptionDescribe(env);
        (*env)->ExceptionClear(env);
    }
    return result;
}

+ (jobject)termNewWithFieldname:(jstring)fieldName text:(jstring)text
{
    jmethodID cid = NULL;
    
    if (! cid)
    {
        cid = (*env)->GetMethodID(env, [self termClass], "<init>", "(Ljava/lang/String;Ljava/lang/String;)V");
        NSAssert(cid != NULL, @"Term constructor couldn't be found.");
    }
    
    jobject term = (*env)->NewObject(env, [self termClass], cid, fieldName, text);
    NSAssert(term != NULL, @"Term couldn't be instantiated.");
    
    return term;
}

+ (void)removeMessagesWithOids:(NSArray *)someOids
{
    if ([someOids count])
    {;
        @synchronized(self)
        {
            if ((*env)->PushLocalFrame(env, 50) < 0) {NSLog(@"Out of memory!"); exit(1);}
            
            jstring javaIndexPath = (*env)->NewStringUTF(env, [[self fulltextIndexPath] UTF8String]);
            jobject indexReader = [self indexReaderOpen:javaIndexPath];             
            NSAssert(indexReader != NULL, @"Could not create Lucene index reader.");
            
             @try
             {
                 NSEnumerator *enumerator = [someOids objectEnumerator];
                 NSString *Oid;
                 
                 while (Oid = [enumerator nextObject])
                 {;
                     @try
                     {
                         if ((*env)->PushLocalFrame(env, 250) < 0) {NSLog(@"Out of memory!");}

                         jstring fieldName = (*env)->NewStringUTF(env, "id");
                         jstring text = (*env)->NewStringUTF(env, [[Oid description] UTF8String]);

                         jobject term = [self termNewWithFieldname:fieldName text:text];
                         
                         jint count = [self indexReader:indexReader delete:term];
                         NSAssert(count <= 1, @"Fatal error: Deleted more than one message for a single message id from fulltext index.");
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
                 [self indexReaderClose:indexReader];
                 (*env)->PopLocalFrame(env, NULL);
             }
        }
        
        [self optimize];
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
        
    jobject result = NULL;
        
    result = (*env)->CallStaticObjectMethod(env, [self queryParserClass], mid, aQueryString, defaultFieldName, anAnalyzer);
    
    jthrowable exc = (*env)->ExceptionOccurred(env);
    if (exc) 
    {
        /* We don't do much with the exception, except that
        we print a debug message for it, clear it. */
        (*env)->ExceptionDescribe(env);
        (*env)->ExceptionClear(env);
    }    
    
    NSAssert(result != NULL, @"parse static method doesn't generate a Query object.");
        
    return result;
}

+ (jobject)luceneHitsForQueryString:(NSString *)aQueryString
/*" Caution: Use only internally in a 'garbage collected' context. "*/
{
    jobject hits = NULL;
    
    jobject indexSearcher = [self indexSearcherNew];
    
    jobject standardAnalyzer = [self standardAnalyzerNew];
    jstring aQueryJavaString = (*env)->NewStringUTF(env, [aQueryString UTF8String]);
    jstring defaultFieldName = (*env)->NewStringUTF(env, "body");
    
    jobject query = [self queryParserClassParseQueryString:aQueryJavaString defaultField:defaultFieldName analyzer:standardAnalyzer];
    
    if (query == NULL) return NULL;
    //NSLog(@"query = %@", [self objectToString:query]);   
    
    hits = [self indexSearcher:indexSearcher search:query];
    
    //NSLog(@"hits = %@", [self objectToString:hits]);   
    
    return hits;
}

+ (jint)hitsLength:(jobject)hits
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
    
    return result;
}

+ (jfloat)hits:(jobject)hits score:(jint)n
{    
    jmethodID mid = NULL;
    
    if (! mid)
    {
        mid = (*env)->GetMethodID(env, (*env)->GetObjectClass(env, hits), "score", "(I)F");
        NSAssert(mid != NULL, @"doc not found");
    }
    
    jfloat result = (*env)->CallFloatMethod(env, hits, mid, n);
    
    return result;
}

+ (jobject)hits:(jobject)hits document:(jint)n
{
    jmethodID mid = NULL;
    
    if (! mid)
    {
        mid = (*env)->GetMethodID(env, (*env)->GetObjectClass(env, hits), "doc", "(I)Lorg/apache/lucene/document/Document;");
        NSAssert(mid != NULL, @"doc not found");
    }
    
    jobject result = (*env)->CallObjectMethod(env, hits, mid, n);
        
    return result;
}

+ (NSArray *)hitsForQueryString:(NSString *)aQuery
{
    NSMutableArray *result = nil;
    
    @synchronized(self)
    {
        if ((*env)->PushLocalFrame(env, 250) < 0) {NSLog(@"Out of memory!"); exit(1);}

        jobject hits = [self luceneHitsForQueryString:aQuery];
        
        if (hits == NULL) return nil;
        
        jint i, hitsCount = [GIFulltextIndexCenter hitsLength:hits];
        
        result = [NSMutableArray arrayWithCapacity:(int)hitsCount];
        
        for (i = 0; i < hitsCount; i++)
        {
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            if ((*env)->PushLocalFrame(env, 250) < 0) {NSLog(@"Out of memory!"); exit(1);}
            
            jobject doc = [self hits:hits document:i];
            //NSLog(@"hit doc = %@", [self objectToString:doc]);
            
            // oid
            jstring fieldName = (*env)->NewStringUTF(env, "id");
            jstring javaOid = [self document:doc get:fieldName];
            NSString *oidString = stringFromJstring(javaOid);
#warning HACK: Do better with converting to unsigned long long (not correct here)
            NSNumber *oid = [NSNumber numberWithUnsignedLongLong:[oidString longLongValue]];
            
            // score
            jfloat javaScore = [self hits:hits score:i];
            NSNumber *score = [NSNumber numberWithDouble:(double)javaScore];
            
            OPObjectPair *hit = [OPObjectPair pairWithObjects:oid :score];
            [result addObject:hit];
            
            (*env)->PopLocalFrame(env, NULL);
            [pool release];
        }
        
        (*env)->PopLocalFrame(env, NULL);
    }

    return result;
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
		CFStringRef targetJVM = CFSTR("1.4");
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