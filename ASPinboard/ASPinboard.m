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

@import hpple;

#import "ASPinboard.h"
#import "NSString+URLEncoding.h"

@interface ASPinboard ()

@property (nonatomic, copy) PinboardSearchResultBlock SearchCompleted;

@property (nonatomic, strong) NSString *searchQuery;
@property (nonatomic, strong) NSURLConnection *redirectingConnection;
@property (nonatomic, strong) NSMutableArray *authCookies;
@property (nonatomic) ASPinboardSearchScopeType searchScope;

@end

@implementation ASPinboard

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
        
        NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];

        self.dateFormatter = [[NSDateFormatter alloc] init];
        [self.dateFormatter setLocale:enUSPOSIXLocale];
        [self.dateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
        [self.dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
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
    
    if (!failure) {
        failure = ^(NSError *error) {};
    }

    if (self.token != nil) {
#warning XXX
        [queryComponents addObject:[NSString stringWithFormat:@"auth_token=%@", self.token]];
    }

    NSString *queryString = [queryComponents componentsJoinedByString:@"&"];
    NSString *urlString = [NSString stringWithFormat:@"%@%@?%@", PinboardEndpoint, path, queryString];
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];

    dispatch_async(dispatch_get_main_queue(), ^{
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                                                    
                                                    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
                                                    [userInfo addEntriesFromDictionary:error.userInfo];
                                                    
                                                    if (httpResponse) {
                                                        userInfo[ASPinboardHTTPURLResponseKey] = httpResponse;
                                                    }

                                                    self.requestCompletedCallback();
                                                    if (httpResponse.statusCode == 401 || httpResponse.statusCode == 429) {
                                                        failure([NSError errorWithDomain:ASPinboardErrorDomain code:PinboardErrorInvalidCredentials userInfo:userInfo]);
                                                    }
                                                    else if (error.code == NSURLErrorUserCancelledAuthentication) {
                                                        failure([NSError errorWithDomain:ASPinboardErrorDomain code:PinboardErrorInvalidCredentials userInfo:userInfo]);
                                                    }
                                                    else if (data == nil) {
                                                        failure([NSError errorWithDomain:ASPinboardErrorDomain code:PinboardErrorEmptyResponse userInfo:userInfo]);
                                                    }
                                                    else {
                                                        id response = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
                                                        success(response);
                                                    }
                                                }];
        [task resume];
    });
}

- (void)requestPath:(NSString *)path success:(PinboardGenericBlock)success failure:(PinboardErrorBlock)failure {
    [self requestPath:path parameters:nil success:success failure:failure];
}

- (void)requestPath:(NSString *)path success:(PinboardGenericBlock)success {
    [self requestPath:path parameters:nil success:success failure:^(NSError *error){
    
    }];
}

- (void)authenticateWithUsername:(NSString *)username password:(NSString *)password timeout:(NSTimeInterval)timeout success:(PinboardStringBlock)success failure:(PinboardErrorBlock)failure{
    self.loginSuccessCallback = success;
    self.loginFailureCallback = failure;
    self.username = username;
    self.password = password;

    NSURL *url = [NSURL URLWithString:@"user/api_token?format=json" relativeToURL:[ASPinboard endpointURL]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    self.loginRequestInProgress = YES;
    self.loginTimer = [NSTimer timerWithTimeInterval:timeout target:self selector:@selector(timerCompleted:) userInfo:nil repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:self.loginTimer forMode:NSRunLoopCommonModes];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.loginConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
        [self.loginConnection start];
    });
}

- (void)authenticateWithUsername:(NSString *)username password:(NSString *)password success:(PinboardStringBlock)success failure:(PinboardErrorBlock)failure {
    [self authenticateWithUsername:username password:password timeout:20.0 success:success failure:failure];
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if (connection == self.loginConnection) {
        self.loginRequestInProgress = NO;
        [self.loginTimer invalidate];
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

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
    if (connection == self.redirectingConnection) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode == 302) {
            NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:[httpResponse allHeaderFields] forURL:request.URL];

            self.authCookies = [NSMutableArray array];
            for (NSHTTPCookie *cookie in cookies) {
                if ([cookie.name isEqualToString:@"secauth"]) {
                    [self.authCookies addObject:cookie];
                }
                else if ([cookie.name isEqualToString:@"auth"]) {
                    [self.authCookies addObject:cookie];
                }
                else if ([cookie.name isEqualToString:@"login"]) {
                    [self.authCookies addObject:cookie];
                }
            }

            [self searchBookmarksWithCookies:self.authCookies
                                       query:self.searchQuery
                                       scope:self.searchScope
                                  completion:self.SearchCompleted];
        }
    }
    return request;
}

#pragma mark - NSURLConnectionDelegate

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

- (void)rssKeyWithSuccess:(PinboardStringBlock)success failure:(PinboardErrorBlock)failure {
    [self requestPath:@"user/secret" success:^(id response) {
        success(response[@"result"]);
    } failure:failure];
}

#pragma mark Bookmarks

