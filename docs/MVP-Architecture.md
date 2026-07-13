# RenderPause Pro — MVP 技术架构与关键 API 清单

> 对应 PRD v0.2 · Phase 1 可直接开工  
> 语言：Swift 5.9+ · 框架：AppKit · 目标：arm64 macOS 26+

---

## 1. 总体架构

```text
┌─────────────────────────────────────────────────────────────┐
│                     Menu Bar App (LSUIElement)               │
│  StatusItem UI · Preferences · Onboarding · Log Viewer      │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                      PolicyEngine                            │
│  rules[bundleID] → thresholds, action, exemptions            │
│  evaluate(snapshot) → [Command]                              │
└───────┬─────────────────────────────┬───────────────────────┘
        │                             │
┌───────▼──────────┐         ┌────────▼──────────┐
│  StateSensors    │         │  Actuators         │
│  WorkspaceFocus  │         │  HideActuator      │
│  IdleTime        │         │  MinimizeActuator  │
│  RunningApps     │         │  RestoreActuator   │
│  (P2: WindowGeom)│         │  (P3: SuspendAct.) │
└───────┬──────────┘         └────────┬──────────┘
        │                             │
┌───────▼─────────────────────────────▼───────────────────────┐
│  AppSessionStore (in-memory + UserDefaults/JSON)             │
│  per-bundle state machine · last action · exemption until    │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│  SafetyGuard · PermissionGate · ActionLog · LaunchAtLogin    │
└─────────────────────────────────────────────────────────────┘
```

### 设计原则

1. **事件驱动为主，轮询为辅**  
2. **Opt-in 名单**，默认不碰未配置 App  
3. **恢复优先于优化**（任何激活信号立即 restore）  
4. **动作幂等**（重复 hide 安全）  
5. **不注入、不读目标进程内存**

---

## 2. 模块职责

| 模块 | 职责 | Phase |
|------|------|-------|
| `AppDelegate` / `MenuBarController` | 菜单栏、快捷操作 | 1 |
| `PermissionGate` | 检测/引导 Accessibility | 1 |
| `RuleStore` | Bundle 规则 CRUD、持久化 | 1 |
| `WorkspaceSensor` | 前后台、hide/unhide 通知 | 1 |
| `IdleSensor` | 系统空闲秒数 | 1 |
| `PolicyEngine` | 状态机求值、防抖 | 1 |
| `HideActuator` | `NSRunningApplication.hide/unhide` | 1 |
| `MinimizeActuator` | AX minimize / raise | 1 |
| `ActionLog` | 本地环形日志 | 1 |
| `WindowGeometrySensor` | CGWindowList 遮挡近似 | 2 |
| `SuspendActuator` | SIGSTOP/CONT + PID 持久化 | 3 |

---

## 3. 单 App 状态机

```text
                    add to rules
                         │
                         ▼
                    ┌─────────┐
         ┌─────────►│ Watched │◄────────────┐
         │          └────┬────┘             │
         │               │ inactive +       │ activated /
         │               │ idle ≥ N         │ unhide / manual
         │               ▼                  │
         │          ┌─────────┐             │
         │          │ Pending │──cancel─────┤
         │          └────┬────┘             │
         │               │ commit action    │
         │               ▼                  │
         │          ┌─────────┐             │
         └──────────┤Optimized│─────────────┘
                    └─────────┘
                         │
                    exemption / rule off
                         │
                         ▼
                    ┌─────────┐
                    │Paused   │  (rule disabled or temp exempt)
                    └─────────┘
```

### 状态定义

```swift
enum WatchState: String, Codable {
    case watched      // 在名单中，前台或未达阈值
    case pending      // 已满足条件，倒计时/待执行（可选预告）
    case optimized    // 已 hide 或 minimize
    case paused       // 豁免或规则关闭
}
```

### 转换规则（Phase 1）

| 当前 | 条件 | 下一状态 | 动作 |
|------|------|----------|------|
| watched | 非前台且 idle≥N 且未豁免 | pending → optimized | Hide 或 Minimize |
| pending | 变为前台 / 用户输入打断 | watched | 取消 |
| optimized | 目标 App 激活 | watched | Unhide / Deminiaturize |
| * | 临时豁免 | paused | 若已 optimized 则先恢复 |
| paused | 豁免到期且规则仍开 | watched | 无 |

