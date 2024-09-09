//
//  ZeroqConstant.swift
//  Runner
//
//  Created by ZeroQ on 2024/10/18.
//

import Foundation
import OSLog

public extension UserDefaults {
    static let shared: UserDefaults = UserDefaults(suiteName: ZeroQ.appGroup)!
}

public enum ZeroQ {
    public static let logger: Logger = Logger(subsystem: "ZeroQTunnel", category: "ZeroQ")
    
    public static let appGroup: String = Bundle.main.infoDictionary?["ZeroQ_APP_GROUP"] as! String
    public static let appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
    public static let appBuildNO: String = Bundle.main.infoDictionary?["CFBundleVersion"] as! String
    
    public enum Command: Codable {
        case Status
        case Stats
    }
    
    public enum DefaultKeys: String {
        case LAST_ERR_CODE = "LAST_ERR_CODE"
        case LAST_ERR_MSG = "LAST_ERR_MSG"
    }
}
