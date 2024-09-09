//
//  PacketTunnelProvider.swift
//  ZeroQTunnelmacOS
//
//  Created by ZeroQ on 2024/9/10.
//

import NetworkExtension
import AnyLinkKit
import OSLog

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    
    public static let logger: Logger = Logger(subsystem: "ZeroQLogger", category: "AnyLinkTunnel")
    
    private lazy var adapter: AnyLinkAdapter = {
        return AnyLinkAdapter(with: self) { level, message in
            switch AnyLinkLogLevel(rawValue: level.rawValue) {
            case .verbose:
                Self.logger.notice("\(message, privacy: .public)")
            default:
                Self.logger.error("\(message, privacy: .public)")
            }
        }
    }()

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        
        // Add code here to start the process of connecting the tunnel.
        adapter.start(tunnelConfiguration: options!) { adapterError in
            guard let adapterError = adapterError else {
                let interfaceName = self.adapter.interfaceName ?? "unknown"
                Self.logger.info("Tunnel interface is \(interfaceName, privacy: .public)")
                completionHandler(nil)
                return
            }
            switch adapterError {
            case .connotinitconfiguration(let ret, let msg):
                UserDefaults.shared.set(ret, forKey: ZeroQ.DefaultKeys.LAST_ERR_CODE.rawValue)
                UserDefaults.shared.set(msg, forKey: ZeroQ.DefaultKeys.LAST_ERR_MSG.rawValue)
                Self.logger.error("Preparing tunnel failed code: \(ret) , msg: \(msg, privacy: .public)")
            case .cannotLocateTunnelFileDescriptor:
                Self.logger.error("Starting tunnel failed: could not determine file descriptor")
            case .setNetworkSettings(let error):
                Self.logger.error("Starting tunnel failed with setTunnelNetworkSettings returning \(error.localizedDescription, privacy: .public)")
                UserDefaults.shared.set(error.localizedDescription, forKey: ZeroQ.DefaultKeys.LAST_ERR_MSG.rawValue)
            case .startAnyLinkBackend(let errorCode):
                Self.logger.error("Starting tunnel failed with wgTurnOn returning \(errorCode)")
                UserDefaults.shared.set(errorCode, forKey: ZeroQ.DefaultKeys.LAST_ERR_CODE.rawValue)
            case .invalidState:
                // Must never happen
                fatalError()
            }
            completionHandler(adapterError)
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        adapter.stop { error in

            if let error = error {
                Self.logger.error("Failed to stop AnyLink adapter: \(error.localizedDescription, privacy: .public)")
            }
            completionHandler()

            #if os(macOS)
            // HACK: This is a filthy hack to work around Apple bug 32073323 (dup'd by us as 47526107).
            // Remove it when they finally fix this upstream and the fix has been rolled out to
            // sufficient quantities of users.
            exit(0)
            #endif
        }
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let completionHandler = completionHandler else { return }

        let command = try? JSONDecoder().decode(ZeroQ.Command.self, from: messageData)
        switch command {
        case .Status:
            adapter.status { status in
                completionHandler(status)
            }
        case .Stats:
            adapter.stats { stats in
                completionHandler(stats)
            }
        default:
            completionHandler(nil)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
    }
}
