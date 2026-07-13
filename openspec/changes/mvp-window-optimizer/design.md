## Context

RenderPause Pro is a greenfield macOS Tahoe 26+ Apple Silicon utility. Source requirements live in `PRD.md` (v0.2) and technical boundaries in `docs/MVP-Architecture.md`. There is no existing application code; this change delivers the Phase 1 MVP only.

Constraints:

- Public APIs only (AppKit, ApplicationServices AX, CoreGraphics idle, ServiceManagement).
- No App Sandbox / not targeting Mac App Store for core features.
- No Metal injection, private WindowServer APIs, or process `SIGSTOP` in MVP.
- Users will grant Accessibility only if they use Minimize.

## Goals / Non-Goals

**Goals:**

- Ship a menu bar agent that auto-Hides (default) or Minimizes opted-in idle background apps.
- Restore immediately on activation, on manual command, and on quit.
- Persist rules/settings/logs locally; keep self overhead tiny (event-driven + ~1s idle timer).
- Unit-test pure policy decisions; manually verify hide/restore on real apps.

**Non-Goals:**

- Occlusion / Spaces intelligence (Phase 2).
- SIGSTOP, GPU/power dashboards, powermetrics (Phase 3).
- Pixel-perfect marketing UI (optional **impeccable** polish after functional MVP).
- Multi-user / managed-device MDM packaging.

## Decisions

### Decision: AppKit menu bar app (LSUIElement), not SwiftUI-only lifecycle

Use `@main` + `NSApplication` accessory policy and `NSStatusItem` for reliability as a background agent. Preferences/onboarding can be AppKit or light SwiftUI hosted in `NSWindow`; default to AppKit for fewer moving parts.

**Alternative:** SwiftUI `MenuBarExtra` — viable on modern macOS, but AppKit status item + explicit engine wiring matches architecture doc and is easier to unit-test around.

### Decision: Layered modules matching architecture doc

```text
MenuBar / Preferences UI
        ↓
   AppController (tick orchestration)
        ↓
 PolicyEngine ← RuleStore / SessionStore / SettingsStore / exemptions
        ↓
 Sensors (Workspace, Idle)    Actuators (Hide, Minimize, Restore)
```

**Rationale:** Keeps policy pure and testable; UI stays thin.

### Decision: Restore-first state machine (`watched` | `optimized` | `paused`)

MVP skips user-visible multi-second “pending” countdown (PRD optional). Idle threshold provides enter hysteresis; restore is immediate.

### Decision: Hide is default; Minimize is opt-in per rule and AX-gated

Hide does not need Accessibility and is the validated low-risk path. Minimize fails closed with log if AX missing—no silent fallback that surprises users who wanted windows minimized not app-hidden.

### Decision: Idle via `CGEventSourceSecondsSinceLastEventType` (multi-type min)

Avoid Input Monitoring and Event Taps. Sample common key/mouse types and take the minimum age.

### Decision: Persistence in `UserDefaults` (Codable JSON blobs)

Simple for MVP rules/settings/log. Can migrate to Application Support files later if log volume grows.

### Decision: Xcode app target + unit test bundle; XcodeGen `project.yml` if available

Automate project generation when `xcodegen` exists; otherwise create/maintain `RenderPausePro.xcodeproj` manually. Module name forced to `RenderPausePro`.

### Decision: Skills usage during apply

| Need | Skill |
|------|--------|
| Execute `tasks.md` task-by-task | **superpowers:executing-plans** or **subagent-driven-development** |
| PolicyEngine / RuleStore | **superpowers:test-driven-development** |
| Hide/AX device failures | **superpowers:systematic-debugging** |
| Before claiming MVP done | **superpowers:verification-before-completion** |
| Preferences / onboarding visual craft | **impeccable** (product/utility register), after core flows work |

## Risks / Trade-offs

- **[Risk] Aggressive hide breaks workflows** → Mitigation: empty default rules, monitoring toggle, exemptions, clear logs.
- **[Risk] Electron AX trees break Minimize** → Mitigation: Hide default; log minimize failures.
- **[Risk] Accessibility entries split by path** → Mitigation: document install to `/Applications`; stable bundle ID.
- **[Risk] Frequent hide/show flicker on Tahoe** → Mitigation: idle threshold; no thrash when already optimized/hidden.
- **[Trade-off] No GPU proof in UI** → Accept qualitative benefit; metrics later.
- **[Trade-off] Non-sandboxed distribution** → Required for future Phase 3 flexibility and simpler AX; notarize later.

## Migration Plan

1. Scaffold Xcode project and menu bar shell.
2. Land stores + PolicyEngine with unit tests.
3. Wire sensors/actuators and AppController tick loop.
4. Ship preferences/onboarding; manual hide/restore checklist.
5. Optional impeccable UI polish.
6. Future: `openspec archive mvp-window-optimizer` after MVP accepted to promote specs into `openspec/specs/`.

Rollback: delete app + its UserDefaults domain; no system modifications beyond optional login item registration (unregister on disable).

## Open Questions

- None blocking MVP. Defaults locked: Hide, restore-on-quit yes, countdown banner no, launch-at-login optional default on after onboarding.
- Signing team ID / notarization credentials deferred until distribution packaging.
