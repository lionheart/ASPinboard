//
//  ASPinboard.h
//  ASPinboard
//
//  Created by Dan Loewenherz on 1/29/13.
//  Copyright (c) 2013 Aurora Software. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSString *PinboardEndpoint = @"https://api.pinboard.in/v1/";
static NSString *ASPinboardErrorDomain = @"ASPinboardErrorDomain";

enum PINBOARD_ERROR_CODES {
    PinboardErrorBookmarkNotFound,
    PinboardErrorTimeout,
    PinboardErrorInvalidCredentials,
    PinboardErrorEmptyResponse
};

@interface ASPinboard : NSObject <NSURLConnectionDataDelegate, NSURLConnectionDelegate>

@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *password;
@property (nonatomic, retain) NSString *token;
@property (nonatomic, retain) NSURLConnection *loginConnection;
@property (nonatomic, retain) NSDateFormatter *dateFormatter;
@property (nonatomic, retain) NSTimer *loginTimer;
@property (nonatomic) BOOL loginRequestInProgress;

@property (nonatomic, copy) void (^requestStartedCallback)();
@property (nonatomic, copy) void (^requestCompletedCallback)();
@property (nonatomic, copy) void (^loginSuccessCallback)(NSString *);
@property (nonatomic, copy) void (^loginFailureCallback)();
@property (nonatomic, copy) void (^loginTimeoutCallback)();

+ (NSString *)urlEncode;
+ (ASPinboard *)sharedInstance;
+ (NSURL *)endpointURL;
- (void)resetAuthentication;
- (void)timerCompleted:(NSTimer *)timer;
- (void)requestPath:(NSString *)path
         parameters:(NSDictionary *)parameters
            success:(void (^)(id))success
            failure:(void (^)(NSError *))failure;

- (void)requestPath:(NSString *)path success:(void (^)(id))success failure:(void (^)(NSError *))failure;
- (void)requestPath:(NSString *)path success:(void (^)(id))success;

- (void)authenticateWithUsername:(NSString *)username
                        password:(NSString *)password
                         timeout:(NSTimeInterval)timeout
                         success:(void (^)(NSString *token))success
                         failure:(void (^)(NSError *))failure;

- (void)authenticateWithUsername:(NSString *)username
                        password:(NSString *)password
                         success:(void (^)(NSString *token))success
                         failure:(void (^)(NSError *))failure;

#pragma mark - API Methods
#pragma mark Generic Endpoints

- (void)lastUpdateWithSuccess:(void (^)(NSDate *))success failure:(void (^)(NSError *))failure;
- (void)rssKeyWithSuccess:(void (^)(NSString *))success;

#pragma mark Bookmarks

- (void)bookmarksWithSuccess:(void (^)(NSArray *bookmarks))success
                     failure:(void (^)(NSError *))failure;

- (void)bookmarksWithTags:(NSString *)tags
                   offset:(NSInteger)offset
                    count:(NSInteger)count
                 fromDate:(NSDate *)fromDate
                   toDate:(NSDate *)toDate
              includeMeta:(BOOL)includeMeta
                  success:(void (NSArray *bookmarks))success
                  failure:(void (^)(NSError *))failure;

- (void)bookmarksByDateWithTags:(NSString *)tags success:(void (^)(NSDictionary *))success;

- (void)addBookmark:(NSDictionary *)bookmark
            success:(void (^)())success
            failure:(void (^)(NSError *))failure;

- (void)addBookmarkWithURL:(NSString *)url
                     title:(NSString *)title
               description:(NSString *)description
                      tags:(NSString *)tags
                    shared:(BOOL)shared
                    unread:(BOOL)unread
                   success:(void (^)())success
                   failure:(void (^)(NSError *))failure;

- (void)bookmarkWithURL:(NSString *)url success:(void (^)(NSDictionary *))success failure:(void (^)(NSError *))failure;
- (void)deleteBookmarkWithURL:(NSString *)url success:(void (^)())success failure:(void (^)(NSError *))failure;

#pragma mark Notes

- (void)notesWithSuccess:(void (^)(NSArray *))success;
- (void)noteWithId:(NSString *)noteId success:(void (^)(NSString *, NSString *))success;

#pragma mark Tags

- (void)tagsWithSuccess:(void (^)(NSDictionary *))success;
- (void)deleteTag:(NSString *)tag success:(void (^)())success;
- (void)renameTagFrom:(NSString *)oldTag to:(NSString *)newTag success:(void (^)())success;
- (void)tagSuggestionsForURL:(NSString *)url success:(void (^)(NSArray *, NSArray *))success;

@end
