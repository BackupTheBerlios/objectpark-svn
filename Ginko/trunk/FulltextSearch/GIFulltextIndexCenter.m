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
#import <JavaVM/JavaVM.h>
#import <OPDebug/OPLog.h>

@implementation GIFulltextIndexCenter

static NSJavaVirtualMachine *jvm = nil;

+ (void)initialize
{
    NSString *lucenePath = [@":" stringByAppendingString:[[NSBundle mainBundle] pathForResource:@"lucene-1.4.3" ofType:@"jar"]];
    
    jvm = [[NSJavaVirtualMachine alloc] initWithClassPath:[[NSJavaVirtualMachine defaultClassPath] stringByAppendingString:lucenePath]];    
}

+ (NSString *)fulltextIndexPath
{
    static NSString *path = nil;
    
    @synchronized(self)
    {
        if (!path) path = [[GIApp applicationSupportPath] stringByAppendingPathComponent:@"FulltextIndex"];
    }
    return path;
}

- (id)init
{
    return nil;
}

+ (LuceneDocument *)luceneDocumentFromMessage:(id)aMessage
{
    LuceneDocument *result = [[[LuceneDocumentClass alloc] init] autorelease];
    Class fieldClass = LuceneFieldClass;
    
    // message id
    NSString *messageId = [aMessage valueForKey:@"messageId"];
    NSAssert([messageId length] > 0, @"fatal error: message id not present.");
    [result add:[fieldClass Keyword:@"id" :messageId]];
    
    // date
    NSCalendarDate *date = [aMessage valueForKey:@"date"];
    double millis = (double)([date timeIntervalSince1970] * 1000.0);
    @try
    {
        [result add:[fieldClass Keyword:@"date" :[NSClassFromString(@"org.apache.lucene.document.DateField") timeToString:(unsigned long long)millis]]];
    }
    @catch(NSException *localException)
    {
        NSLog(@"Date %@ could not be fulltext indexed", date);
    }
                                                                                                                                    
    // subject
    NSString *subject = [aMessage valueForKey:@"subject"];
    [result add:[fieldClass Keyword:@"subject" :subject]];

    // author
    NSString *author = [aMessage valueForKey:@"senderName"];
    [result add:[fieldClass Keyword:@"author" :author]];

    // body
    NSString *body = [aMessage valueForKey:@"messageBodyAsPlainString"];
    [result add:[fieldClass Text:@"body" :body]];
    
    //NSLog(@"\nindexing body = %@\n", body);
    
    return result;
}

+ (LuceneIndexWriter *)indexWriter
/*" Private method. Should only be used inside a synchronized context. "*/
{
    BOOL shouldCreateNewIndex = YES;
    
    id standardAnalyzer = [[[NSClassFromString(@"org.apache.lucene.analysis.standard.StandardAnalyzer") alloc] init] autorelease];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self fulltextIndexPath]]) shouldCreateNewIndex = NO;
    
    LuceneIndexWriter *indexWriter = [[LuceneIndexWriterClass newWithSignature:@"(Ljava/lang/String;Lorg/apache/lucene/analysis/Analyzer;Z)", [self fulltextIndexPath], standardAnalyzer, [NSNumber numberWithBool:shouldCreateNewIndex]] autorelease];
    
    return indexWriter;
}

+ (BOOL)addMessages:(NSArray *)someMessages
{
    @synchronized(self)
    {
        LuceneIndexWriter *indexWriter = [self indexWriter];
        
        NSAssert(indexWriter != nil, @"IndexWriter could not be created.");
        
        NSEnumerator *enumerator = [someMessages objectEnumerator];
        id message;
        
        while (message = [enumerator nextObject])
        {
            LuceneDocument *doc = [self luceneDocumentFromMessage:message];
                
            @try
            {
                [indexWriter addDocument:doc];
            } 
            @catch (NSException *localException)
            {
                NSLog(@"EXCEPTION reason = %@", localException);
                [indexWriter close];
                return NO;
            }
        }
        [indexWriter close];
    }
    
    return YES;
}

+ (void)optimize
{
    @synchronized(self)
    {
        LuceneIndexWriter *indexWriter = [self indexWriter];
        [indexWriter optimize];
        [indexWriter close];
    }
}

+ (LuceneHits *)hitsForQueryString:(NSString *)aQueryString
{
    LuceneHits *hits = nil;
    
    @synchronized(self)
    {
        LuceneIndexSearcher *indexSearcher = [[LuceneIndexSearcherClass newWithSignature:@"(Ljava/lang/String;)", [GIFulltextIndexCenter fulltextIndexPath]] autorelease];
        
        //NSLog(@"indexSearcher = %@", indexSearcher);   
        
        id standardAnalyzer = [[[NSClassFromString(@"org.apache.lucene.analysis.standard.StandardAnalyzer") alloc] init] autorelease];
        
        id query = [LuceneQueryParserClass parse:aQueryString :@"body" :standardAnalyzer];
        //NSLog(@"query = %@", query);   
        
        hits = [indexSearcher search:query];
    }
    
    return hits;
}

@end
