//
//  SSHKitDirectChannel.h
//  SSHKit
//
//  Created by Yang Yubo on 10/29/14.
//
//

#import "SSHKitChannel.h"

@interface SSHKitDirectChannel : SSHKitChannel

@property NSString      *host;
@property NSUInteger    port;

@end