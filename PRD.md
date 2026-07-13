# RenderPause Pro — 修订版 PRD（可执行）

> 版本：v0.2（基于可行性评审修订）  
> 平台：macOS Tahoe 26+ · Apple Silicon（arm64）  
> 分发：官网 Direct Download + Developer ID Notarization（**非 Mac App Store**）

---

## 1. 产品一句话

**RenderPause Pro** 是一款菜单栏工具：在用户明确加入名单的应用变为「非活跃」后，通过系统公开接口自动 **隐藏（Hide）或最小化（Minimize）** 其窗口，降低 WindowServer 为「可见但无用」图层持续合成的开销，从而减少发热与耗电。

它 **不是** 驱动级 GPU 控制器，也 **不能** 拦截第三方 App 的 Metal 渲染循环。

---

## 2. 问题与价值

### 2.1 真实痛点

- Electron / Skia / 自绘 UI（如 Pencil、Discord、部分创意工具）在窗口仍可见但用户已切走时，仍可能持续提交合成负载。
- 成本常汇总到 `WindowServer`，表现为整机发热、风扇噪音、续航下降。
- 用户手工 Cmd+H / 最小化有效，但无法长期坚持。

### 2.2 核心价值主张

> 把「你已经验证有效的最小化/隐藏」变成 **规则化、可恢复、可豁免的无感后台服务**。

### 2.3 非目标（明确不做）

- 注入 / hook 第三方 Metal / Core Animation
- 使用私有合成器 API 强制降帧
- 宣称精确到「每 App GPU 瓦数 / 节省帧数」的营销数字（MVP 不做）
- 默认全局自动「猎杀」所有应用

---

## 3. 目标用户

- Apple Silicon 重度多开用户（创意、开发、协作）
- 常驻 Pencil / Figma / Discord / VS Code / Electron 工具
- 对发热与续航敏感，愿意授予 **辅助功能（Accessibility）** 权限
- 接受官网安装（非 App Store）

---

## 4. 成功标准（MVP）

| 指标 | 目标 |
|------|------|
| 名单内 App 非前台且空闲 N 秒后 | 自动 Hide 或 Minimize 成功率 ≥ 95% |
| 用户切回目标 App | ≤ 300ms 内开始恢复（hide 取消 / unminimize） |
| 工具自身常驻开销 | CPU 均值 < 0.5%，无持续 GPU 占用 |
| 误伤 | 默认不优化未加入名单的 App；媒体/全屏默认豁免 |
| 崩溃安全 | 无「被挂起后永久冻住」路径（MVP 不做 SIGSTOP） |

---

## 5. 功能范围

### 5.1 MVP（Phase 1）— 只做窗口层

#### F1. 应用名单（Opt-in）

- 用户手动添加 Bundle ID / 从运行中 App 选择
- 每条规则可配置：
  - 策略：`Hide`（默认）或 `Minimize`
  - 空闲阈值：默认 30s（可调 5–600s）
  - 启用/禁用
- **安装后默认名单为空**，避免惊吓用户

#### F2. 活跃状态感知

输入信号（事件驱动优先）：

| 信号 | API / 来源 | 用途 |
|------|------------|------|
| 前台 App 变化 | `NSWorkspace.didActivateApplicationNotification` 等 | 进出优化候选 |
| 应用隐藏/取消隐藏 | `didHide` / `didUnhide` | 避免重复动作 |
| 用户空闲秒数 | `CGEventSourceSecondsSinceLastEventType` 或 HIDIdleTime | 空闲阈值 |
| 运行中进程列表 | `NSWorkspace.runningApplications` | 名单匹配 |

**不做（MVP）**：精确第三方 occlusion、精确 Spaces 归属、per-App GPU。

#### F3. 策略执行

- **策略 A — Hide（主推）**  
  `NSRunningApplication.hide()`  
  等价用户 Cmd+H；对「整个应用」干净，常能显著降低合成。

- **策略 B — Minimize（可选）**  
  Accessibility：`AXUIElementPerformAction(..., kAXMinimizeAction)`  
  适合「只收窗口、应用仍当运行」的场景。

执行约束：

- 仅对名单内且当前非前台的 App
- 满足空闲阈值
- 不在豁免状态
- 带滞后：进入优化需等待；恢复立即

#### F4. 恢复路径（必须可靠）

以下任一发生时 **立即恢复**：

- 目标 App 被激活（切到前台）
- 用户点击 Dock 图标
- 菜单栏「立即恢复全部 / 恢复某个」
- 用户关闭本工具前（可选：退出时恢复本次会话优化过的 App）

#### F5. 豁免与安全阀

- **临时豁免**：10 分钟 / 1 小时 / 直到重启
- **永久锁定**：该 App 永不优化
- **内置场景豁免（启发式）**：
  - 当前全屏
  - 正在屏幕录制（若可检测）
  - 常见媒体/会议 Bundle 预设（可关）
