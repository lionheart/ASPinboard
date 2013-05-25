//
//  ASPinboard.m
//  ASPinboard
//
//  Created by Dan Loewenherz on 1/29/13.
//  Copyright (c) 2013 Aurora Software. All rights reserved.
//

#import "ASPinboard.h"
#import "NSString+URLEncoding.h"

@implementation ASPinboard

@synthesize token = _token;
@synthesize requestStartedCallback;
@synthesize requestCompletedCallback;
@synthesize loginFailureCallback;
@synthesize loginSuccessCallback;
@synthesize loginConnection;
@synthesize loginRequestInProgress;
@synthesize username = _username;
@synthesize password = _password;
@synthesize dateFormatter;

+ (ASPinboard *)sharedInstance {
    static ASPinboard *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ASPinboard alloc] init];
    });
    return sharedInstance;
}

+ (NSURL *)endpointURL {
    return [NSURL URLWithString:PinboardEndpoint];
}

- (void)resetAuthentication {
    self.username = nil;
    self.password = nil;
    self.token = nil;
}

- (id)init {
    self = [super init];
    if (self) {
        self.token = nil;
        self.requestCompletedCallback = ^{};
        self.requestStartedCallback = ^{};
        self.dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
        [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
    }
    return self;
}

- (void)requestPath:(NSString *)path parameters:(NSDictionary *)parameters success:(PinboardGenericBlock)success failure:(PinboardErrorBlock)failure {
    self.requestStartedCallback();

    NSMutableArray *queryComponents = [NSMutableArray arrayWithObject:@"format=json"];
    [parameters enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        if (![value isEqualToString:@""]) {
            [queryComponents addObject:[NSString stringWithFormat:@"%@=%@", [key urlEncode], [value urlEncode]]];
        }
    }];

    if (self.token != nil) {
        [queryComponents addObject:[NSString stringWithFormat:@"auth_token=%@", self.token]];
    }

    NSString *queryString = [queryComponents componentsJoinedByString:@"&"];
    NSString *urlString = [NSString stringWithFormat:@"%@%@?%@", PinboardEndpoint, path, queryString];
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                               self.requestCompletedCallback();
                               if (error.code == NSURLErrorUserCancelledAuthentication) {
                                   failure([NSError errorWithDomain:ASPinboardErrorDomain code:PinboardErrorInvalidCredentials userInfo:nil]);
                               }
                               else if (data == nil) {
                                   failure([NSError errorWithDomain:ASPinboardErrorDomain code:PinboardErrorEmptyResponse userInfo:nil]);
                               }
                               else {
                                   id response = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
                                   success(response);
                               }
                           }];
}

- (void)requestPath:(NSString *)path success:(PinboardGenericBlock)success failure:(PinboardErrorBlock)failure {
    [self requestPath:path parameters:nil success:success failure:failure];
}

- (void)requestPath:(NSString *)path success:(PinboardGenericBlock)success {
    [self requestPath:path parameters:nil success:success failure:^(NSError *error){}];
}

