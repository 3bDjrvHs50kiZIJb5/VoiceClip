# TTS Voice（VoiceClip）

基于 **Swift / SwiftUI** 的 **macOS 菜单栏应用**：在任意应用中划选文本后，通过快捷键调用**字节火山 OpenSpeech（TTS）**接口合成语音并播放。可与同系列的 **Electron 桌面版**共用配置目录与 `settings.json`。

## 环境要求

- **macOS 13（Ventura）** 或更高版本  
- **Xcode** 或 **Swift 5.9+** 命令行工具（`swift build`）

## 功能概览

| 能力 | 说明 |
|------|------|
| 菜单栏图标 | 后台常驻，无 Dock 图标（`accessory` 模式） |
| 划词朗读 | 模拟 **⌘C** 从剪贴板读取当前选中文本（需「辅助功能」授权） |
| 全局快捷键 | 系统级热键注册，默认 **⌘⇧L**（可在设置中修改） |
| 长文本 | 按句合并后按长度/字节拆分，与 Node 版 `splitText` 语义对齐 |
| 队列播放 | 流式分片音频入队播放 |
| 系统通知 | 朗读开始、错误等提示 |

## 配置说明

设置保存在：

`~/Library/Application Support/TTS Voice/settings.json`

与 Electron 版 **productName: TTS Voice** 的 userData 一致，便于两版本共用同一配置。

### 必填与常用项

- **TTS App ID**、**TTS Bearer Token**：火山 OpenSpeech 控制台获取  
- **音色**：如 `BV001_streaming`（女生）、`BV002_streaming`（男生）  
- **语速**：约 `0.8`～`1.8`  

### 高级与服务端参数（一般保持默认即可）

- **音量 / 音调**：对应 Node 版 `volume_ratio` / `pitch_ratio`  
- **Cluster**、**Endpoint**、**UID**、**Encoding**：与接口文档及桌面版 `settings.json` 字段一致  

首次未填写 App ID / Token 时，触发朗读会提示并打开设置页。

## 权限与使用注意

1. **辅助功能**：划词依赖模拟复制，须在 **系统设置 → 隐私与安全性 → 辅助功能** 中勾选本应用。  
2. **同一安装路径**：若混用 **Xcode 调试** 与 **正式 `.app`**，系统可能视为不同程序，需分别授权；建议日常使用固定路径（例如仅使用「应用程序」内的安装包）。  
3. **F1–F12**：单独用作快捷键时可能与系统或其它软件冲突；可改用 **⌘ / ⌃ / ⇧** 与字母组合，或在 **系统设置 → 键盘** 中开启「将 F1、F2 等键用作标准功能键」。  
4. **最短文本长度**：选中文本少于约 10 个字符时不会调用 TTS（与产品逻辑一致）。  

## 开发与构建

### 命令行编译

```bash
cd /path/to/VoiceClip
swift build
swift run TTSVoice
```

### 打包为 `.app`

```bash
./scripts/package-app.sh
```

产物：`dist/TTSVoice.app`。脚本会先生成 `Resources/AppIcon.icns`（依赖 `sips` / `iconutil`），再 **Release** 编译并拷贝资源；若本机有 `codesign`，会尝试 **ad-hoc** 签名以便本机运行。

首次运行示例：

```bash
open dist/TTSVoice.app
```

### 仅生成应用图标

```bash
./scripts/build-icon.sh
```

从 `Resources/tray-icon-light.png` 生成多尺寸 `AppIcon.icns`。

## 项目结构（简要）

- `Package.swift`：Swift Package 定义，可执行目标名 **TTSVoice**  
- `Sources/TTSVoice/`：应用源码（菜单栏、设置、热键、TTS 客户端、选区读取、播放队列等）  
- `Resources/`：`Info.plist`、托盘/应用图标等  
- `scripts/`：图标与 `.app` 打包脚本  

## 技术栈

- **SwiftUI** + **AppKit**（`MenuBarExtra`、`NSApplicationDelegate`）  
- **URLSession** 调用 OpenSpeech HTTP API（JSON + Base64 音频）  

## 许可证

若仓库未包含许可证文件，以项目所有者后续补充为准。