**滞后（hysteresis）**：进入 optimized 需连续满足条件；离开 optimized 立即执行。

---

## 4. 关键 API 调用清单

### 4.1 应用与焦点

```swift
import AppKit

let ws = NSWorkspace.shared

// 当前前台
let front = ws.frontmostApplication // bundleIdentifier, processIdentifier

// 运行中应用
let apps = ws.runningApplications
// app.bundleIdentifier, .processIdentifier, .isActive, .isHidden, .activationPolicy

// 通知
let nc = ws.notificationCenter
nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, ...)
nc.addObserver(forName: NSWorkspace.didDeactivateApplicationNotification, ...)
nc.addObserver(forName: NSWorkspace.didHideApplicationNotification, ...)
nc.addObserver(forName: NSWorkspace.didUnhideApplicationNotification, ...)
nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, ...)
nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, ...)
// Phase 2:
nc.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, ...)
```

### 4.2 Hide / Unhide（主策略，尽量不依赖 AX）

```swift
guard let app = NSRunningApplication.runningApplications(
    withBundleIdentifier: bundleID
).first else { return }

// 优化
let ok = app.hide()

// 恢复
let ok2 = app.unhide()
// 若需置前：
app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
```

说明：

- `hide()` 对 `activationPolicy == .regular` 的 GUI App 有效。
- 对 agent/UIElement 类应用通常无窗口可 hide，规则 UI 应过滤。

### 4.3 系统空闲时间（无需 Input Monitoring）

```swift
import CoreGraphics

func secondsSinceLastInput() -> CFTimeInterval {
    CGEventSourceSecondsSinceLastEventType(
        .combinedSessionState,
        CGEventType(rawValue: ~0)! // 或分别查询 key/mouse 取 min
    )
}
```

备选（IOKit HIDIdleTime）：

```swift
// IOService matching "IOHIDSystem" → property "HIDIdleTime" (nanoseconds)
```

MVP 推荐 `CGEventSourceSecondsSinceLastEventType`。

### 4.4 Accessibility：权限与最小化

```swift
import ApplicationServices

// 权限检查 / 弹系统提示
let trusted = AXIsProcessTrusted()
let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
let trustedPrompt = AXIsProcessTrustedWithOptions(opts as CFDictionary)

// 打开设置（macOS 13+ 常用 URL，Tahoe 需再核验）
// x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility
// 或 SMAppService / 新 Settings deep link（实现时以系统版本分支）
```

最小化目标窗口：

```swift
let appElement = AXUIElementCreateApplication(pid)

var windowsRef: CFTypeRef?
AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
let windows = windowsRef as? [AXUIElement] ?? []

for window in windows {
    // 可选：跳过已最小化
    var miniaturized: CFTypeRef?
    AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &miniaturized)
    if let num = miniaturized as? NSNumber, num.boolValue { continue }

    AXUIElementPerformAction(window, kAXMinimizeAction as CFString)
}

// 恢复：kAXRaiseAction 或设置 kAXMinimizedAttribute = false
var falseVal = kCFBooleanFalse
AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, falseVal!)
```

主窗口快捷路径：

```swift
var mainWindow: CFTypeRef?
AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &mainWindow)
```

### 4.5 Phase 2：窗口几何与近似遮挡

```swift
import CoreGraphics

let info = CGWindowListCopyWindowInfo(
    [.optionOnScreenOnly, .excludeDesktopElements],
    kCGNullWindowID
) as? [[String: Any]] ?? []

// 常用键：
// kCGWindowOwnerPID
// kCGWindowOwnerName
// kCGWindowBounds (CGRect dict)
// kCGWindowLayer
// kCGWindowAlpha
// kCGWindowIsOnscreen
// kCGWindowNumber
```

近似算法（务实版）：

1. 按 layer 从高到低排序 on-screen 窗口  
2. 对目标窗口矩形，用更高 layer 的不透明窗口做区域覆盖累计  
3. 覆盖面积 ≥ 阈值（如 95%）→ 视为「近似完全遮挡」  
4. 失败时降级：仅用「非前台 + 空闲」

**不要**声称这是系统级 Occlusion API。

### 4.6 Phase 3：进程挂起（可选高级）

