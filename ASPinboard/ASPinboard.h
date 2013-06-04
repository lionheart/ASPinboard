//
//  ASPinboard.h
//  ASPinboard
//
//  Created by Dan Loewenherz on 1/29/13.
//  Copyright (c) 2013 Aurora Software. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSString *PinboardEndpoint __unused = @"https://api.pinboard.in/v1/";
static NSString *ASPinboardErrorDomain __unused = @"ASPinboardErrorDomain";

typedef void(^PinboardGenericBlock)(id);
typedef void(^PinboardEmptyBlock)();
typedef void(^PinboardStringBlock)(NSString *);
typedef void(^PinboardTwoStringBlock)(NSString *, NSString *);
typedef void(^PinboardDateBlock)(NSDate *);
typedef void(^PinboardArrayBlock)(NSArray *);
typedef void(^PinboardTwoArrayBlock)(NSArray *, NSArray *);
typedef void(^PinboardDictionaryBlock)(NSDictionary *);
typedef void(^PinboardErrorBlock)(NSError *);

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
- (void)rssKeyWithSuccess:(PinboardStringBlock)success;

#pragma mark Bookmarks

- (void)bookmarksWithSuccess:(PinboardArrayBlock)success
                     failure:(PinboardErrorBlock)failure;

- (void)bookmarksWithTags:(NSString *)tags
                   offset:(NSInteger)offset
                    count:(NSInteger)count
                 fromDate:(NSDate *)fromDate
                   toDate:(NSDate *)toDate
              includeMeta:(BOOL)includeMeta
                  success:(PinboardArrayBlock)success
                  failure:(PinboardErrorBlock)failure;

- (void)bookmarksByDateWithTags:(NSString *)tags success:(PinboardDictionaryBlock)success;

- (void)addBookmark:(NSDictionary *)bookmark
            success:(void (^)())success
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
