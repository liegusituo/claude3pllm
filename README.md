# DeepSeek Proxy

<span style="float: right;">[English](#english-readme) | [中文](#中文说明)</span>

---

## 🌐 DeepSeek Proxy

在 macOS 上运行 Claude for Mac 和 Codex 使用 DeepSeek v4 flash/pro 的代理工具。

A proxy tool for running Claude for Mac and Codex on macOS using DeepSeek v4 flash/pro models.

---

## 📋 功能特性 / Features

| 中文 | English |
|------|---------|
| 🌐 **API 代理服务** | Convert Claude API requests to DeepSeek API format |
| 🔄 **模型映射** | Automatically translate Claude and Codex model names |
| 🌍 **中英文界面** | Support Chinese and English interface switching |
| 📊 **连接日志** | Real-time display of client connections |
| 🔒 **安全存储** | API Keys securely stored locally |
| ⚙️ **灵活配置** | Customizable port and multiple API keys |
| 📱 **动态图标** | Menu bar icons display proxy status in real-time |

---

<a id="中文说明"></a>

## 🇨🇳 中文说明

### 安装步骤

**方法一：从 Gitee 下载（推荐国内用户）**

1. 访问 [Releases](https://gitee.com/42589378/claude3pllm/releases) 页面
2. 点击最新版本（v1.0.5）的 `DeepSeekProxy-v1.0.5-macOS.zip` 下载
3. 解压下载的文件：
   ```bash
   unzip DeepSeekProxy-v1.0.5-macOS.zip
   cd DeepSeekProxy-v1.0.5-macOS
   chmod +x DeepSeekProxy
   ```
4. 运行应用：
   ```bash
   ./DeepSeekProxy
   ```

**方法二：从源码编译**

```bash
git clone https://gitee.com/42589378/claude3pllm.git
cd claude3pllm
swift build -c release --arch arm64
./.build/release/DeepSeekProxy
```

### 配置说明

**1. 配置 API Key**

点击菜单栏图标 → 设置，打开设置面板：
- **通用密钥**：用于所有 API 请求的备用密钥
- **Codex 密钥**：专门用于 Codex 客户端的密钥
- **Claude 密钥**：专门用于 Claude 客户端的密钥

**2. Claude for Mac 配置**

在 Claude Desktop 中配置第三方推理：
1. 打开 Claude Desktop
2. 点击设置 → "Configure third-party inference"
3. 在 **Connection** 部分：
   - 选择 **Gateway**
   - **Gateway base URL**: `http://127.0.0.1:9797`
   - **Gateway API key**: 可以任意填写
   - **Gateway auth scheme**: 选择 `bearer`
4. 在 **Identity & models** 部分添加两个模型：
   - `claude-deepseek-v4-flash`
   - `claude-deepseek-v4-pro`

**3. Codex 配置**

在 `~/.config/Codex/config.toml` 中添加：
```toml
[codex]
base_url = "http://127.0.0.1:9797/v1"
```

### 使用方法

1. 启动 DeepSeek Proxy 应用
2. 在菜单栏中找到代理图标
3. 点击图标 → 设置，配置 DeepSeek API Key
4. 点击"启动代理"按钮
5. 观察菜单栏图标颜色变化：
   - 🟢 绿色：运行中
   - 🟠 橙色：启动中
   - ⚫ 灰色：已停止
   - 🔴 红色：发生错误

### 版本历史

- **v1.0.5**: 动态菜单栏图标，根据代理状态显示不同颜色
- **v1.0.4**: 添加中文/英文界面切换功能
- **v1.0.3**: 增强日志功能
- **v1.0.2**: 默认端口改为 9797

---

<a id="english-readme"></a>

## 🇺🇸 English Documentation

### Installation

**Method 1: Download from Gitee**

1. Visit [Releases](https://gitee.com/42589378/claude3pllm/releases) page
2. Download `DeepSeekProxy-v1.0.5-macOS.zip`
3. Extract and run:
   ```bash
   unzip DeepSeekProxy-v1.0.5-macOS.zip
   cd DeepSeekProxy-v1.0.5-macOS
   chmod +x DeepSeekProxy
   ./DeepSeekProxy
   ```

**Method 2: Build from Source**

```bash
git clone https://gitee.com/42589378/claude3pllm.git
cd claude3pllm
swift build -c release --arch arm64
./.build/release/DeepSeekProxy
```

### Configuration

**1. Configure API Key**

Click menu bar icon → Settings:
- **General Key**: Fallback key for all API requests
- **Codex Key**: Key specifically for Codex client
- **Claude Key**: Key specifically for Claude client

**2. Configure Claude for Mac**

1. Open Claude Desktop
2. Click Settings → "Configure third-party inference"
3. In **Connection**:
   - Select **Gateway**
   - **Gateway base URL**: `http://127.0.0.1:9797`
   - **Gateway API key**: Can be anything
   - **Gateway auth scheme**: Select `bearer`
4. In **Identity & models**, add:
   - `claude-deepseek-v4-flash`
   - `claude-deepseek-v4-pro`

**3. Configure Codex**

Add to `~/.config/Codex/config.toml`:
```toml
[codex]
base_url = "http://127.0.0.1:9797/v1"
```

### Usage

1. Launch DeepSeek Proxy
2. Find proxy icon in menu bar
3. Click icon → Settings, configure DeepSeek API Key
4. Click "Start Proxy" button
5. Observe menu bar icon color:
   - 🟢 Green: Running
   - 🟠 Orange: Starting
   - ⚫ Gray: Stopped
   - 🔴 Red: Error

### Version History

- **v1.0.5**: Dynamic menu bar icons based on proxy status
- **v1.0.4**: Added Chinese/English interface switching
- **v1.0.3**: Enhanced logging function
- **v1.0.2**: Changed default port to 9797

---

## 📝 License

MIT License

---

<span style="float: right;">[中文](#中文说明) | [English](#english-readme)</span>
