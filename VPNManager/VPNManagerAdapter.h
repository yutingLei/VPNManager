//
//  VPNManagerAdapter.h
//  VPNManager
//
//  Created by admin on 8/23/17.
//  Copyright © 2017 Favorite. All rights reserved.
//

#import <NetworkExtension/NetworkExtension.h>
#import <Foundation/Foundation.h>

#define kNotificationVPNStatus @"kNotificationVPNStatusChanged"

@interface VPNManagerAdapter : NSObject

//! Sigleton
+ (VPNManagerAdapter * _Nonnull)shared;
- (nonnull instancetype)init __unused;

//! Current vpn status
@property (nonatomic, assign, readonly) NEVPNStatus vpnStatus;

//! VPN Description or name. default "MyVPN"
@property (nonatomic, copy) NSString * _Nonnull vpnDescription;

//! VPN Server address. default "MyVPN"
@property (nonatomic, copy) NSString * _Nonnull vpnServerAddress;

//! Start Tunnel
- (void)startTunnelWithOptions:(NSDictionary <NSString *, id> * _Nullable)options;

//! Stop Tunnel
- (void)stopTunnel;

@end
