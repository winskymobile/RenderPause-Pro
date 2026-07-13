# RenderPause Pro

macOS 菜单栏工具：对用户**主动加入名单**的应用，在非前台且系统空闲达到阈值后自动 **隐藏（默认）** 或 **最小化**，降低 WindowServer 为可见但无用窗口持续合成的开销。

> MVP（Phase 1）· macOS 26+ · Apple Silicon (arm64) · 非 Mac App Store

## 功能（MVP）

- Opt-in 应用名单（默认空）
- 策略：Hide / Minimize（Minimize 需辅助功能）
- 切回前台立即恢复；退出时恢复全部
- 临时豁免、锁定、监控总开关、操作日志
- 登录启动（可选）

**不做**：SIGSTOP 挂起进程、per-app GPU 仪表盘、遮挡检测（后续阶段）

## 构建

```bash
# 需要 Xcode 26+
cd "…/RenderPause Pro"
xcodegen generate   # 若已安装 xcodegen
open RenderPausePro.xcodeproj
# 或
xcodebuild -scheme RenderPausePro -destination 'platform=macOS' build
xcodebuild -scheme RenderPausePro -destination 'platform=macOS' test
```

## 使用

1. 运行 App（菜单栏出现暂停图标，无 Dock 图标）
2. 完成引导或打开「偏好设置」
3. 「添加运行中应用…」加入 Pencil / Discord 等
4. 默认 30 秒空闲后隐藏；Cmd+Tab 切回即恢复
5. 若使用「最小化」策略，请授予**辅助功能**权限

## 文档

- [PRD.md](PRD.md)
- [docs/MVP-Architecture.md](docs/MVP-Architecture.md)
- OpenSpec 变更：`openspec/changes/mvp-window-optimizer/`
- 手工验收：[docs/manual-test-checklist.md](docs/manual-test-checklist.md)

## 权限说明

| 能力 | 权限 |
|------|------|
| 隐藏 Hide | 无需辅助功能 |
| 最小化 Minimize | 系统设置 → 隐私与安全性 → 辅助功能 |
| 空闲检测 | 系统 API，无需「输入监控」 |

## 许可

私有项目 · Copyright © 2026
