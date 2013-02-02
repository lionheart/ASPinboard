//
//  NSString+URLEncoding.h
//  ASPinboard
//
//  Created by Dan Loewenherz on 1/29/13.
//  Copyright (c) 2013 Aurora Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (URLEncoding)

- (NSString *)urlEncode;
- (NSString *)urlEncodeUsingEncoding:(NSStringEncoding)encoding;

@end