```swift
import Darwin

// 挂起
kill(pid, SIGSTOP)

// 恢复
kill(pid, SIGCONT)
```

硬性配套：

```text
~/Library/Application Support/RenderPausePro/suspended.json
[
  { "pid": 1234, "bundleID": "…", "suspendedAt": "ISO8601" }
]
```

- 启动时：对仍存在且记录在案的 pid 发 `SIGCONT`，再清记录  
- 退出时：批量 `SIGCONT`  
- 对 `pid == 0/1`、自身、系统路径下进程拒绝操作  
- UI 二次确认 + 每次启用写审计日志

**不需要关闭 SIP。** App Store 沙盒下此路不通 → 坚持 Developer ID 分发。

### 4.7 登录启动 / 菜单栏形态

```swift
// Menu bar only
// Info.plist: LSUIElement = YES  （无 Dock 图标，仅菜单栏）

// 登录项（现代）：ServiceManagement.SMAppService.mainApp
import ServiceManagement
try SMAppService.mainApp.register()
try SMAppService.mainApp.unregister()
```

### 4.8 持久化

```swift
// Rules
struct AppRule: Codable, Identifiable {
    var id: String { bundleID }
    var bundleID: String
    var displayName: String
    var enabled: Bool
    var action: OptimizeAction // hide | minimize
    var idleSeconds: TimeInterval
    var locked: Bool          // 永久不优化
}

enum OptimizeAction: String, Codable {
    case hide
    case minimize
}
```

存储：`UserDefaults` 或 Application Support JSON。规则变更立即生效。

### 4.9 不在 MVP 使用的 API（避免踩坑）

| API / 思路 | 原因 |
|------------|------|
| `powermetrics` 常驻解析 | 通常需 root，不适合 GUI 常驻 |
| 私有 WindowServer / CA 接口 | 拒审风险与系统不稳定 |
| 全局 Event Tap 做空闲 | 多余，且可能触发 Input Monitoring |
| 对第三方 `NSWindow.occlusionState` | 只能读自己的窗口 |
| `arm64e` 用户态目标 | 普通 App 用 **arm64** |

---

## 5. PolicyEngine 伪代码

```swift
func tick(now: Date) {
    let frontID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    let idle = secondsSinceLastInput()

    for rule in ruleStore.enabledRules() {
        guard let app = runningApp(bundleID: rule.bundleID) else {
            session.clear(rule.bundleID); continue
        }
        if rule.locked || exemption.isActive(rule.bundleID) {
            session.set(rule.bundleID, .paused)
            continue
        }

        // 恢复优先
        if app.isActive || frontID == rule.bundleID {
            if session.state(rule.bundleID) == .optimized {
                actuators.restore(app, action: rule.action)
                log.restore(rule, reason: "activated")
            }
            session.set(rule.bundleID, .watched)
            continue
        }

        // 尝试优化
        switch session.state(rule.bundleID) {
        case .watched, .pending:
            if !app.isActive && idle >= rule.idleSeconds {
                actuators.optimize(app, action: rule.action)
                session.set(rule.bundleID, .optimized)
                log.optimize(rule, reason: "inactive+idle")
            }
        case .optimized:
            break // 已优化，等待激活
        case .paused:
            break
        }
    }
}
```

调度建议：

- Workspace 通知到达时立即 `tick`  
- 另起 `Timer` 每 1.0s 检查 idle 阈值（仅当存在 watched 非前台规则时运行，省电）

---

## 6. 权限与分发清单

### Info.plist / 工程设置（要点）

```text
LSUIElement = YES
LSMinimumSystemVersion = 26.0
ARCHITECTURES = arm64
CODE_SIGN_IDENTITY = Developer ID Application
Enable Hardened Runtime = YES
（不要开 App Sandbox）
```

Hardened Runtime 异常（按需）：

- 若未来用 Apple Events：`com.apple.security.automation.apple-events`
- 一般 Hide/AX **不靠** 自动化权限即可完成主路径

### 公证

```bash
xcodebuild ...
productsign / notarytool submit / stapler staple
```

### 辅助功能信任

- 公证后的 App 路径固定（不要每次从 Downloads 不同路径跑出多重条目）
- 引导文案写清：系统设置 → 隐私与安全性 → 辅助功能 → 勾选 RenderPause Pro

---