- (void)authenticateWithUsername:(NSString *)username password:(NSString *)password timeout:(NSTimeInterval)timeout success:(PinboardStringBlock)success failure:(PinboardErrorBlock)failure{
    self.loginSuccessCallback = success;
    self.loginFailureCallback = failure;
    self.username = username;
    self.password = password;

    NSURL *url = [NSURL URLWithString:@"user/api_token?format=json" relativeToURL:[ASPinboard endpointURL]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    self.loginRequestInProgress = YES;
    self.loginTimer = [NSTimer timerWithTimeInterval:timeout target:self selector:@selector(timerCompleted:) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:self.loginTimer forMode:NSRunLoopCommonModes];
    self.loginConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [self.loginConnection start];
}

- (void)authenticateWithUsername:(NSString *)username password:(NSString *)password success:(PinboardStringBlock)success failure:(PinboardErrorBlock)failure {
    [self authenticateWithUsername:username password:password timeout:20.0 success:success failure:failure];
}

#pragma mark - URL Connection Delegates

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if (connection == self.loginConnection) {
        if ([challenge previousFailureCount] == 0) {
            NSURLCredential *credential = [NSURLCredential credentialWithUser:self.username password:self.password persistence:NSURLCredentialPersistenceNone];
            [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
        }
        else {
            self.loginFailureCallback([NSError errorWithDomain:ASPinboardErrorDomain code:PinboardErrorInvalidCredentials userInfo:nil]);
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if (connection == self.loginConnection) {
        self.loginRequestInProgress = NO;
        NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
        if (payload == nil) {
            self.loginFailureCallback([NSError errorWithDomain:ASPinboardErrorDomain code:PinboardErrorInvalidCredentials userInfo:nil]);
        }
        else {
            self.token = [NSString stringWithFormat:@"%@:%@", self.username, payload[@"result"]];
            self.loginSuccessCallback(self.token);
            self.username = nil;
            self.password = nil;
        }
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    if (connection == self.loginConnection) {
        self.loginRequestInProgress = NO;
        self.loginFailureCallback([NSError errorWithDomain:ASPinboardErrorDomain code:PinboardErrorInvalidCredentials userInfo:nil]);
    }
}

#pragma mark - Timer
                       
- (void)timerCompleted:(NSTimer *)timer {
    if (timer == self.loginTimer) {
        if (self.loginRequestInProgress) {
            self.loginRequestInProgress = NO;
            [self.loginConnection cancel];
            self.loginFailureCallback([NSError errorWithDomain:ASPinboardErrorDomain code:PinboardErrorTimeout userInfo:nil]);
        }
    }
}

#pragma mark - API Methods

#pragma mark Generic Endpoints

- (void)lastUpdateWithSuccess:(PinboardDateBlock)success failure:(PinboardErrorBlock)failure {
    [self requestPath:@"posts/update"
              success:^(id response) {
                  NSDate *date = [self.dateFormatter dateFromString:response[@"update_time"]];
                  if (!date) {
                      date = [NSDate date];
                  }
                  success(date);
              }
              failure:failure];
}

- (void)rssKeyWithSuccess:(PinboardStringBlock)success {
    [self requestPath:@"user/secret" success:^(id response) {
        success(response[@"result"]);
    }];
}

#pragma mark Bookmarks

- (void)bookmarksWithSuccess:(PinboardArrayBlock)success failure:(PinboardErrorBlock)failure {
    [self requestPath:@"posts/all"
           parameters:@{@"meta": @"yes"}
              success:^(id response) {
                  success((NSArray *)response);
              }
              failure:failure];
}

- (void)bookmarksWithTags:(NSString *)tags
                   offset:(NSInteger)offset
                    count:(NSInteger)count
                 fromDate:(NSDate *)fromDate
                   toDate:(NSDate *)toDate
              includeMeta:(BOOL)includeMeta
                  success:(PinboardArrayBlock)success
                  failure:(PinboardErrorBlock)failure {
    NSDictionary *parameters = @{
        @"tag": tags,
        @"start": [NSString stringWithFormat:@"%d", offset],
        @"results": [NSString stringWithFormat:@"%d", count],
        @"fromdt": [self.dateFormatter stringFromDate:fromDate],
        @"todt": [self.dateFormatter stringFromDate:toDate],
        @"meta": includeMeta ? @"yes" : @"no"
    };
    [self requestPath:@"posts/all"
           parameters:parameters
              success:^(id response) {
                  success((NSArray *)response);
              }
              failure:failure];
}

- (void)bookmarksByDateWithTags:(NSString *)tags success:(PinboardDictionaryBlock)success {
    [self requestPath:@"posts/dates"
           parameters:@{@"tag": tags}
              success:^(id response) {
                  success(response[@"dates"]);
              }
              failure:^(NSError *error) {}];
}

- (void)addBookmark:(NSDictionary *)bookmark success:(PinboardEmptyBlock)success failure:(PinboardErrorBlock)failure {
    [self requestPath:@"posts/add"
           parameters:bookmark
              success:^(id response) {
                  success();
              }
              failure:failure];
}

- (void)addBookmarkWithURL:(NSString *)url
                     title:(NSString *)title
               description:(NSString *)description
                      tags:(NSString *)tags
                    shared:(BOOL)shared
                    unread:(BOOL)unread
                   success:(PinboardEmptyBlock)success
                   failure:(PinboardErrorBlock)failure {
    NSDictionary *bookmark = @{
        @"url": url,
        @"description": title,
        @"extended": description,
        @"tags": tags,
        @"toread": unread ? @"yes" : @"no",
        @"shared": shared ? @"yes" : @"no"
    };
    [self addBookmark:bookmark success:success failure:failure];
}

- (void)bookmarkWithURL:(NSString *)url success:(PinboardDictionaryBlock)success failure:(PinboardErrorBlock)failure {
    [self requestPath:@"posts/get"
           parameters:@{@"url": url}
              success:^(id response) {
                  if ([response[@"posts"] count] == 0) {
                      failure([NSError errorWithDomain:ASPinboardErrorDomain code:PinboardErrorBookmarkNotFound userInfo:nil]);
                  }
                  else {
                      success(response[@"posts"][0]);
                  }
              }
              failure:failure];
}

- (void)deleteBookmarkWithURL:(NSString *)url success:(PinboardEmptyBlock)success failure:(PinboardErrorBlock)failure {
    [self requestPath:@"posts/delete"
           parameters:@{@"url": url}
              success:^(id response) {
                  success();
              }
              failure:failure];
}

#pragma mark Notes

- (void)notesWithSuccess:(PinboardArrayBlock)success {
    [self requestPath:@"notes/list" success:^(id response) {
        success(response[@"notes"]);
    }];
}

- (void)noteWithId:(NSString *)noteId success:(PinboardTwoStringBlock)success {
    NSString *path = [NSString stringWithFormat:@"notes/%@", noteId];
    [self requestPath:path success:^(id response) {
        success(response[@"title"], response[@"text"]);
    }];
}

#pragma mark Tags

- (void)tagsWithSuccess:(PinboardDictionaryBlock)success {
    [self requestPath:@"tags/get"
              success:^(id response) {
                  success((NSDictionary *)response);
              }];
}

- (void)deleteTag:(NSString *)tag success:(PinboardEmptyBlock)success {
    [self requestPath:@"tags/delete"
           parameters:@{@"tag": tag}
              success:^(id response) {
                  success();
              }
              failure:^(NSError *error) {}];
}

- (void)renameTagFrom:(NSString *)oldTag to:(NSString *)newTag success:(PinboardEmptyBlock)success {
    [self requestPath:@"tags/rename"
           parameters:@{@"old": oldTag, @"new": newTag}
              success:^(id response) {
                  success();
              }
              failure:^(NSError *error) {}];
}

- (void)tagSuggestionsForURL:(NSString *)url success:(PinboardTwoArrayBlock)success {
    [self requestPath:@"posts/suggest"
           parameters:@{@"url": url}
              success:^(id response) {
                  success(response[0][@"popular"], response[1][@"recommended"]);
              }
              failure:^(NSError *error){}];
}

@end