- **预告可选**：执行前菜单栏轻提示 N 秒，移动鼠标或切回可取消（默认关，进阶开）

#### F6. 菜单栏 UI（极简）

- 状态：空闲 / 监控中 / 今日优化次数
- 名单快速开关
- 最近操作日志（时间、App、动作、原因）
- 辅助功能权限状态 + 一键打开系统设置
- 偏好设置窗口

#### F7. 权限与引导

- **必需**：Accessibility（最小化；部分窗口查询）
- **非必需**：Input Monitoring（MVP 不用全局键鼠 hook）
- 首次启动：3 步引导（授权 → 添加第一个 App → 选策略）

---

### 5.2 Phase 2 — 智能可见性（仍不碰进程）

- 用 `CGWindowListCopyWindowInfo` 做 **近似遮挡**（矩形覆盖启发式，非系统官方 Occlusion）
- Space 切换通知辅助：非当前桌面的可见窗口更激进
- 多显示器策略：仅主屏 / 任意屏有可见内容则视为需保留
- Stage Manager / 分屏默认保守（降级或豁免）

### 5.3 Phase 3 — 高级与度量（可选）

- **SIGSTOP / SIGCONT**（默认关，二次确认，强免责）
  - 非沙盒；**不需要关 SIP**
  - PID 列表磁盘持久化 + 登录恢复扫描
  - 禁止对浏览器/IDE/AI/会议默认启用
- Before/After 粗指标（执行前后短窗口采样），文案标注「估算」
- 预设包：「Electron 套件」「创意套件」

---

## 6. 明确修正（相对 v0.1）

| v0.1 表述 | v0.2 修正 |
|-----------|-----------|
| AXAPI 读 Occlusion | MVP 不做；Phase 2 用 CGWindowList 启发式 |
| 空闲需输入监听权限 | 优先系统空闲 API，不默认要 Input Monitoring |
| SIGSTOP 需关 SIP | 不需要关 SIP；需非沙盒 + 风险确认 |
| powermetrics 核心面板 | 移出 MVP；后期可选且非精确 |
| 策略 D WK 节流 | 删除/远期，对第三方无效 |
| arm64e | 改为 **arm64** 用户态 |
| 系统级 GPU Saver | 改为 WindowServer / 空闲窗口合成开销控制 |
| 默认广谱优化 | 改为 **Opt-in 名单** |

---

## 7. 非功能需求

- **兼容性**：macOS 26+，Apple Silicon arm64 原生
- **性能**：事件驱动；窗口列表轮询若启用 ≤ 1–2 Hz
- **安全**：不注入第三方、不读目标 App 用户数据
- **稳定性**：状态机 + 动作幂等；重复 hide 无害
- **隐私**：日志仅本地；无强制联网
- **本地化**：先中文 + 英文界面字符串预留

---

## 8. 风险与产品内免责（必须明示）

- 自动隐藏/最小化可能打断「需要窗口保持可见」的工作流
- 部分 App 在隐藏后快捷键/后台行为变化
- Tahoe 合成路径下，频繁 hide/show 可能带来短暂闪烁或缓存重建
- Phase 3 SIGSTOP 可能导致任务中断、未保存状态风险、音频异常——默认关闭

---

## 9. 竞争与差异化

| 类型 | 代表 | 我们的差异 |
|------|------|------------|
| 进程暂停/限速 | App Tamer | 优先窗口层，专打 WindowServer 合成叙事 |
| 窗口摆放 | Rectangle 等 | 目标是节能，不是布局 |
| 手工操作 | Cmd+H | 规则化、可恢复、可审计 |

**一句话差异化**：专治 Tahoe 上「看得见但你已经不用」的窗口空转，而不是粗暴停掉整个进程。

---

## 10. 里程碑

1. **Phase 0（验证）**：脚本对比 Hide vs Minimize 对目标 App + WindowServer 的收益  
2. **Phase 1（MVP）**：名单 + Hide/Minimize + 恢复 + 日志 + 权限引导  
3. **Phase 2**：近似遮挡 / 多屏 / 场景豁免  
4. **Phase 3**：可选 SIGSTOP + 粗指标 + 预设

---

## 11. 开放决策（实现前拍板即可）

1. 默认策略：Hide 还是 Minimize？（建议 **Hide**）  
2. 退出 App 时是否自动恢复本次优化对象？（建议 **是**）  
3. 是否提供「即将优化」倒计时提示？（建议默认关）  
4. 是否做登录启动？（建议可选，默认开）

---

## 12. 文档关系

- 本文件：产品范围与边界  
- 详见：`docs/MVP-Architecture.md`（架构、状态机、关键 API 清单）
