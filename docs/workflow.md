# 开发流程

## 1. 开发环境

- macOS + Xcode（从 App Store 安装）
- `xcodegen`（从 Homebrew 安装：`brew install xcodegen`）
- 打开项目：双击 `HistoryCopy.xcodeproj`，`Cmd+R` 运行

## 2. 开发步骤

### Phase 1 — 基础框架
- [x] 项目结构搭建
- [x] 数据模型定义
- [x] 剪贴板监听
- [x] 菜单栏图标

### Phase 2 — UI 面板
- [x] 主面板布局
- [x] 卡片列表
- [x] 玻璃质感背景
- [x] 空状态页面

### Phase 3 — 交互功能
- [x] 搜索过滤
- [x] 置顶 / 删除
- [x] 再复制到剪贴板
- [x] 全局快捷键

### Phase 4 — 设置与优化
- [x] 设置窗口
- [x] 保留时长配置
- [x] 快捷键自定义 + 冲突检测
- [x] 开机自启
- [x] 过期自动清理

### Phase 5 — 测试与发布
- [ ] 本地编译运行测试
- [ ] 功能完整性验证
- [ ] 性能测试
- [ ] 打包 DMG
- [ ] 发布

## 3. 重新生成 Xcode 项目

修改文件结构后重新生成：

```bash
xcodegen generate --spec project.yml
```

## 4. 构建命令

```bash
# Debug 构建
xcodebuild -project HistoryCopy.xcodeproj -scheme HistoryCopy -configuration Debug build

# Release 构建
xcodebuild -project HistoryCopy.xcodeproj -scheme HistoryCopy -configuration Release build
```

## 5. 开发日志

每天开发结束后在 `devlog/YYYY-MM-DD.md` 按模板记录：
- 已完成事项
- 待办事项
- 遇到的问题
- 备注

## 6. 规范引用

- 需求文档：`PRD.md`
- 设计规范：`docs/design-spec.md`
- 技术规范：`docs/technical-spec.md`
