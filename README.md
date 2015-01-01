# ASPinboard

ASPinboard is the Objective-C library for [Pinboard](https://pinboard.in) that powers [Pushpin](http://getpushpin.com/). It uses modern Objective-C features (such as ARC and blocks), supports iOS 5.1+, and is dead-simple to integrate. As of January 2013, ASPinboard has full support for every endpoint in the [Pinboard API](https://pinboard.in/api), except [posts/recent](https://pinboard.in/api#posts_recent).

## Getting Started

The first thing you'll want to do is add the files in the ASPinboard directory to your application. Alternatively, you can drag and drop the Xcode project into your existing app, and create a workspace. It's really up to you.

### Quickstart

ASPinboard uses the Pinboard's authentication token to access protected resources. You can retrieve a token with the `authenticateWithUsername:password:success:failure` method.

```objective-c
void (^loginFailureBlock)(NSError *);
loginFailureBlock = ^(NSError *error) {
   if (error.code == PinboardErrorInvalidCredentials) {
       // An invalid username or password was provided.
   }
   else if (error.code == PinboardErrorTimeout) {
       // The authentication request will time out if
       // it takes longer than 20 seconds to respond.
   }
};

ASPinboard *pinboard = [ASPinboard sharedInstance];
[pinboard authenticateWithUsername:PINBOARD_USERNAME
                          password:PINBOARD_PASSWORD
                           success:^(NSString *token) {
                               NSLog(@"Your Pinboard API token is: %@", token);
                           }
                           failure:loginFailureBlock];
```

After authenticating, ASPinboard stores the token internally for future requests.

If you want to use a token that you've previously stored or copied from your settings page, just use the `setToken` method on the ASPinboard shared instance before using ASPinboard to make requests to protected resources.

```objective-c
[pinboard setToken:token];
```

### Retrieving Bookmarks

Now that you have a token, let's grab your bookmarks, shall we?

```objective-c
void (^successBlock)(NSArray *, NSDictionary *);
successBlock = ^(NSArray *bookmarks, NSDictionary *parameters) {
    NSLog(@"Here are your bookmarks:");
    for (id bookmark in bookmarks) {
        NSLog(@"url: %@", bookmark[@"href"]);
    }
};

void (^failureBlock)(NSError *);
failureBlock = ^(NSError *error) {
   if (error != nil) {
       NSLog(@"Houston, we have a problem.");
   }
};

[pinboard bookmarksWithSuccess:successBlock failure:failureBlock];
```

### Adding a Bookmark

```objective-c
[pinboard addBookmarkWithURL:@"https://pinboard.in/"
                       title:@"Pinboard"
                 description:@"A cool bookmarking site"
                        tags:@"bookmarking services"
                      shared:YES
                      unread:NO
                     success:^{}
                     failure:failureBlock];
```

This method can also be used to update an existing bookmark. For more information, see the Pinboard documentation for [posts/add](https://pinboard.in/api#posts_add).

### Other Methods

Please see ASPinboard.h for the full list of supported methods.

## License

ASPinboard is available for use under the Apache License, Version 2.0. See LICENSE for more details.
