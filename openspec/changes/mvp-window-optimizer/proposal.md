## Why

Electron / Skia / custom Metal apps (e.g. Pencil, Discord) often keep feeding WindowServer composition while visible but unused, causing heat, fan noise, and battery drain on Apple Silicon Macs. Users already know manual Hide/Minimize helps; RenderPause Pro turns that into a safe, opt-in, auto-restore menu bar service for macOS Tahoe 26+.

## What Changes

- Introduce a **menu bar (LSUIElement)** macOS app: RenderPause Pro MVP.
- **Opt-in rule list** by Bundle ID (default empty): enable, action (Hide default / Minimize), idle seconds (5–600, default 30), permanent lock.
- **Sensors**: NSWorkspace focus/hide notifications + system input idle time (no Input Monitoring).
- **Policy engine**: restore-first state machine; optimize only when inactive + idle threshold + monitoring on + not exempt/locked.
- **Actuators**: `NSRunningApplication.hide/unhide`; Accessibility minimize/deminiaturize when trusted.
- **Safety**: temporary exemptions, restore all on quit, action log, Accessibility guidance, optional launch-at-login.
- **Non-goals for this change**: SIGSTOP, per-app GPU metrics, occlusion/Spaces intelligence, private WindowServer APIs, App Sandbox / Mac App Store build.

## Capabilities

### New Capabilities

- `rule-management`: Opt-in watched-app rules, persistence, enable/disable, lock, picker constraints.
- `idle-optimization`: Detect inactivity/idle and apply Hide or Minimize under policy constraints.
- `restore-and-safety`: Immediate restore on activation, manual restore, quit cleanup, exemptions, monitoring kill-switch.
- `menu-bar-shell`: Status item UI, preferences, onboarding, permissions, launch-at-login, local action log.

### Modified Capabilities

- None (greenfield; `openspec/specs/` has no baseline specs yet).

## Impact

- **Code**: new Xcode macOS app target + unit tests (no existing app code).
- **APIs**: AppKit `NSWorkspace` / `NSRunningApplication`, CoreGraphics idle timing, ApplicationServices AX (minimize path), ServiceManagement login item.
- **Permissions**: Accessibility required only for Minimize; Hide works without it.
- **UX risk**: over-aggressive hide/minimize; mitigated by opt-in defaults and restore-first design.
- **Docs**: implements `PRD.md` Phase 1 and `docs/MVP-Architecture.md`.
- **Implementation aids**: may use **superpowers** (TDD / plan execution / verification) and **impeccable** (UI polish) during apply.
