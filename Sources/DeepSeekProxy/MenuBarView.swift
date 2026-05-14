import SwiftUI

struct MenuBarView: View {
    @ObservedObject var proxyManager: ProxyManager

    private var isEnglish: Bool {
        proxyManager.settings.isEnglish
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            statusHeader

            Divider()

            modelInfoSection

            Divider()

            actionButtons

            Divider()

            Toggle(isEnglish ? "Launch at Login" : "开机启动", isOn: Binding(
                get: { proxyManager.settings.launchAtLogin },
                set: { proxyManager.settings.launchAtLogin = $0 }
            ))
            .toggleStyle(.checkbox)

            Divider()

            Button(isEnglish ? "Quit DeepSeek Proxy" : "退出 DeepSeek Proxy") {
                proxyManager.onAppTerminate()
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(minWidth: 280)
    }

    private func openSettingsWindow() {
        WindowManager.shared.showSettings(proxyManager: proxyManager)
    }

    private func openLogWindow() {
        WindowManager.shared.showLogs(proxyManager: proxyManager)
    }

    private var statusHeader: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(statusColor.opacity(0.3), lineWidth: 3)
                        .scaleEffect(proxyManager.status == .starting ? 1.5 : 1.0)
                        .opacity(proxyManager.status == .starting ? 0.4 : 0)
                )
                .animation(
                    proxyManager.status == .starting
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: proxyManager.status
                )

            Text(statusText)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            if proxyManager.status == .starting {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
            }
        }
        .padding(.bottom, 4)
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

    private var modelInfoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isEnglish ? "Model Mappings" : "模型映射")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Image(systemName: "message.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                Text("Claude:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("v4-pro")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                Text("/")
                    .font(.caption2)
                Text("v4-flash")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
            }

            HStack(spacing: 4) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
                Text("Codex:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("v4-pro")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                Text("/")
                    .font(.caption2)
                Text("v4-flash")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 4) {
            switch proxyManager.status {
            case .stopped, .error:
                Button(action: { proxyManager.startProxy() }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text(isEnglish ? "Start Proxy" : "启动代理")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(proxyManager.status == .starting)

            case .starting:
                Button(action: {}) {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                        Text(isEnglish ? "Starting..." : "启动中...")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(true)

            case .running:
                Button(action: { proxyManager.stopProxy() }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text(isEnglish ? "Stop Proxy" : "停止代理")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }

            HStack(spacing: 6) {
                Button(action: { openSettingsWindow() }) {
                    Label(isEnglish ? "Settings" : "设置", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: { openLogWindow() }) {
                    Label(isEnglish ? "Logs" : "日志", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}
