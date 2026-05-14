import SwiftUI

struct LogView: View {
    @ObservedObject var proxyManager: ProxyManager
    @Environment(\.dismiss) private var dismiss
    @State private var filterLevel: LogEntry.LogLevel? = nil
    @State private var searchText = ""
    @State private var autoScroll = true
    @State private var copiedMessage: String? = nil

    private var isEnglish: Bool {
        proxyManager.settings.isEnglish
    }

    private var filteredLogs: [LogEntry] {
        var logs = proxyManager.logs
        if let level = filterLevel {
            logs = logs.filter { $0.level == level }
        }
        if !searchText.isEmpty {
            logs = logs.filter { $0.message.localizedCaseInsensitiveContains(searchText) }
        }
        return logs
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(isEnglish ? "Proxy Logs" : "代理日志")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                HStack(spacing: 12) {
                    ForEach(LogEntry.LogLevel.allCases, id: \.self) { level in
                        Button {
                            filterLevel = filterLevel == level ? nil : level
                        } label: {
                            Text(level.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(filterLevel == level ? level.color.opacity(0.2) : Color.clear)
                                .foregroundColor(filterLevel == level ? level.color : .secondary)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(filterLevel == level ? level.color : Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        TextField(isEnglish ? "Search..." : "搜索...", text: $searchText)
                            .textFieldStyle(.plain)
                            .frame(width: 120)
                            .font(.caption)
                    }
                    .padding(4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)

                    Toggle(isOn: Binding(
                        get: { proxyManager.settings.loggingEnabled },
                        set: { proxyManager.settings.loggingEnabled = $0 }
                    )) {
                        Image(systemName: "scroll")
                            .font(.caption)
                    }
                    .toggleStyle(.button)
                    .help(isEnglish ? "Enable logging" : "启用日志")

                    Toggle(isOn: $autoScroll) {
                        Image(systemName: "arrow.down.to.line")
                            .font(.caption)
                    }
                    .toggleStyle(.button)
                    .help(isEnglish ? "Auto-scroll" : "自动滚动")

                    Button(action: {
                        proxyManager.logs.removeAll()
                        if case .error = proxyManager.status {
                            proxyManager.status = .stopped
                        }
                    }) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .help(isEnglish ? "Clear logs and reset error state" : "清空日志并重置错误状态")
                    .buttonStyle(.borderless)

                    Button(isEnglish ? "Done" : "完成") { dismiss() }
                        .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .padding()

            Divider()

            if filteredLogs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(isEnglish ? "No log entries match your filter." : "没有匹配的日志。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredLogs) { entry in
                                logRow(entry)
                                    .id(entry.id)
                            }
                        }
                    }
                    .onChange(of: filteredLogs.last?.id) { _, _ in
                        if autoScroll, let last = filteredLogs.last {
                            withAnimation {
                                scrollProxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 680, height: 440)
        .overlay(alignment: .bottom) {
            if copiedMessage != nil {
                Text(isEnglish ? "Copied!" : "已复制！")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .cornerRadius(6)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { copiedMessage = nil }
                        }
                    }
            }
        }
    }

    private func logRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.timestamp, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute().second())
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            Text(entry.level.rawValue)
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(entry.level.color.opacity(0.15))
                .foregroundColor(entry.level.color)
                .cornerRadius(3)
                .frame(width: 44, alignment: .leading)

            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.message, forType: .string)
                copiedMessage = entry.message
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 9))
            }
            .buttonStyle(.borderless)
            .opacity(0.5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .background(Color.clear)
    }
}
