//
//  TunnelManager.swift
//  Runner
//
//  Created by ZeroQ on 2024/9/10.
//

import Combine
import NetworkExtension

public final class VPNManager: ObservableObject {
    
    private var cancellables: Set<AnyCancellable> = []
    private var callback: ((String, [String: Any?]) -> Void)?
    @Published public var controller: VPNController?
    
    public static let shared = VPNManager()
    
    private let providerBundleIdentifier: String = {
        let identifier = Bundle.main.infoDictionary?["CFBundleIdentifier"] as! String
        #if os(macOS)
        return "\(identifier).ZeroQTunnelmacOS"
        #elseif os(iOS)
        return "\(identifier).ZeroQTunneliOS"
        #endif
    }()
    
    private init() {
        NotificationCenter.default
            .publisher(for: .NEVPNConfigurationChange, object: nil)
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in self.handleVPNConfigurationChangedNotification($0) }
            .store(in: &self.cancellables)
        Task(priority: .high) {
            await self.loadController()
        }
    }
    
    private func handleVPNConfigurationChangedNotification(_ notification: Notification) {
        Task(priority: .high) {
            await self.loadController()
        }
    }
    
    @discardableResult
    func loadController() async -> VPNController? {
        if let manager = try? await self.loadCurrentTunnelProviderManager() {
            if self.controller?.isEqually(manager: manager) ?? false {
                // Nothing
            } else {
                await MainActor.run {
                    self.controller = VPNController(providerManager: manager)
                }
            }
        } else {
            await MainActor.run {
                self.controller = nil
            }
        }
        return self.controller
    }
    
    private func loadCurrentTunnelProviderManager() async throws -> NETunnelProviderManager? {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        
        var oneManager: NETunnelProviderManager?
        managers.forEach { tunnelManager in
            guard let proto = tunnelManager.protocolConfiguration as? NETunnelProviderProtocol else {return}
            guard proto.providerBundleIdentifier == self.providerBundleIdentifier else {return}
            guard let protoVersion = proto.providerConfiguration?["Version"],
                  let protoBuildNo = proto.providerConfiguration?["BuildNo"],
                  protoVersion as! String == ZeroQ.appVersion
                    && protoBuildNo as! String == ZeroQ.appBuildNO else {
                tunnelManager.removeFromPreferences() {_ in}
                return
            }
            oneManager = tunnelManager
        }
        
        guard let oneManager = oneManager else {
            return nil
        }
        oneManager.isEnabled = true
        try await oneManager.saveToPreferences()
        return oneManager
    }
    
    public func setCallback(callback: @escaping (String, [String: Any]) -> Void) {
        self.callback = callback
    }
    
    public func callbackWithKey(key: String, params: [String: Any?]) {
        self.callback?(key, params)
    }
    
    public func installVPNConfiguration() async throws {
        let manager = (try? await loadCurrentTunnelProviderManager()) ?? NETunnelProviderManager()
        manager.localizedDescription = "ZeroQ"
        manager.protocolConfiguration = {
            let configuration = NETunnelProviderProtocol()
            configuration.providerBundleIdentifier = self.providerBundleIdentifier
            configuration.serverAddress = "ZeroQ"
            configuration.providerConfiguration = ["Version" : ZeroQ.appVersion, "BuildNo" : ZeroQ.appBuildNO]
//            configuration.includeAllNetworks = true
//            configuration.enforceRoutes = true
//            configuration.excludeLocalNetworks = true
//            configuration.excludeCellularServices = true
//            configuration.excludeAPNs = true
//            configuration.excludeDeviceCommunication =true
            return configuration
        }()
        manager.isEnabled = true
        manager.isOnDemandEnabled = true
        ZeroQ.logger.info("ZeroQ Install Configuration")
        try await manager.saveToPreferences()
        try await Task.sleep(nanoseconds: 200_000_000)//0.1s
        try await manager.loadFromPreferences()
        await self.loadController()
    }
}

