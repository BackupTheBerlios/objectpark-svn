/*
 *  Lucene.h
 *  GinkoVoyager
 *
 *  Created by Axel Katerbau on 18.12.05.
 *  Copyright 2005 __MyCompanyName__. All rights reserved.
 *
 */

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

#define LuceneHitsClassname @"org.apache.lucene.search.Hits"
#define LuceneHitsClass (NSClassFromString(LuceneHitsClassname))
@interface LuceneHits : NSObject
{
}

- (LuceneDocument *)doc:(int)n;
- (int)length;
- (float)score:(int)n;

@end

#define LuceneTermClassname @"org.apache.lucene.index.Term"
#define LuceneTermClass (NSClassFromString(LuceneTermClassname))
@interface LuceneTerm : NSObject
{
}

@end

#define LuceneIndexReaderClassname @"org.apache.lucene.index.IndexReader"
#define LuceneIndexReaderClass (NSClassFromString(LuceneIndexReaderClassname))
@interface LuceneIndexReader : NSObject
{
}

+ (LuceneIndexReader *)open:(id)aDirectory;

- (void)close;
- (int)delete:(LuceneTerm *)aTerm;

@end

#define LuceneFSDirectoryClassname @"org.apache.lucene.store.FSDirectory"
#define LuceneFSDirectoryClass (NSClassFromString(LuceneFSDirectoryClassname))
@interface LuceneFSDirectory : NSObject
{
}

+ (LuceneFSDirectory *)getDirectory:(NSString *)path :(NSNumber *)create;

- (void)close;

@end
