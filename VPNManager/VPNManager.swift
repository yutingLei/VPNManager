
/*********************************************************************
 *
 * FileName    :  Tunnel Manager
 *
 * Description :  VPN tunnel managed
 *
 * Creator     :  sean
 *
 * @Copyright © 2017 warpvpn. All rights reserved.
 *********************************************************************/

import UIKit
import NetworkExtension

//! Handler
fileprivate typealias CompletionHander = (NETunnelProviderManager?, Error?) -> Swift.Void

public class VPNManager: NSObject {

    //! Add observer for vpn status. (iOS >= 10.0)
    fileprivate var isAddedObserver = false

    //! Current VPN status. option nil.
    var vpnStatus: NEVPNStatus? {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("kNotificationVPNStatusChanged"), object: nil)
            }
        }
    }

    /**
     *  @function Singleton Instance
     *
     */
    static let shared = VPNManager()

    /**
     *  @function Init.
     *
     */
    override init() {
        super.init()
        updateVPNStatus()
    }

    /**
     *  @function Start tunnel
     *
     **  @param  options        VPN profile
     */
    func startTunnel(options: [String: NSObject]? = nil) {
        initializerOrCreateProviderManager {[unowned self] (manager, error) in
            if let manager = manager {
                let status = manager.connection.status
                if status == .disconnected || status == .invalid {
                    do {
                        try manager.connection.startVPNTunnel(options: options)
                    } catch {
                        print("Start tunnel error: \(error)")
                    }
                }
                self.updateVPNStatus()
            } else {
                print("Tunnel error: \(String(describing: error))")
            }
        }
    }

    /// Stop tunnel
    func stopTunnel() {
        checkSystemProviderManager { (manager, error) in
            if let manager = manager {
                manager.connection.stopVPNTunnel()
            }
        }
    }
}

//MARK: - Manager Extension
fileprivate extension VPNManager {

    /**
     *  @function Update VPN status.
     *
     */
    func updateVPNStatus() {
        checkSystemProviderManager {[unowned self] (manager, error) in
            if let manager = manager {
                if !self.isAddedObserver {
                    self.isAddedObserver = true
                    NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange,
                                                           object: manager.connection,
                                                           queue: OperationQueue.main,
                                                           using: {[unowned self] (notification) in
                        self.vpnStatus = manager.connection.status
                    })
                }
                self.vpnStatus = manager.connection.status
            }
        }
    }

    /**
     *  @function Create VPN manager if not exist. otherwise handler it
     *
     **  @param  completion     handler manager if needed
     */
    func initializerOrCreateProviderManager(_ completion: @escaping CompletionHander) {
        NETunnelProviderManager.loadAllFromPreferences { (managers, error) in

            /// check managers isEmpty
            if let managers = managers {
                var manager: NETunnelProviderManager
                if managers.count > 0 {
                    manager = managers[0]
                } else {
                    manager = self.createProviderManager()
                }

                /// setting manager
                self.configurationProviderManager(&manager)

                /// save manager
                manager.saveToPreferences(completionHandler: { (error) in
                    if let error = error {
                        completion(nil, error)
                    } else {
                        /// if no error. load current manager and with closure handler
                        manager.loadFromPreferences(completionHandler: { (error) in
                            if let error = error {
                                completion(nil, error)
                            } else {
                                completion(manager, nil)
                            }
                        })
                    }
                })

            } else {
                completion(nil, error)
            }
        }
    }

    /**
     *  @function Create a new VPN manager
     *
     */
    func createProviderManager() -> NETunnelProviderManager {
        let manager = NETunnelProviderManager()
        manager.protocolConfiguration = NETunnelProviderProtocol()
        return manager
    }

    /**
     *  @function Configuration for VPN manager
     *
     */
    func configurationProviderManager(_ manager: inout NETunnelProviderManager) {
        manager.isEnabled = true
        manager.isOnDemandEnabled = true
        manager.localizedDescription = "<#YOUR_VPN_NAME_IN_SYSTEM#>"
        manager.protocolConfiguration?.serverAddress = "<#YOUR_SERVER_ADDRESS#>"
    }

    /**
     *  @function Check system VPN manager. if exist and handler it or nil
     *
     **  @param  completion     handler manager if exist
     */
    func checkSystemProviderManager(_ completion: @escaping CompletionHander) {
        NETunnelProviderManager.loadAllFromPreferences { (managers, error) in
            if let managers = managers {
                if managers.count > 0 {
                    completion(managers[0], nil)
                } else {
                    completion(nil, nil)
                }
            } else {
                completion(nil, error)
            }
        }
    }
}
