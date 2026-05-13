# 技术规范

## 1. 技术栈

| 层级 | 技术 |
|------|------|
| 语言 | Swift 5.9 |
| UI 框架 | SwiftUI |
| 数据持久化 | SwiftData（SQLite） |
| 全局快捷键 | Carbon `RegisterEventHotKey` |
| 剪贴板访问 | `NSPasteboard` |
| 菜单栏 | `NSStatusBar` |
| 应用入口 | SwiftUI `@main` + `NSApplicationDelegate` |

## 2. 最低系统要求

- macOS 26.0 (Tahoe)
- Apple Silicon / Intel 通用

## 3. 项目架构

```
App/                # 应用入口
  HistoryCopyApp    # @main + AppDelegate
Model/              # 数据模型
  ClipboardItem     # SwiftData @Model
Services/           # 业务服务
  ClipboardMonitor  # 剪贴板轮询
  HotkeyManager     # 全局快捷键
  StorageManager    # 数据 CRUD
Views/              # UI 视图
  HistoryPanelView  # 主面板
  ClipboardCardView # 卡片组件
  SearchBar         # 搜索栏
  SettingsView      # 设置窗口
  EmptyStateView    # 空状态
Utilities/          # 工具扩展
  DateFormatter     # 相对时间
```

## 4. 数据模型

```
ClipboardItem
  ├── id: UUID
  ├── contentType: Int (0: text, 1: image)
  ├── textContent: String?
  ├── imageFileName: String?
  ├── timestamp: Date
  ├── isPinned: Bool
  └── sourceAppBundleId: String?

图片存储：~/Library/Application Support/HistoryCopy/Images/{UUID}.png
```

## 5. 剪贴板监听

- 轮询间隔：0.5s
- 检测方式：`NSPasteboard.general.changeCount`
- 内容类型：`NSPasteboard.PasteboardType.string` / `NSImage`
- 去重：最新一条文字内容相同则仅更新时间戳
- 上限：1000 条，超出删除最旧非置顶条目

## 6. 快捷键

- 框架：Carbon `RegisterEventHotKey`
- 默认键位：`Cmd + Option + V`（keyCode=9, modifiers=cmdKey|optionKey）
- 存储：UserDefaults（hotkeyKeyCode, hotkeyModifiers）
- 冲突检测：尝试注册临时热键，失败则被占用

## 7. 用户设置（UserDefaults）

| Key | 类型 | 默认值 | 说明 |
|-----|------|--------|------|
| retentionDays | Int | 3 | 保留天数，0=永不 |
| maxItemCount | Int | 1000 | 最大条数 |
| hotkeyKeyCode | Int | 9 | 快捷键键码 |
| hotkeyModifiers | Int | cmd\|option | 快捷键修饰键 |

## 8. 窗口管理

- 主面板：`NSPanel` + `.nonactivatingPanel`（不抢焦点）
- 窗口层级：`.floating`
- 显示：`makeKeyAndOrderFront`，配合 `didResignKeyNotification` 关闭
- 设置窗口：独立 NSPanel，可同时存在多窗口

## 9. 不使用的方案

- 不使用第三方依赖（纯系统框架实现）
- 不使用 iCloud / 网络同步（仅本地）
- 不使用 OCR 图片文字识别
- 不接入 Accessibility API（全局事件监听）
