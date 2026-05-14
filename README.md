# DeepSeek Proxy

在 macOS Tahoe 26 版本上运行 Claude for Mac 使用 DeepSeek v4 flash/pro 的代理工具。

## 功能特性

- 🌐 **API 代理服务**：将 Claude API 请求转换为 DeepSeek API 格式
- 🔄 **模型映射**：自动转换 Claude 和 Codex 模型名称到 DeepSeek 模型
- 🌍 **中英文界面**：支持中文和英文界面一键切换
- 📊 **连接日志**：实时显示客户端连接和模型转换日志
- 🔒 **安全存储**：API Key 安全存储在本地

## 支持的模型映射

### Claude 模型
- `claude-deepseek-v4-pro` → `deepseek-v4-pro`
- `claude-deepseek-v4-flash` → `deepseek-v4-flash`

### Codex 模型
- `GPT-5.5 / GPT-5.1` → `v4-pro` (高推理)
- `GPT-5.4-MINI` → `v4-flash` (低/中推理)

## 系统要求

- macOS Tahoe 26 或更高版本
- Apple Silicon (M1/M2/M3) 芯片

## 安装步骤

### 方法一：从 Release 下载

1. 进入 [Releases](https://github.com/liegusituo/claude3pllm/releases) 页面
2. 下载最新版本的 `DeepSeekProxy-macos-arm64.tar.gz`
3. 解压文件：
   ```bash
   tar -xzf DeepSeekProxy-macos-arm64.tar.gz
   ```
4. 进入 `dist` 目录运行：
   ```bash
   cd dist
   ./DeepSeekProxy
   ```

### 方法二：从源码编译

```bash
git clone https://github.com/liegusituo/claude3pllm.git
cd claude3pllm
swift build -c release --arch arm64
./.build/release/DeepSeekProxy
```

## 配置说明

### 1. 配置 API Key

点击菜单栏图标 → 设置，打开设置面板：

- **通用密钥**：用于所有 API 请求的备用密钥
- **Codex 密钥**：专门用于 Codex 客户端的密钥
- **Claude 密钥**：专门用于 Claude 客户端的密钥

### 2. Claude for Mac 配置

在 Claude Desktop 配置文件中添加：

```json
{
  "provider": "custom",
  "base_url": "http://127.0.0.1:9797"
}
```

### 3. Codex 配置

在 `~/.config/Codex/config.toml` 中添加：

```toml
base_url = "http://127.0.0.1:9797/v1"
```

## 使用方法

1. 启动 DeepSeek Proxy 应用
2. 在设置中配置 DeepSeek API Key
3. 点击"启动代理"按钮
4. 状态显示"运行中"后，即可使用 Claude 或 Codex

## 语言切换

点击菜单栏图标 → 设置，在右上角选择：
- 🇨🇳 中文
- 🇺🇸 English

## 界面预览

[截图待添加]

## 开发者说明

### 项目结构

```
DeepSeekProxy/
├── Sources/DeepSeekProxy/    # Swift 源代码
│   ├── App.swift            # 应用入口
│   ├── ProxyManager.swift   # 代理管理
│   ├── SettingsView.swift   # 设置界面
│   ├── LogView.swift        # 日志界面
│   └── ...
├── Resources/
│   └── deepseek_proxy.py    # Python 代理后端
├── Package.swift            # Swift 包配置
└── build.sh                # 构建脚本
```

### 构建命令

```bash
# Debug 构建
swift build

# Release 构建
swift build -c release --arch arm64

# 运行
.build/release/DeepSeekProxy
```

## License

MIT License

## 问题反馈

如有问题，请提交 [Issue](https://github.com/liegusituo/claude3pllm/issues)。
