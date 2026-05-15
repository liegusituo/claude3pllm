# DeepSeek Proxy

A proxy tool for running Claude for Mac and Codex on macOS using DeepSeek v4 flash/pro models.

## Features

- 🌐 **API Proxy Service**: Convert Claude API requests to DeepSeek API format
- 🔄 **Model Mapping**: Automatically translate Claude and Codex model names to DeepSeek models
- 🌍 **Dual Language UI**: Support Chinese and English interface with one-click switching
- 📊 **Connection Logs**: Real-time display of client connections and model translations
- 🔒 **Secure Storage**: API Keys securely stored locally
- ⚙️ **Flexible Configuration**: Customizable port and multiple API keys
- 📱 **Dynamic Icons**: Menu bar icons display proxy status in real-time (running/stopped/error)

## Supported Model Mapping

### Claude Models
- `claude-deepseek-v4-pro` → `deepseek-v4-pro`
- `claude-deepseek-v4-flash` → `deepseek-v4-flash`

### Codex Models
- `GPT-5.5 / GPT-5.1` → `v4-pro` (high reasoning)
- `GPT-5.4-MINI` → `v4-flash` (low/medium reasoning)

## System Requirements

- macOS 14.0 or higher (macOS 14+ recommended)
- Apple Silicon (M1/M2/M3) chip (Intel supported but not guaranteed)

## Installation

### Method 1: Download from Gitee (recommended for Chinese users)

1. Visit the [Releases](https://gitee.com/42589378/claude3pllm/releases) page
2. Click to download `DeepSeekProxy-v1.0.5-macOS.zip` of the latest version (v1.0.5)
3. Extract the downloaded file:
   ```bash
   unzip DeepSeekProxy-v1.0.5-macOS.zip
   cd DeepSeekProxy-v1.0.5-macOS
   chmod +x DeepSeekProxy
   ```
4. Run the application:
   ```bash
   ./DeepSeekProxy
   ```

### Method 2: Download from GitHub (alternative)

1. Visit the [Actions](https://github.com/liegusituo/claude3pllm/actions) page
2. Click on the latest "Build and Release" run (with green ✅ mark)
3. At the bottom of the page under Artifacts section, click `DeepSeekProxy-macos` to download
4. Extract the downloaded file:
   ```bash
   unzip DeepSeekProxy-macos.zip
   cd dist
   chmod +x DeepSeekProxy
   ```
5. Run the application:
   ```bash
   ./DeepSeekProxy
   ```

### Method 3: Build from Source

```bash
git clone https://gitee.com/42589378/claude3pllm.git
cd claude3pllm
swift build -c release --arch arm64
./.build/release/DeepSeekProxy
```

## Configuration

### 1. Configure API Key

Click the menu bar icon → Settings to open the settings panel:

- **General Key**: Fallback key for all API requests
- **Codex Key**: Key specifically for Codex client
- **Claude Key**: Key specifically for Claude client

You can get an API Key from the [DeepSeek Open Platform](https://platform.deepseek.com/).

### 2. Configure Claude for Mac

Configure third-party inference in Claude Desktop:

1. Open Claude Desktop
2. Click Settings → "Configure third-party inference"
3. In the **Connection** section:
   - Select **Gateway**
   - **Gateway base URL**: `http://127.0.0.1:9797`
   - **Gateway API key**: Can be anything (proxy uses the API Key configured in DeepSeek Proxy)
   - **Gateway auth scheme**: Select `bearer`
   
4. In the **Identity & models** section:
   - Click to add models to the **Model list**, add the following two models:
     - **Model ID**: `claude-deepseek-v4-flash`, turn on **Offer 1M-context variant**
     - **Model ID**: `claude-deepseek-v4-pro`, turn on **Offer 1M-context variant**

### 3. Configure Codex

Add or modify in the Codex configuration file `~/.config/Codex/config.toml`:

```toml
[codex]
base_url = "http://127.0.0.1:9797/v1"
```

## Usage

1. Launch DeepSeek Proxy application
2. Find the proxy icon in the menu bar
3. Click the icon → Settings, configure DeepSeek API Key
4. Click "Start Proxy" button
5. Observe the menu bar icon color changes:
   - 🟢 Green: Running
   - 🟠 Orange: Starting
   - ⚫ Gray: Stopped
   - 🔴 Red: Error occurred
6. When status shows "Running", you can use Claude or Codex

## Language Switching

Click the menu bar icon → Settings, select in the top-right corner:
- 🇨🇳 Chinese
- 🇺🇸 English

## Viewing Logs

Click the menu bar icon → Logs to open the logs window:
- Real-time connection information
- View errors and warnings
- Can enable/disable logging with switch in settings

## Version History

### v1.0.5 (2026-05-15)
- ✅ Dynamic menu bar icons with different colors based on proxy status
- 🐛 Optimized proxy state management
- 🐛 Improved error handling mechanism

### v1.0.4 (2026-05-15)
- 🌍 Added Chinese/English interface switching function
- 🐛 Fixed Claude Desktop compatibility parameter conflict

### v1.0.3 (2026-05-14)
- 📊 Enhanced logging function, showing detailed connection information
- 🔧 Added log switch

### v1.0.2 (2026-05-14)
- ⚙️ Changed default port from 8787 to 9797

### v1.0.1 (2026-05-13)
- 🐛 Fixed application startup error handling

## Developer Notes

### Project Structure

```
DeepSeekProxy/
├── Sources/DeepSeekProxy/    # Swift Source Code
│   ├── App.swift            # App Entry Point
│   ├── ProxyManager.swift   # Proxy Management
│   ├── SettingsView.swift   # Settings View
│   ├── LogView.swift        # Log View
│   └── MenuBarView.swift    # Menu View
├── Resources/
│   └── deepseek_proxy.py    # Python Proxy Backend
├── Package.swift            # Swift Package Config
└── build.sh                # Build Script
```

### Build Commands

```bash
# Debug Build
swift build

# Release Build
swift build -c release --arch arm64

# Run
.build/release/DeepSeekProxy
```

### GitHub Actions Build

- Automatically triggered on tag push
- Build artifacts published as artifacts
- Can manually trigger: Actions → Build and Release → Run workflow

## FAQ

**Q: What if proxy fails to start?**
A: Check if port 9797 is already in use, you can change the port in settings.

**Q: Claude cannot connect?**
A: Ensure proxy is started (status shows "Running"), check if API Key is properly configured.

**Q: How to view proxy logs?**
A: Click menu bar icon → Logs, view in the opened window.

**Q: Menu bar icon not showing?**
A: Check if system accessibility permissions are granted.

## License

MIT License

## Feedback

For issues, please submit an [Issue](https://gitee.com/42589378/claude3pllm/issues).
