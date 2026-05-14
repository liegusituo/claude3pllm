# DeepSeek Proxy

在 macOS 上运行 Claude for Mac 和 Codex 使用 DeepSeek v4 flash/pro 的代理工具。

## 功能特性

- 🌐 **API 代理服务**：将 Claude API 请求转换为 DeepSeek API 格式
- 🔄 **模型映射**：自动转换 Claude 和 Codex 模型名称到 DeepSeek 模型
- 🌍 **中英文界面**：支持中文和英文界面一键切换
- 📊 **连接日志**：实时显示客户端连接和模型转换日志
- 🔒 **安全存储**：API Key 安全存储在本地
- ⚙️ **灵活配置**：可自定义端口和多个 API 密钥

## 支持的模型映射

### Claude 模型
- `claude-deepseek-v4-pro` → `deepseek-v4-pro`
- `claude-deepseek-v4-flash` → `deepseek-v4-flash`

### Codex 模型
- `GPT-5.5 / GPT-5.1` → `v4-pro` (高推理)
- `GPT-5.4-MINI` → `v4-flash` (低/中推理)

## 系统要求

- macOS 14.0 或更高版本（推荐 macOS 14+）
- Apple Silicon (M1/M2/M3) 芯片（也支持 Intel 但不保证）

## 安装步骤

### 方法一：从 GitHub Actions 下载（推荐）

1. 访问 [Actions](https://github.com/liegusituo/claude3pllm/actions) 页面
2. 点击最新的 "Build and Release" 运行（带有绿色 ✅ 标记）
3. 在页面底部的 Artifacts 部分，点击 `DeepSeekProxy-macos` 下载
4. 解压下载的文件：
   ```bash
   unzip DeepSeekProxy-macos.zip
   cd dist
   chmod +x DeepSeekProxy
   ```
5. 运行应用：
   ```bash
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

你可以在 [DeepSeek 开放平台](https://platform.deepseek.com/) 获取 API Key。

### 2. Claude for Mac 配置

在 Claude Desktop 配置文件中添加自定义提供商：

- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%/Claude/claude_desktop_config.json`
- Linux: `~/.config/Claude/claude_desktop_config.json`

添加以下配置：

```json
{
  "provider": "custom",
  "base_url": "http://127.0.0.1:9797"
}
```

或者如果是多个提供商配置：

```json
{
  "providers": {
    "deepseek": {
      "base_url": "http://127.0.0.1:9797"
    }
  }
}
```

### 3. Codex 配置

在 Codex 配置文件 `~/.config/Codex/config.toml` 中添加或修改：

```toml
[codex]
base_url = "http://127.0.0.1:9797/v1"
```

## 使用方法

1. 启动 DeepSeek Proxy 应用
2. 在菜单栏中找到代理图标
3. 点击图标 → 设置，配置 DeepSeek API Key
4. 点击"启动代理"按钮
5. 状态显示"运行中"后，即可使用 Claude 或 Codex

## 语言切换

点击菜单栏图标 → 设置，在右上角选择：
- 🇨🇳 中文
- 🇺🇸 English

## 日志查看

点击菜单栏图标 → 日志，打开日志窗口：
- 实时查看连接信息
- 查看错误和警告
- 可以通过设置中的开关启用/禁用日志记录

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
│   └── MenuBarView.swift    # 菜单界面
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

### GitHub Actions 构建

- 每次推送 tag 时会自动触发构建
- 构建产物会作为 artifact 发布
- 可以手动触发构建：Actions → Build and Release → Run workflow

## 常见问题

**Q: 代理启动失败怎么办？**
A: 检查端口 9797 是否被占用，在设置中可以修改端口。

**Q: Claude 无法连接？**
A: 确保代理已启动（状态显示"运行中"），检查 API Key 是否正确配置。

**Q: 如何查看代理日志？**
A: 点击菜单栏图标 → 日志，在打开的窗口中查看。

## License

MIT License

## 问题反馈

如有问题，请提交 [Issue](https://github.com/liegusituo/claude3pllm/issues)。
