import SwiftUI

struct SettingsView: View {
    @ObservedObject var proxyManager: ProxyManager
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var codexApiKey: String = ""
    @State private var claudeApiKey: String = ""
    @State private var port: String = ""
    @State private var autoStart: Bool = false
    @State private var selectedLocale: String = "zh"

    private var isEnglish: Bool {
        selectedLocale == "en"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(isEnglish ? "Settings" : "设置")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Picker("", selection: $selectedLocale) {
                    Text("中文").tag("zh")
                    Text("English").tag("en")
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                Button(isEnglish ? "Done" : "完成") { saveAndDismiss() }
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GroupBox(label: Label(isEnglish ? "API Keys" : "API 密钥", systemImage: "key.fill").foregroundColor(.orange)) {
                        VStack(alignment: .leading, spacing: 12) {
                            keyField(isEnglish ? "Universal Key" : "通用密钥", text: $apiKey, prompt: "sk-...", env: "DEEPSEEK_API_KEY")
                            keyField(isEnglish ? "Codex Key" : "Codex 密钥", text: $codexApiKey, prompt: "sk-... (optional)", env: "CODEX_DEEPSEEK_API_KEY")
                            keyField(isEnglish ? "Claude Key" : "Claude 密钥", text: $claudeApiKey, prompt: "sk-... (optional)", env: "CLAUDE_DEEPSEEK_API_KEY")

                            Text(isEnglish ? "Universal key is used as fallback when specific keys are not set." : "通用密钥在未设置专用密钥时作为备用。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                    }

                    GroupBox(label: Label(isEnglish ? "Proxy Settings" : "代理设置", systemImage: "antenna.radiowaves.left.and.right").foregroundColor(.blue)) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(isEnglish ? "Port:" : "端口：")
                                TextField("9797", text: $port)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                Spacer()
                            }

                            Toggle(isEnglish ? "Auto-start proxy on launch" : "启动时自动运行代理", isOn: $autoStart)

                            Text("Claude Desktop Base URL: http://127.0.0.1:\(port.isEmpty ? "9797" : port)")
                                .font(.caption)
                                .monospaced()
                            Text("Codex config.toml base_url: http://127.0.0.1:\(port.isEmpty ? "9797" : port)/v1")
                                .font(.caption)
                                .monospaced()
                        }
                        .padding(12)
                    }

                    GroupBox(label: Label(isEnglish ? "Model Mappings" : "模型映射", systemImage: "arrow.triangle.branch").foregroundColor(.green)) {
                        VStack(alignment: .leading, spacing: 8) {
                            mappingRow("Claude", "v4-pro", isEnglish ? "claude-deepseek-v4-pro → deepseek-v4-pro" : "claude-deepseek-v4-pro → deepseek-v4-pro")
                            mappingRow("Claude", "v4-flash", isEnglish ? "claude-deepseek-v4-flash → deepseek-v4-flash" : "claude-deepseek-v4-flash → deepseek-v4-flash")
                            Divider()
                            mappingRow("Codex", "v4-pro", isEnglish ? "GPT-5.5 / GPT-5.1 → v4-pro (high reason)" : "GPT-5.5 / GPT-5.1 → v4-pro (高推理)")
                            mappingRow("Codex", "v4-flash", isEnglish ? "GPT-5.4-MINI → v4-flash (low/med reason)" : "GPT-5.4-MINI → v4-flash (低/中推理)")
                        }
                        .padding(12)
                    }
                }
                .padding()
            }
        }
        .frame(width: 520, height: 600)
        .onAppear {
            apiKey = proxyManager.settings.apiKey
            codexApiKey = proxyManager.settings.codexApiKey
            claudeApiKey = proxyManager.settings.claudeApiKey
            port = String(proxyManager.settings.port)
            autoStart = proxyManager.settings.autoStart
            selectedLocale = proxyManager.settings.locale
        }
    }

    private func keyField(_ label: String, text: Binding<String>, prompt: String, env: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.subheadline).fontWeight(.medium)
            HStack {
                SecureField(prompt, text: text)
                    .textFieldStyle(.roundedBorder)
                Text(env)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospaced()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
    }

    private func mappingRow(_ agent: String, _ model: String, _ detail: String) -> some View {
        HStack(spacing: 6) {
            Text(agent)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(agent == "Claude" ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15))
                .cornerRadius(4)
            Text(model)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Text(detail)
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private func saveAndDismiss() {
        proxyManager.settings.apiKey = apiKey
        proxyManager.settings.codexApiKey = codexApiKey
        proxyManager.settings.claudeApiKey = claudeApiKey
        proxyManager.settings.port = Int(port) ?? 9797
        proxyManager.settings.autoStart = autoStart
        proxyManager.settings.locale = selectedLocale

        let defaults = UserDefaults.standard
        defaults.set(apiKey, forKey: "api_key")
        defaults.set(codexApiKey, forKey: "codex_api_key")
        defaults.set(claudeApiKey, forKey: "claude_api_key")
        defaults.set(Int(port) ?? 9797, forKey: "proxy_port")
        defaults.set(autoStart, forKey: "auto_start")
        defaults.set(selectedLocale, forKey: "locale")

        dismiss()
    }
}