public final class VPNController: ObservableObject {
    
    private var cancellables: Set<AnyCancellable> = []
    private let providerManager: NETunnelProviderManager
    
    public var connectedDate: Date? {
        self.providerManager.connection.connectedDate
    }
    
    @Published public var connectionStatus: NEVPNStatus
    
    public init(providerManager: NETunnelProviderManager) {
        self.providerManager = providerManager
        self.connectionStatus = providerManager.connection.status
        NotificationCenter.default
            .publisher(for: Notification.Name.NEVPNStatusDidChange, object: nil)
            .receive(on: OperationQueue.main)
            .sink { [unowned self] in self.handleVPNStatusDidChangeNotification($0) }
            .store(in: &self.cancellables)
    }
    
    private func handleVPNStatusDidChangeNotification(_ notification: Notification) {
        var params: [String : Any?] = [:]
        guard let session = notification.object as? NETunnelProviderSession else {return}
        self.connectionStatus = session.status
        if self.connectionStatus == .connected {
            params["connected"] = true
        } else if self.connectionStatus == .disconnected {
            params["connected"] = false
            params["msg"] = UserDefaults.shared.string(forKey: ZeroQ.DefaultKeys.LAST_ERR_MSG.rawValue)
            UserDefaults.shared.removeObject(forKey: ZeroQ.DefaultKeys.LAST_ERR_MSG.rawValue)
        } else {
            return
        }
        VPNManager.shared.callbackWithKey(key: "statusChanged", params: params)
    }
    
    public func isEqually(manager: NETunnelProviderManager) -> Bool {
        self.providerManager === manager
    }
    
    public func startVPN(configMap: [String : Any]) async throws {
        switch self.providerManager.connection.status {
        case .disconnecting, .disconnected:
            break
        case .connecting, .connected, .reasserting:
            return
        case .invalid:
            try await self.providerManager.removeFromPreferences()
            try await VPNManager.shared.installVPNConfiguration()
            return
        @unknown default:
            break
        }
        if !self.providerManager.isEnabled {
            self.providerManager.isEnabled = true
            try await self.providerManager.saveToPreferences()
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        do {
            let options = ["z" : try JSONSerialization.data(withJSONObject: configMap).base64EncodedString() as NSObject]
            try self.providerManager.connection.startVPNTunnel(options: options)
        } catch {
            ZeroQ.logger.error("error: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    public func stopVPN() {
        switch self.providerManager.connection.status {
        case .disconnecting, .disconnected:
            return
        case .invalid:
            self.providerManager.removeFromPreferences()
            return
        case .connecting, .connected, .reasserting:
            break
        @unknown default:
            break
        }
        self.providerManager.connection.stopVPNTunnel()
    }
    
    public func status() async throws -> String? {
        guard let stats = await sendProviderMessage(ZeroQ.Command.Status) else {return nil}
        return String(data: stats, encoding: .utf8)!
    }
    
    public func disableVPN() {
        self.providerManager.isEnabled = false
        self.providerManager.saveToPreferences()
    }
    
    public func uninstallVPNConfiguration() async throws {
        ZeroQ.logger.info("ZeroQ Uninstall Configuration")
        try await self.providerManager.removeFromPreferences()
    }
    
    @discardableResult
    public func sendProviderMessage(_ command: ZeroQ.Command) async -> Data? {
        guard self.connectionStatus != .invalid || self.connectionStatus != .disconnected else {
            return nil
        }
        return try? await self.providerManager.sendProviderMessage(data: try JSONEncoder().encode(command))
    }
}

fileprivate extension NETunnelProviderManager {
    
    @discardableResult
    func sendProviderMessage(data: Data) async throws -> Data? {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try (self.connection as! NETunnelProviderSession).sendProviderMessage(data) {
                    continuation.resume(with: .success($0))
                }
            } catch {
                continuation.resume(with: .failure(error))
            }
        }
    }
}
