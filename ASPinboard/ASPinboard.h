//
//  Copyright 2012-2013 Aurora Software LLC
//  Copyright 2013-2017 Lionheart Software LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

@import Foundation;

static NSString *PinboardEndpoint __unused = @"https://api.pinboard.in/v1/";
static NSString *ASPinboardErrorDomain __unused = @"ASPinboardErrorDomain";
static NSString *ASPinboardHTTPURLResponseKey = @"ASPinboardHTTPURLResponseKey";

typedef void(^PinboardGenericBlock)(id);
typedef void(^PinboardEmptyBlock)(void);
typedef void(^PinboardStringBlock)(NSString *);
typedef void(^PinboardTwoStringBlock)(NSString *, NSString *);
typedef void(^PinboardDateBlock)(NSDate *);
typedef void(^PinboardArrayBlock)(NSArray *);
typedef void(^PinboardSuccessBlock)(NSArray *, NSDictionary *);
typedef void(^PinboardTwoArrayBlock)(NSArray *, NSArray *);
typedef void(^PinboardDictionaryBlock)(NSDictionary *);
typedef void(^PinboardErrorBlock)(NSError *);
typedef void(^PinboardSearchResultBlock)(NSArray *urls, NSError *error);

typedef enum : NSInteger {
    ASPinboardSearchScopeAll,
    ASPinboardSearchScopeNetwork,
    ASPinboardSearchScopeMine,
    ASPinboardSearchScopeFullText,
    ASPinboardSearchScopeNone
} ASPinboardSearchScopeType;

typedef enum : NSInteger {
    PinboardErrorBookmarkNotFound,
    PinboardErrorTimeout,
    PinboardErrorInvalidCredentials,
    PinboardErrorEmptyResponse
} ASPinboardErrorType;

@interface ASPinboard : NSObject <NSURLConnectionDataDelegate, NSURLConnectionDelegate>

@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *password;
@property (nonatomic, retain) NSString *token;
@property (nonatomic, retain) NSURLConnection *loginConnection;
@property (nonatomic, retain) NSDateFormatter *dateFormatter;
@property (nonatomic, retain) NSTimer *loginTimer;
@property (nonatomic) BOOL loginRequestInProgress;

@property (nonatomic, copy) void (^requestStartedCallback)(void);
@property (nonatomic, copy) void (^requestCompletedCallback)(void);
@property (nonatomic, copy) void (^loginSuccessCallback)(NSString *);
@property (nonatomic, copy) void (^loginFailureCallback)(NSError *);

+ (ASPinboard *)sharedInstance;
+ (NSURL *)endpointURL;
- (void)resetAuthentication;
- (void)timerCompleted:(NSTimer *)timer;
- (void)requestPath:(NSString *)path
         parameters:(NSDictionary *)parameters
            success:(PinboardGenericBlock)success
            failure:(PinboardErrorBlock)failure;

- (void)requestPath:(NSString *)path success:(PinboardGenericBlock)success failure:(PinboardErrorBlock)failure;
- (void)requestPath:(NSString *)path success:(PinboardGenericBlock)success;

- (void)authenticateWithUsername:(NSString *)username
                        password:(NSString *)password
                         timeout:(NSTimeInterval)timeout
                         success:(PinboardStringBlock)success
                         failure:(PinboardErrorBlock)failure;

- (void)authenticateWithUsername:(NSString *)username
                        password:(NSString *)password
                         success:(PinboardStringBlock)success
                         failure:(PinboardErrorBlock)failure;

#pragma mark - API Methods
#pragma mark Generic Endpoints

- (void)lastUpdateWithSuccess:(PinboardDateBlock)success failure:(PinboardErrorBlock)failure;
- (void)rssKeyWithSuccess:(PinboardStringBlock)success failure:(PinboardErrorBlock)failure;

#pragma mark Bookmarks

- (void)bookmarksWithSuccess:(PinboardSuccessBlock)success
                     failure:(PinboardErrorBlock)failure;

- (void)bookmarksWithTags:(NSString *)tags
                   offset:(NSInteger)offset
                    count:(NSInteger)count
                 fromDate:(NSDate *)fromDate
                   toDate:(NSDate *)toDate
              includeMeta:(BOOL)includeMeta
                  success:(PinboardSuccessBlock)success
                  failure:(PinboardErrorBlock)failure;

- (void)searchBookmarksWithCookies:(NSArray *)cookies
                             query:(NSString *)query
                             scope:(ASPinboardSearchScopeType)scope
                        completion:(PinboardSearchResultBlock)completion;

- (void)searchBookmarksWithUsername:(NSString *)username
                           password:(NSString *)password
                              query:(NSString *)query
                              scope:(ASPinboardSearchScopeType)scope
                         completion:(PinboardSearchResultBlock)completion;

- (void)bookmarksByDateWithTags:(NSString *)tags success:(PinboardDictionaryBlock)success;

- (void)addBookmark:(NSDictionary *)bookmark
            success:(void (^)(void))success
            failure:(void (^)(NSError *))failure;

- (void)addBookmarkWithURL:(NSString *)url
                     title:(NSString *)title
               description:(NSString *)description
                      tags:(NSString *)tags
                    shared:(BOOL)shared
                    unread:(BOOL)unread
                   success:(PinboardEmptyBlock)success
                   failure:(PinboardErrorBlock)failure;

- (void)bookmarkWithURL:(NSString *)url success:(PinboardDictionaryBlock)success failure:(PinboardErrorBlock)failure;
- (void)deleteBookmarkWithURL:(NSString *)url success:(PinboardEmptyBlock)success failure:(PinboardErrorBlock)failure;

#pragma mark Notes

- (void)notesWithSuccess:(PinboardArrayBlock)success;
- (void)noteWithId:(NSString *)noteId success:(PinboardTwoStringBlock)success;

#pragma mark Tags

- (void)tagsWithSuccess:(PinboardDictionaryBlock)success;
- (void)deleteTag:(NSString *)tag success:(PinboardEmptyBlock)success;
- (void)renameTagFrom:(NSString *)oldTag to:(NSString *)newTag success:(PinboardEmptyBlock)success;
- (void)tagSuggestionsForURL:(NSString *)url success:(PinboardTwoArrayBlock)success;

@end
