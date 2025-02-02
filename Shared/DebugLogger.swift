import Foundation
import SwiftUI

public enum DebugLogger {
    public static var logs: [DebugLog] = []
    
    static func log(_ message: String, type: DebugLogType = .info, details: String? = nil) {
        let log = DebugLog(type: type, message: message, details: details)
        logs.append(log)
        print("[\(log.type.rawValue.uppercased())] \(log.message)")
        if let details = details {
            print("Details: \(details)")
        }
    }
    
    static func getLogs() -> [DebugLog] {
        return logs
    }
    
    static func clearLogs() {
        logs.removeAll()
    }
}

public struct DebugLog: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let type: DebugLogType
    public let message: String
    public let details: String?
    
    public init(
        timestamp: Date = Date(),
        type: DebugLogType = .info,
        message: String,
        details: String? = nil
    ) {
        self.timestamp = timestamp
        self.type = type
        self.message = message
        self.details = details
    }
}

public enum DebugLogType: String, CaseIterable {
    case info
    case error
    case network
}

public enum LogType {
    case info
    case error
} 