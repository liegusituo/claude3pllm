import SwiftUI
import AppKit

@main
struct DeepSeekProxyApp: App {
    @StateObject private var proxyManager = ProxyManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(proxyManager: proxyManager)
        } label: {
            MenuBarIcon(status: proxyManager.status)
        }
    }
}

struct MenuBarIcon: View {
    let status: ProxyStatus

    var body: some View {
        ZStack {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            Image(systemName: iconName)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(statusColor)
        }
        .frame(width: 20, height: 20)
    }

    private var iconName: String {
        switch status {
        case .stopped:
            return "antenna.radiowaves.left.and.right.slash"
        case .starting:
            return "antenna.radiowaves.left.and.right"
        case .running:
            return "antenna.radiowaves.left.and.right"
        case .error:
            return "antenna.radiowaves.left.and.right.trianglebadge.exclamationmark"
        }
    }

    private var statusColor: Color {
        switch status {
        case .stopped:
            return .gray
        case .starting:
            return .orange
        case .running:
            return .green
        case .error:
            return .red
        }
    }
}

struct MenuBarContent: View {
    @ObservedObject var proxyManager: ProxyManager

    private var isEnglish: Bool {
        proxyManager.settings.isEnglish
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            statusHeader
            Divider()
            actionButtons
            Divider()
            Toggle(isEnglish ? "Launch at Login" : "开机启动", isOn: $proxyManager.settings.launchAtLogin)
                .toggleStyle(.switch)
            Divider()
            Button(isEnglish ? "Quit DeepSeek Proxy" : "退出 DeepSeek Proxy") {
                proxyManager.onAppTerminate()
                NSApp.terminate(nil)
            }
        }
        .padding(12)
        .frame(minWidth: 260)
    }

    private var statusHeader: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            Text(statusText)
                .font(.headline)

            Spacer()

            if proxyManager.status == .starting {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
    }

    private var statusColor: Color {
        switch proxyManager.status {
        case .stopped: return .gray
        case .starting: return .orange
        case .running: return .green
        case .error: return .red
        }
    }

    private var statusText: String {
        switch proxyManager.status {
        case .stopped:
            return isEnglish ? "Stopped" : "已停止"
        case .starting:
            return isEnglish ? "Starting..." : "启动中..."
        case .running(let port):
            return isEnglish ? "Running :\(port)" : "运行中 :\(port)"
        case .error:
            return isEnglish ? "Error" : "错误"
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            switch proxyManager.status {
            case .stopped, .error:
                Button(action: { proxyManager.startProxy() }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text(isEnglish ? "Start Proxy" : "启动代理")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

            case .starting:
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(isEnglish ? "Starting..." : "启动中...")
                }
                .frame(maxWidth: .infinity)

            case .running:
                Button(action: { proxyManager.stopProxy() }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text(isEnglish ? "Stop Proxy" : "停止代理")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }

            HStack(spacing: 8) {
                Button(action: { WindowManager.shared.showSettings(proxyManager: proxyManager) }) {
                    Label(isEnglish ? "Settings" : "设置", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: { WindowManager.shared.showLogs(proxyManager: proxyManager) }) {
                    Label(isEnglish ? "Logs" : "日志", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}
