# CLAUDE.md — HistoryCopy 项目

## 项目概述

macOS 历史剪贴板管理工具。菜单栏常驻，自动记录复制内容，支持搜索、置顶、删除、再复制。

## 标准文件路径

| 文件 | 路径 | 说明 |
|------|------|------|
| 需求文档 | [PRD.md](PRD.md) | 产品需求文档 |
| 设计规范 | [docs/design-spec.md](docs/design-spec.md) | UI 设计、交互规范 |
| 技术规范 | [docs/technical-spec.md](docs/technical-spec.md) | 技术栈、架构、代码规范 |
| 开发流程 | [docs/workflow.md](docs/workflow.md) | 开发步骤、Git 规范、发布流程 |
| 开发日志 | [devlog/](devlog/) | 每日开发记录 |

## 工作约定

1. **必须先确认再动手**：收到需求后先讨论确认，等用户明确给出"开始""实现""写代码"等指令后再写代码
2. **修改前先读文件**：修改任何文件前，先 Read 查看当前内容
3. **记录开发日志**：每次开发结束后，在 `devlog/` 下按日期创建日志
4. **遵循设计规范**：UI 和交互严格参照 `docs/design-spec.md`
5. **遵循技术规范**：代码风格和架构参照 `docs/technical-spec.md`
6. **不主动 commit**：只做代码修改，git 操作需用户明确指令

## 技术栈

- Swift 5.9 + SwiftUI
- SwiftData（本地存储）
- Carbon API（全局快捷键）
- macOS 14.0+