## 7. 工程目录建议

```text
RenderPause Pro/
  PRD.md
  docs/
    MVP-Architecture.md
  RenderPausePro/
    App/
      AppDelegate.swift
      MenuBarController.swift
      PreferencesViewController.swift
      OnboardingViewController.swift
    Sensors/
      WorkspaceSensor.swift
      IdleSensor.swift
    Engine/
      PolicyEngine.swift
      AppSessionStore.swift
      RuleStore.swift
      SafetyGuard.swift
    Actuators/
      HideActuator.swift
      MinimizeActuator.swift
      RestoreCoordinator.swift
    Support/
      PermissionGate.swift
      ActionLog.swift
      DeepLinks.swift
    Resources/
      Info.plist
      Assets.xcassets
```

---

## 8. Phase 0 验证脚本（建议先跑）

用 Swift 或 `osascript` + Activity Monitor 人工观察：

1. 打开 Pencil（或目标 App），放一边保持可见  
2. 记录 Activity Monitor 中 WindowServer / GPU 观感  
3. 对该 App `hide` → 观察变化  
4. `unhide` → 恢复  
5. 再试 AX minimize vs hide，选默认策略  

验收问题：

- Hide 是否已足够？（足够则 MVP 甚至可先不做 Minimize）  
- 恢复是否丢窗口布局？  
- 多屏下是否误伤？

---

## 9. 测试用例（Phase 1 必过）

1. 名单外 App 永远不操作  
2. 名单内 App 前台时不操作  
3. 切走并空闲 N 秒后执行 Hide  
4. Dock 点击立即出现  
5. Cmd+Tab 切回立即恢复  
6. 关闭 Accessibility 时 Minimize 策略降级提示，Hide 仍可用  
7. 退出 RenderPause Pro 时恢复本次 optimized 集合  
8. 目标 App 中途退出无崩溃、无残留状态  
9. 连续抖动切 App 不产生动作风暴（恢复优先 + 节流）  
10. 自身 CPU 在空闲系统上接近 0

---

## 10. 风险登记（工程）

| 风险 | 影响 | 缓解 |
|------|------|------|
| AX API 在部分 Electron App 上窗口树异常 | Minimize 失败 | Hide 作默认与回退 |
| 用户从不同路径启动导致辅助功能条目分裂 | 授权混乱 | 固定安装到 `/Applications` |
| 过度优化引发投诉 | 卸载 | Opt-in、豁免、清晰日志 |
| Tahoe API/设置 URL 变更 | 引导失效 | 版本分支 + 文案兜底「手动打开设置」 |
| 未来误开 SIGSTOP 无恢复 | 数据/体验事故 | 默认关、持久化、启动扫描 |

---

## 11. 建议的第一周实现顺序

1. 空菜单栏 App + `LSUIElement`  
2. `RuleStore` + 从运行中 App 添加  
3. `WorkspaceSensor` + `IdleSensor`  
4. `HideActuator` + 状态机  
5. 恢复路径（activate 通知）  
6. 日志 + 豁免  
7. Accessibility 引导 + `MinimizeActuator`  
8. 启动/退出清理  
9. 公证与安装体验

---

## 12. 一页 API 速查

| 目的 | API |
|------|-----|
| 前台变化 | `NSWorkspace.didActivateApplicationNotification` |
| 隐藏应用 | `NSRunningApplication.hide()` |
| 取消隐藏 | `NSRunningApplication.unhide()` / `activate` |
| 空闲时间 | `CGEventSourceSecondsSinceLastEventType` |
| AX 权限 | `AXIsProcessTrusted` / `WithOptions` |
| 最小化窗口 | `AXUIElementPerformAction(kAXMinimizeAction)` |
| 枚举窗口 | `kAXWindowsAttribute` / `CGWindowListCopyWindowInfo` |
| Space 变化 | `NSWorkspace.activeSpaceDidChangeNotification` |
| 挂起进程 | `kill(pid, SIGSTOP/SIGCONT)`（Phase 3） |
| 登录项 | `SMAppService.mainApp` |

---

**结论**：Phase 1 只需 AppKit +（可选）ApplicationServices + CoreGraphics 空闲 API，即可交付可验证的核心价值。先把 Hide 路径做稳，再扩展 Minimize 与智能可见性。
