# Design System — RenderPause Pro

> Native macOS product UI. Visual language: System Settings / Battery-like calm.

## Visual Theme

**Style:** Quiet system utility  
**Tone:** Neutral, spacious, hierarchical  
**Density:** Comfortable (not dashboard-dense; not sparse to the point of empty)  
**Theme:** Follow system light/dark (`NSAppearance`)

Scene sentence: *A focused creator glances at a menu-bar preference window under soft office light, wants clarity in three seconds, then closes it.*

Color strategy: **Restrained** — system materials + one system accent only for primary actions / toggles.

## Color

Use AppKit semantic colors only (no custom brand palette):

| Role | AppKit |
|------|--------|
| Window / page bg | `windowBackgroundColor` / content under `NSVisualEffectView` optional |
| Grouped surface | `controlBackgroundColor` / standard Form inset group (Tahoe/macOS 26) |
| Primary text | `labelColor` |
| Secondary text | `secondaryLabelColor` |
| Tertiary / hints | `tertiaryLabelColor` |
| Separators | `separatorColor` |
| Primary action | system accent (`.accent` / default push button) |
| Destructive | system red only if ever needed (not in MVP prefs) |
| Success / status | SF Symbol + secondary label; avoid green blocks |

No custom OKLCH brand ramp required for this surface; identity = system fidelity.

## Typography

- Family: **SF Pro** via system fonts only  
- Title (window / section): `NSFont.preferredFont(forTextStyle: .headline)` or `.title3` sparingly  
- Body / controls: `.body` / system 13pt  
- Captions / footnotes under groups: `.caption1` + `secondaryLabelColor`  
- Monospaced digits: for seconds / counts only (`monospacedDigitSystemFont`)  
- Scale ratio tight; no display fonts

## Layout

### Preferences window (single page)

- Size: ~ **520×640** (resizable min ~480×560); not a wide 760 dashboard  
- Structure: **vertical stack of grouped sections** with generous outer margin **20–24pt**, section spacing **20–24pt**  
- No sidebar, no tab bar, no dual tables fighting for height  

**Section order (top → bottom):**

1. **状态** — 监控开关；一行次要状态（今日优化次数 · 后台阈值摘要）  
2. **通用** — 后台秒数（步进器或带单位字段）；登录时启动  
3. **权限** — 辅助功能状态 +「打开系统设置…」  
4. **应用名单** — 主列表（应用图标+名称+策略）；工具栏：添加 / 移除；行内或菜单切换策略与启用  
5. **最近活动** — 紧凑日志列表（时间 · 应用 · 事件），固定最大高度，可滚动  

### Menu bar

- Template SF Symbol status item  
- Short status header (disabled item)  
- Primary actions: 暂停/恢复监控、立即恢复全部  
- Compact rule list or deep-link「管理应用…」→ 打开偏好并聚焦名单  
- 偏好设置…、退出  

### Onboarding

- Compact sheet (~440×380)  
- Title + 3 条短说明 + 主按钮「开始使用」  
- 次要：添加应用、辅助功能（链接样式按钮）  
- Large padding, no checklist chrome overload  

## Components

- Prefer **SwiftUI `Form` + `Section`** hosted in `NSHostingController` **or** AppKit equivalents that match Tahoe Settings grouping  
- Toggles for boolean settings  
- Stepper / `TextField` + unit label for seconds (5–600)  
- List rows with app icon (`NSWorkspace` icon), title, subtitle optional (bundle id secondary)  
- Segmented or menu for 隐藏 | 最小化  
- Standard push buttons; primary = default  
- Empty state for rules: short sentence +「添加应用…」centered in list area  

### States

Every control: default / hover (system) / focus / disabled  
List: empty / 1–N rows / many rows (scroll)  
Permission: authorized / not authorized (secondary text + button)

## Spacing scale

4 / 8 / 12 / 16 / 20 / 24 / 32  
Section internal: 8–12  
Between sections: 20–24  
Window edge: 20–24  

## Motion

- System only; 150–250ms if any custom  
- No celebratory animations on optimize count  

## Do / Don't

**Do:** group boxes / Form sections, secondary captions under sections, one primary focus (应用名单)  
**Don't:** two equal-height competing tables; horizontal button soup; emoji status glyphs if SF Symbols suffice; marketing metrics panels  

## Implementation note

UI-only refactor; PolicyEngine / sensors / actuators behavior unchanged.
