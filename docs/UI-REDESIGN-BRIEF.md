# UI Redesign Brief — RenderPause Pro

**Status:** Awaiting user confirmation before implementation  
**Scope:** UI only · features unchanged  
**Direction (confirmed):** Single-page preferences · calm system · spacious · premium native

---

## 1. Goals

- Feel like a **macOS system utility** (Settings / Battery), not a third-party dashboard.
- One preferences window, **grouped**, **breathing room**, clear hierarchy.
- Menu bar stays the daily surface; preferences for setup.

## 2. Non-goals

- No sidebar / tabs / multi-window settings app  
- No GPU charts, big savings numbers, dark “ops console”  
- No engine behavior changes  

## 3. Information architecture

```text
菜单栏
  状态摘要
  监控开/关 · 恢复全部
  （可选）前几条应用快览 / 管理应用…
  偏好设置… · 退出

偏好设置（单页）
  [状态] 监控 · 今日次数
  [通用] 后台秒数 · 登录启动
  [权限] 辅助功能
  [应用名单] 主列表 ← 视觉重心
  [最近活动] 次要、限高日志

引导（首次）
  短说明 · 开始使用 · 可选添加/授权
```

## 4. Preferences layout (wire)

```text
┌─────────────────────────────────────────────┐
│  RenderPause Pro                    ● ● ●   │
│                                             │
│  状态                                       │
│  ┌───────────────────────────────────────┐  │
│  │  启用监控                         [✓] │  │
│  │  今日已优化 3 次 · 后台 30 秒       │  │
│  └───────────────────────────────────────┘  │
│                                             │
│  通用                                       │
│  ┌───────────────────────────────────────┐  │
│  │  后台满          [ 30 ] 秒  (−)(+)    │  │
│  │  登录时启动                       [✓] │  │
│  └───────────────────────────────────────┘  │
│                                             │
│  权限                                       │
│  ┌───────────────────────────────────────┐  │
│  │  辅助功能    已授权 / 未授权          │  │
│  │              [ 打开系统设置… ]        │  │
│  └───────────────────────────────────────┘  │
│                                             │
│  应用名单                    [+] [−]        │
│  ┌───────────────────────────────────────┐  │
│  │ 🖥 Pencil          隐藏        启用  │  │
│  │ 📄 腾讯文档        隐藏        启用  │  │
│  │     （空状态：添加要优化的应用）      │  │
│  └───────────────────────────────────────┘  │
│                                             │
│  最近活动                                   │
│  ┌───────────────────────────────────────┐  │
│  │ 14:02  Pencil  已优化  background+30s │  │
│  │ …（约 6–8 行高度，可滚动）            │  │
│  └───────────────────────────────────────┘  │
│                                             │
└─────────────────────────────────────────────┘
```

## 5. Component mapping (implementation)

| Area | Approach |
|------|----------|
| Prefs shell | `NSWindow` + **SwiftUI `Form`/`Section`** in `NSHostingController` (best Settings match on Tahoe) **or** AppKit `NSBox`/stack if we stay pure AppKit |
| Monitoring / login | `Toggle` |
| Background seconds | `Stepper` + field, clamp 5…600 |
| Rules | `List`/`NSTableView` with icon, name, strategy menu, enable toggle |
| Log | Compact list, secondary labels, max height ~160 |
| Onboarding | SwiftUI sheet or refined AppKit stack with same spacing language |
| Menu | `NSMenu` structure cleanup; SF Symbols where useful |

**Recommendation:** Preferences + Onboarding → **SwiftUI Form** hosted in AppKit (native grouping on macOS 26 with least custom drawing). Menu bar stays AppKit `NSMenu`.

## 6. Copy (ZH)

- 启用监控  
- 后台满 N 秒后优化  
- 登录时启动  
- 辅助功能：已授权 / 未授权（最小化需要）  
- 应用名单 / 添加… / 移除  
- 策略：隐藏 | 最小化  
- 最近活动  
- 空状态：还没有应用。添加需要在后台自动隐藏或最小化的应用。  

## 7. Acceptance checklist

- [ ] Single prefs page, no tabs/sidebar  
- [ ] Clear section grouping + ≥20pt gaps  
- [ ] Rules list is visual focus; log is secondary  
- [ ] Follows light/dark  
- [ ] All existing settings still work  
- [ ] Optimize engine unchanged (manual smoke)  

## 8. Out of scope this pass

- Redesign app icon  
- Marketing site  
- New features (exemptions, lock, GPU UI)  
