//
//  VPNManagerAdapter.m
//  VPNManager
//
//  Created by admin on 8/23/17.
//  Copyright © 2017 Favorite. All rights reserved.
//

#import "VPNManagerAdapter.h"
#import <UIKit/UIKit.h>

@interface VPNManagerAdapter ()
@end

@implementation VPNManagerAdapter {
    BOOL isAddedObserver;
}
@synthesize vpnServerAddress = _vpnServerAddress;
@synthesize vpnDescription   = _vpnDescription;
@synthesize vpnStatus        = _vpnStatus;

#pragma mark -
#pragma mark Setter & Getter
//! Description get & set
- (NSString *)vpnDescription {
    if (!_vpnDescription) {
        _vpnDescription = @"MyVPN";
    }
    return _vpnDescription;
}

- (void)setVpnDescription:(NSString *)vpnDescription {
    _vpnDescription = nil;
    _vpnDescription = vpnDescription;
}

//! Server Address get & set
- (NSString *)vpnServerAddress {
    if (!_vpnServerAddress) {
        _vpnServerAddress = @"MyVPN";
    }
    return _vpnServerAddress;
}

- (void)setVpnServerAddress:(NSString *)vpnServerAddress {
    _vpnServerAddress = nil;
    _vpnServerAddress = vpnServerAddress;
}

//! VPN Status set
- (void)setVpnStatus:(NEVPNStatus)vpnStatus {
    _vpnStatus = vpnStatus;
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kNotificationVPNStatus object:nil];
    });
}

#pragma mark -
#pragma mark Public func
//! Sigleton
+ (VPNManagerAdapter * _Nonnull)shared {
    static VPNManagerAdapter *instance = nil;
    static dispatch_once_t once_token;
    dispatch_once(&once_token, ^{
        instance = [VPNManagerAdapter new];
    });
    return instance;
}

//! Start Tunnel
- (void)startTunnelWithOptions:(NSDictionary <NSString *, id> * _Nullable)options {
    [self createManager:^(NETunnelProviderManager * _Nullable manager, NSError * _Nullable error) {
        if (manager) {
            if (manager.connection.status == NEVPNStatusDisconnected || manager.connection.status == NEVPNStatusInvalid) {
                NSError *connectionError;
                [manager.connection startVPNTunnelWithOptions:options andReturnError:&connectionError];
                if (connectionError) {
                    NSLog(@"Error: %@", connectionError);
                }
            }
        }
    }];
}

//! Stop Tunnel
- (void)stopTunnel {
    [self checkSystemManager:^(NETunnelProviderManager * _Nullable manager) {
        if (manager) {
            [manager.connection stopVPNTunnel];
        }
    }];
}

#pragma mark Private func
//! Init
- (instancetype)init {
    if (self = [super init]) {
        [self handleVPNStatus];
    }
    return self;
}

//! Get current VPN status
- (void)handleVPNStatus {
    [self checkSystemManager:^(NETunnelProviderManager * _Nullable manager) {
        if (manager) {
            _vpnStatus = manager.connection.status;
            [self addObserverForVPNStatusWithManager:manager];
        }
    }];
}

//! Add observer for status
- (void)addObserverForVPNStatusWithManager:(NETunnelProviderManager * _Nonnull)manager {
    if (!isAddedObserver) {
        isAddedObserver = YES;
        [NSNotificationCenter.defaultCenter addObserverForName:NEVPNStatusDidChangeNotification
                                                        object:manager.connection
                                                         queue:NSOperationQueue.mainQueue
                                                    usingBlock:^(NSNotification * _Nonnull note) {
            _vpnStatus = manager.connection.status;
        }];
    }
}

//! Get the first VPN Manager from system.
//! If not exist, create a new Manager and return it
- (void)createManager:(void(^)(NETunnelProviderManager * _Nullable manager, NSError * _Nullable error))handler {

    //! Load system preferences
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
        //! Load succeed
        if (managers) {

            //! create or build manager
            NETunnelProviderManager *manager = [self buildManager:(managers.count > 0) ? managers[0] : nil];

            //! save manager
            [manager saveToPreferencesWithCompletionHandler:^(NSError * _Nullable error) {

                //! save failed
                if (error) {
                    handler(nil, error);
                }

                //! save succeed
                [manager loadFromPreferencesWithCompletionHandler:^(NSError * _Nullable error) {
                    if (error) {
                        handler(nil, error);
                    } else {
                        handler(manager, nil);
                    }
                }];
            }];
        }

        //! Load failed
        else {
            handler(nil, error);
        }
    }];
}

//! Build manager.
//! if manager nil, create new one.
- (NETunnelProviderManager * _Nonnull)buildManager:(NETunnelProviderManager * _Nullable)manager {
    if (!manager) {
        manager = [NETunnelProviderManager new];
        manager.protocolConfiguration    = [NETunnelProviderProtocol new];
    }
    manager.enabled                  = YES;
    manager.onDemandEnabled          = YES;
    manager.localizedDescription     = self.vpnDescription;
    manager.protocolConfiguration.serverAddress    = self.vpnServerAddress;
    return manager;
}

//! Check system's managers
//! If exist, return first.
- (void)checkSystemManager:(void(^)(NETunnelProviderManager * _Nullable manager))handler {
    [NETunnelProviderManager loadAllFromPreferencesWithCompletionHandler:^(NSArray<NETunnelProviderManager *> * _Nullable managers, NSError * _Nullable error) {
        if (managers) {
            if (managers.count > 0) {
                handler(managers[0]);
                return;
            }
        }
        handler(nil);
    }];
}

@end
