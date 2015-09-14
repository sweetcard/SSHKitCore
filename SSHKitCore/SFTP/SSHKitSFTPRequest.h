//
//  SSHKitSFTPRequest.h
//  SSHKitCore
//
//  Created by vicalloy on 9/11/15.
//
//

#import <Foundation/Foundation.h>
#import "SSHKitSFTPSession.h"
#import "SSHKitCoreCommon.h"

@interface SSHKitSFTPRequest : NSObject
@property (nonatomic, readonly, getter = isCancelled) BOOL cancelled;
@property (nonatomic, weak) SSHKitSFTPSession *sftpSession;
@property (nonatomic, readwrite, copy) SSHKitSFTPRequestCancelHandler cancelHandler;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, copy) id successBlock;
@property (nonatomic, copy) SSHKitSFTPClientFailureBlock failureBlock;

// may be called by the connection or the end user
- (void)cancel;

// Only the connection should call these methods
- (void)start:(SSHKitSFTPSession *)sftpSession; // subclasses must override
- (void)succeed; // subclasses must override and invoke their success blocks
- (void)fail; // subclasses need not override this

// Only subclasses should call these methods
- (BOOL)ready;
- (BOOL)checkSFTP;
- (BOOL)pathIsValid:(NSString *)path;
- (NSError *)errorWithCode:(SSHKitSFTPClientErrorCode)errorCode
          errorDescription:(NSString *)errorDescription
           underlyingError:(NSNumber *)underlyingError;
@end