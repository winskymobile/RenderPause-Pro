## Context

RenderPause Pro already optimizes opted-in apps after they leave “effective foreground” for a global background threshold. Effective foreground currently includes system frontmost, regular active, and Split View partners (`SplitViewDetector` via `CGWindowList`).

False positives remain when a watched app is **not frontmost** but **still partially visible** (stacked windows with residual area). Scheme A requires: **if not fully occluded, do not hide/minimize**.

Architecture doc already listed Phase 2 `WindowGeometrySensor`; this change lands that capability as an occlusion guard without process suspension or private APIs.

## Goals / Non-Goals

**Goals:**

- Approximate per-app full occlusion from public CGWindow geometry.
- Only accumulate background seconds while fully occluded (or no significant on-screen windows).
- Hard-block optimize when any significant window remains partially visible.
- Keep restore-first behavior; keep Split View protection; keep Hide/Minimize actuators unchanged.
- Unit-test pure geometry helpers with synthetic rect stacks.

**Non-Goals:**

- Pixel-perfect occlusion (transparency, shadows, rounded corners).
- Per-window hide (still app-level hide/minimize).
- User-facing GPU metrics or occlusion debug UI (optional later).
- SIGSTOP / Metal injection / private WindowServer APIs.
- Preferences toggle for this release (always-on Scheme A; can add later).

## Decisions

### Decision: New pure helper `OcclusionDetector` beside `SplitViewDetector`

Share the same window list sampling approach (`CGWindowListCopyWindowInfo` on-screen, exclude desktop). Split View stays specialized; occlusion answers “any residual visible area?”.

**Alternative:** fold into SplitViewDetector — rejected to keep responsibilities clear.

### Decision: Significant windows only

Consider layer ≤ 0 and size ≥ 200×200 (aligned with Split View significance filter). Ignore menu bar / HUD layers.

### Decision: Full occlusion = residual visible area ≤ 2% of each significant window (AND all windows)

Conservative bias: prefer false “visible” over false “occluded”. Use axis-aligned rectangle subtraction of covering windows in front (list order = front-to-back).

If the app has **no** significant on-screen windows (other Space / fully off-screen / minimized system state still listing none), treat as **fully occluded for eligibility** so background apps on other Spaces can still optimize.

### Decision: Timer semantics live in `WorkspaceSensor`

Extend `deactivatedAt` rules:

1. Front / Split partner → clear timer, treat active.
2. Else if **partially visible** → clear/do not start timer; `secondsSinceDeactivated = 0`; `isActive` for policy may stay false but protection blocks optimize.
3. Else (fully occluded / no windows) → start or continue timer as today.

Expose on snapshot:

- `isPartiallyVisible: Bool` (true → protect)
- Keep `isActive` meaning “effective foreground” (front or split), **not** partial visibility, so PolicyEngine restore still only on real activate.

Hard protect in `AppController` / `isProtectedFromOptimize`:

- frontmost OR active OR split partner OR **partially visible**

### Decision: One window list per tick

`snapshots(for:)` already lists windows once for Split View; reuse that list for occlusion to avoid double CGWindow scans.

### Decision: Skills during apply

| Need | Skill |
|------|--------|
| Geometry unit tests first | superpowers:test-driven-development |
| Task loop | superpowers:executing-plans |
| Green build before done | superpowers:verification-before-completion |
| Prefs copy if needed | impeccable (optional, minimal) |

## Risks / Trade-offs

- **[Risk] Geometry approximation misclassifies translucent covers** → Mitigation: 2% residual threshold; prefer not optimizing.
- **[Risk] Multi-display global coordinates edge cases** → Mitigation: compare rects in CGWindow global space only; do not convert to view coords incorrectly.
- **[Risk] Stage Manager / Spaces churn** → Mitigation: re-sample every tick; Space change already triggers workspace re-eval.
- **[Trade-off] Delayed optimize until fully covered** → Accept as intentional Scheme A safety.
- **[Trade-off] Extra CPU for rect subtraction** → Negligible for small rule sets + 1s tick.

## Migration Plan

1. Land detector + tests.
2. Wire sensor/protection.
3. Build, test, reinstall `/Applications/RenderPausePro.app`.
4. Manual: partially covered watched app must not hide; fully covered + N seconds must hide.

Rollback: revert change; previous frontmost-only timer returns.

## Open Questions

- None blocking. Optional future: prefs toggle “仅完全遮挡后优化” default on.

### Follow-up fix: ignore non-content layers as covers

Live diagnosis showed Dock (`layer` 20) and menu extras (`layer` 24–25) appear *before* app windows in `CGWindowList` with near full-screen bounds. Counting them as covers falsely classified every app as fully occluded. Only `layer <= 0` content windows may cover; residual threshold also uses a min absolute area (2500 pt²) so thin peeks still protect.
