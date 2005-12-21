/*
 *  Lucene.h
 *  GinkoVoyager
 *
 *  Created by Axel Katerbau on 18.12.05.
 *  Copyright 2005 __MyCompanyName__. All rights reserved.
 *
 */

@interface NSObject (InstantiatingJavaObjects)

// Instantiating java objects for when no -init/constructor mapping works.
// The class these methods are invoked on *must* be a class returned by the
// -findClass: method (or NSClassFromString() function), otherwise
// NSInvalidJavaClassException is raised. The signature is specified using the
// rather counter-intuitive format defined by the Java Virtual Machine
// specification.  Try looking in JavaVM/vm-interface.h for help.

+ (id) newWithSignature:(NSString *)signature, ...;
+ (id) newWithSignature:(NSString *)signature arguments:(va_list)args;

@end

#define LuceneFieldClassname @"org.apache.lucene.document.Field"
#define LuceneFieldClass (NSClassFromString(LuceneFieldClassname))
@interface LuceneField : NSObject
{
}

+ (LuceneField *)Keyword:(NSString *)aName :(id /* String or Date */)value;
+ (LuceneField *)Text:(NSString *)aName :(id /* String or Reader */)value;

@end

#define LuceneFieldClassname @"org.apache.lucene.document.Field"
#define LuceneFieldClass (NSClassFromString(LuceneFieldClassname))
@interface LuceneDateField : NSObject
{
}

+ (NSString *)timeToString:(unsigned long long)time;

@end

#define LuceneDocumentClassname @"org.apache.lucene.document.Document"
#define LuceneDocumentClass (NSClassFromString(LuceneDocumentClassname))
@interface LuceneDocument : NSObject
{
}

- (void)add:(LuceneField *)aField;

@end

#define LuceneIndexWriterClassname @"org.apache.lucene.index.IndexWriter"
#define LuceneIndexWriterClass (NSClassFromString(LuceneIndexWriterClassname))
@interface LuceneIndexWriter : NSObject
{
}

- (id)getAnalyzer;
- (void)setUseCompoundFile:(BOOL)aBool;

- (void)addDocument:(LuceneDocument *)aDocument;

- (int)docCount;

- (void)optimize;
- (void)close;

@end

#define LuceneIndexSearcherClassname @"org.apache.lucene.search.IndexSearcher"
#define LuceneIndexSearcherClass (NSClassFromString(LuceneIndexSearcherClassname))
@interface LuceneIndexSearcher : NSObject
{
}

- (id)search:(id)aQuery;

@end

#define LuceneQueryParserClassname @"org.apache.lucene.queryParser.QueryParser"
#define LuceneQueryParserClass (NSClassFromString(LuceneQueryParserClassname))
@interface LuceneQueryParser : NSObject
{
}

+ (id)parse:(NSString *)aQueryString :(NSString *)defaultField :(id)anAnalyzer;

@end