- (void)searchBookmarksWithCookies:(NSArray *)cookies
                             query:(NSString *)query
                             scope:(ASPinboardSearchScopeType)scope
                        completion:(PinboardSearchResultBlock)completion {
    NSString *username;
    for (NSHTTPCookie *cookie in cookies) {
        if ([cookie.name isEqualToString:@"login"]) {
            username = cookie.value;
        }
    }

    NSString *encodedQuery = [query urlEncode];
    NSURL *url;

    switch (scope) {
        case ASPinboardSearchScopeFullText:
            url = [NSURL URLWithString:[NSString stringWithFormat:@"https://pinboard.in/search/u:%@?fulltext=on&query=%@", username, encodedQuery]];
            break;

        case ASPinboardSearchScopeMine:
            url = [NSURL URLWithString:[NSString stringWithFormat:@"https://pinboard.in/search/u:%@?query=%@", username, encodedQuery]];
            break;

        case ASPinboardSearchScopeNetwork:
            url = [NSURL URLWithString:[NSString stringWithFormat:@"https://pinboard.in/search/u:%@/network/?query=%@", username, encodedQuery]];
            break;

        case ASPinboardSearchScopeAll:
            url = [NSURL URLWithString:[NSString stringWithFormat:@"https://pinboard.in/search/?query=%@&all=Search+All", encodedQuery]];
            break;

        case ASPinboardSearchScopeNone:
            break;
    }

    NSLog(@"%@", url);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setAllHTTPHeaderFields:[NSHTTPCookie requestHeaderFieldsWithCookies:cookies]];
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                               TFHpple *doc = [[TFHpple alloc] initWithHTMLData:data];
                               NSArray *results = [doc searchWithXPathQuery:@"//a[contains(@class, 'bookmark_title')]"];

                               NSMutableArray *urls = [NSMutableArray array];
                               for (TFHppleElement *element in results) {
                                   [urls addObject:element.attributes[@"href"]];
                               }
 
                               if (completion) {
                                   completion(urls, nil);
                               }
                           }];
}

- (void)searchBookmarksWithUsername:(NSString *)username
                           password:(NSString *)password
                              query:(NSString *)query
                              scope:(ASPinboardSearchScopeType)scope
                         completion:(PinboardSearchResultBlock)completion {
    if (self.redirectingConnection) {
        [self.redirectingConnection cancel];
        self.redirectingConnection = nil;
    }

    if ([username length] == 0 || [password length] == 0) {
        completion(nil, [NSError errorWithDomain:ASPinboardErrorDomain code:PinboardErrorInvalidCredentials userInfo:nil]);
    }
    else {
        self.searchScope = scope;
        self.searchQuery = query;
        self.SearchCompleted = completion;
        
        // Check if auth cookies exist and that they are not expired
        BOOL validAuthCookiesExist = NO;
        if (self.authCookies) {
            // Ensure that no cookies expire before the current date.
            validAuthCookiesExist = [self.authCookies indexesOfObjectsPassingTest:^(NSHTTPCookie *cookie, NSUInteger idx, BOOL *stop) {
                return (BOOL)([cookie.expiresDate compare:[NSDate date]] == NSOrderedAscending);
            }].count == 0;
        }

        if (validAuthCookiesExist) {
            [self searchBookmarksWithCookies:self.authCookies
                                       query:self.searchQuery
                                       scope:scope
                                  completion:self.SearchCompleted];
        }
        else {
            NSDictionary *parameters = @{@"password": password,
                                         @"username": username};
            NSURL *url = [NSURL URLWithString:@"https://pinboard.in/auth/"];
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
            [request setTimeoutInterval:5];

            NSMutableArray *queryComponents = [NSMutableArray array];
            [parameters enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
                if (![value isEqualToString:@""]) {
                    [queryComponents addObject:[NSString stringWithFormat:@"%@=%@", [key urlEncode], [value urlEncode]]];
                }
            }];

            request.HTTPBody = [[queryComponents componentsJoinedByString:@"&"] dataUsingEncoding:NSUTF8StringEncoding];
            request.HTTPMethod = @"POST";
            
            dispatch_async(dispatch_get_main_queue(), ^{
                self.redirectingConnection = [NSURLConnection connectionWithRequest:request delegate:self];
                [self.redirectingConnection start];
            });
        }
    }
}

- (void)bookmarksWithSuccess:(PinboardSuccessBlock)success failure:(PinboardErrorBlock)failure {
    [self bookmarksWithTags:nil
                     offset:-1
                      count:-1
                   fromDate:nil
                     toDate:nil
                includeMeta:YES
                    success:success
                    failure:failure];
}

- (void)bookmarksWithTags:(NSString *)tags
                   offset:(NSInteger)offset
                    count:(NSInteger)count
                 fromDate:(NSDate *)fromDate
                   toDate:(NSDate *)toDate
              includeMeta:(BOOL)includeMeta
                  success:(PinboardSuccessBlock)success
                  failure:(PinboardErrorBlock)failure {
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    if (tags) {
        parameters[@"tags"] = tags;
    }
    
    if (offset != -1) {
        parameters[@"start"] = [NSString stringWithFormat:@"%ld", (long)offset];
    }

    if (count != -1) {
        parameters[@"results"] = [NSString stringWithFormat:@"%ld", (long)count];
    }
    
    if (fromDate) {
        parameters[@"fromdt"] = [self.dateFormatter stringFromDate:fromDate];
    }
    
    if (toDate) {
        parameters[@"todt"] = [self.dateFormatter stringFromDate:toDate];
    }
    
    parameters[@"meta"] = includeMeta ? @"yes" : @"no";

    [self requestPath:@"posts/all"
           parameters:parameters
              success:^(id response) {
                  success((NSArray *)response, [parameters copy]);
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
