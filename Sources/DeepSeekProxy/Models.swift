import Foundation
import SwiftUI

enum ProxyStatus: Equatable {
    case stopped
    case starting
    case running(port: Int)
    case error(String)

    var displayName: String {
        switch self {
        case .stopped: return "已停止 / Stopped"
        case .starting: return "启动中... / Starting..."
        case .running(let port): return "运行中 :\(port) / Running :\(port)"
        case .error(let msg): return "错误: \(msg) / Error: \(msg)"
        }
    }

    var iconColor: Color {
        switch self {
        case .stopped: return .gray
        case .starting: return .orange
        case .running: return .green
        case .error: return .red
        }
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let level: LogLevel

    enum LogLevel: String, CaseIterable {
        case info = "INFO"
        case warn = "WARN"
        case error = "ERROR"
        case debug = "DEBUG"

        var color: Color {
            switch self {
            case .info: return .blue
            case .warn: return .orange
            case .error: return .red
            case .debug: return .gray
            }
        }
    }
}

struct AppSettings {
    var apiKey: String = ""
    var codexApiKey: String = ""
    var claudeApiKey: String = ""
    var port: Int = 9797
    var autoStart: Bool = false
    var launchAtLogin: Bool = false
    var loggingEnabled: Bool = true
    var locale: String = "zh"

    var hasAnyKey: Bool {
        !apiKey.isEmpty || !codexApiKey.isEmpty || !claudeApiKey.isEmpty
    }
    
    var isEnglish: Bool {
        locale == "en"
    }
}
