
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

    //! 是否添加了观察者标志.
    fileprivate var isAddedObserver = false

    //! VPN描述(名称)，在手机系统中的显示名称和地址
    fileprivate var vpnDescription = "MyVPN"
    fileprivate var serverAddress = "MyVPN"

    // VPN状态，默认为nil
    public var vpnStatus: NEVPNStatus? {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("kNotificationVPNStatusChanged"), object: nil)
            }
        }
    }

    //! 单例
    static let shared = VPNManager()

    //! 初始化方法，默认获取当前VPN状态
    override init() {
        super.init()
        updateVPNStatus()
    }

    // @function   设置VPN在系统中的显示名称和地址
    func setDescription(_ text: String, serverAddress addressName: String) {
        vpnDescription = text
        serverAddress = addressName
    }

    // @function 启动Tunnel
    // @param  options 启动参数，与ProviderManager中的options是同一个值
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

    // @function 关闭Tunnel
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

    //! @function   获取当前VPN的状态，仅在初始化对象时使用。
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

    //! @function 初始化或创建Tunnel管理器
    func initializerOrCreateProviderManager(_ completion: @escaping CompletionHander) {
        NETunnelProviderManager.loadAllFromPreferences { (managers, error) in

            //! 系统没有VPN设置
            if let managers = managers {
                var manager: NETunnelProviderManager
                if managers.count > 0 {
                    manager = managers[0]
                } else {
                    manager = self.createProviderManager()
                }

                //! 配置VPN
                self.configurationProviderManager(&manager)

                //! 保存配置
                manager.saveToPreferences(completionHandler: { (error) in
                    if let error = error {
                        completion(nil, error)
                    } else {
                        //! 保存后重新获取VPN配置管理器
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

    //! @function   创建Tunnel管理器
    func createProviderManager() -> NETunnelProviderManager {
        let manager = NETunnelProviderManager()
        manager.protocolConfiguration = NETunnelProviderProtocol()
        return manager
    }

    //! @function 配置Tunnel管理器
    func configurationProviderManager(_ manager: inout NETunnelProviderManager) {
        manager.isEnabled = true
        manager.isOnDemandEnabled = true
        manager.localizedDescription = vpnDescription
        manager.protocolConfiguration?.serverAddress = serverAddress
    }

    //! @function 检车系统中是否存在VPN配置，如果有则返回，否则nil
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
