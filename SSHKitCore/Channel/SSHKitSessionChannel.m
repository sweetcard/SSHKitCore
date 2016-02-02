//
//  SSHKitSessionChannel.m
//  SSHKitCore
//
//  Created by Yang Yubo on 2/2/16.
//
//

#import "SSHKitSessionChannel.h"
#import "SSHKitSession.h"
#import "SSHKitCore+Protected.h"

@implementation SSHKitSessionChannel

- (void)openShellWithTerminalType:(NSString *)type columns:(NSInteger)columns rows:(NSInteger)rows {
    self.stage = SSHKitChannelStageWating;
    
    __weak SSHKitSessionChannel *weakSelf = self;
    [self.session dispatchAsyncOnSessionQueue: ^{ @autoreleasepool {
        __strong SSHKitSessionChannel *strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (!strongSelf.session.isConnected || strongSelf.stage != SSHKitChannelStageWating) {
            if (strongSelf->_delegateFlags.didCloseWithError) {
                [strongSelf.delegate channelDidClose:strongSelf withError:nil];
            }
            
            return_from_block;
        }
        
        if ([strongSelf _initiate]) {
            strongSelf->_shellColumns = columns;
            strongSelf->_shellRows = rows;
            [strongSelf _openSession];
        }
    }}];
}

- (void)_openSession {
    int result = ssh_channel_open_session(self.rawChannel);
    
    switch (result) {
        case SSH_AGAIN:
            // try again
            break;
            
        case SSH_OK:
            self.stage = SSHKitChannelStageRequestPTY;
            
            // opened
            [self _requestPty];
            
            break;
            
        default:
            // open failed
            [self _doCloseWithError:self.session.coreError];
            [self.session disconnectIfNeeded];
            break;
    }
}

- (void)_requestPty {
    int result = ssh_channel_request_pty_size(self.rawChannel, "xterm", (int)_shellColumns, (int)_shellRows);
    
    switch (result) {
        case SSH_AGAIN:
            // try again
            break;
            
        case SSH_OK:
            self.stage = SSHKitChannelStageRequestShell;
            
            // opened
            [self _requestShell];
            
            break;
            
        default:
            // open failed
            [self _doCloseWithError:self.session.coreError];
            [self.session disconnectIfNeeded];
            break;
    }
}

- (void)_requestShell {
    int result = ssh_channel_request_shell(self.rawChannel);
    
    switch (result) {
        case SSH_AGAIN:
            // try again
            break;
            
        case SSH_OK:
            self.stage = SSHKitChannelStageReadWrite;
            [self _registerCallbacks];
            
            // opened
            if (_delegateFlags.didOpen) {
                [self.delegate channelDidOpen:self];
            }
            break;
            
        default:
            // open failed
            [self _doCloseWithError:self.session.coreError];
            [self.session disconnectIfNeeded];
            break;
    }
}

- (void)doProcess {
    NSAssert([self.session isOnSessionQueue], @"Must be dispatched on session queue");
    
    switch (self.stage) {
        case SSHKitChannelStageOpening:
                [self _openSession];
            
            break;
            
        case SSHKitChannelStageRequestPTY:
            [self _requestPty];
            break;
            
            
        case SSHKitChannelStageRequestShell:
            [self _requestShell];
            break;
            
        case SSHKitChannelStageReadWrite:
            [self _doWrite];
            break;
            
        case SSHKitChannelStageClosed:
        default:
            break;
    }
}

- (void)changePtySizeToColumns:(NSInteger)columns rows:(NSInteger)rows {
    __weak SSHKitSessionChannel *weakSelf = self;
    
    [self.session dispatchAsyncOnSessionQueue:^{ @autoreleasepool {
        __strong SSHKitSessionChannel *strongSelf = weakSelf;
        
        if (strongSelf.stage != SSHKitChannelStageReadWrite || !strongSelf.session.isConnected) {
            return_from_block;
        }
        
        int rc = ssh_channel_change_pty_size(strongSelf.rawChannel, (int)columns, (int)rows);
        
        if (!strongSelf->_delegateFlags.didChangePtySizeToColumnsRows) {
            return;
        }
        
        NSError *error = nil;
        
        // According to "6.7.  Window Dimension Change Message", "window-change" request won't receive a response, `ssh_channel_change_pty_size` will never return SSH_AGAIN
        if (rc != SSH_OK) {
            error = strongSelf.session.coreError;
            if (!error) {
                error = [NSError errorWithDomain:SSHKitLibsshErrorDomain
                                            code:rc
                                        userInfo: @{ NSLocalizedDescriptionKey : @"Failed to change remote pty size" }];
            }
        }
        
        [strongSelf.delegate channel:strongSelf didChangePtySizeToColumns:columns rows:rows withError:error];
    }}];
}

@end
