## Why

Users still see opted-in apps hide while partially visible (background but not fully covered). Relying only on “left frontmost for N seconds” is too aggressive for stacked windows, multi-monitor layouts, and non–Split View side-by-side. We need Scheme A: **never hide/minimize while any significant window remains partially visible**.

## What Changes

- Add **window occlusion sensing** via public `CGWindowList` geometry (no private APIs, no injection).
- Treat an app as eligible for optimize **only when fully occluded** (no significant on-screen residual visible area), in addition to existing non-frontmost + background-seconds threshold rules.
- Count `secondsSinceDeactivated` only while the app remains fully occluded (or not on screen); partial visibility resets/pauses the timer and blocks optimize.
- Keep existing Split View partner protection; occlusion is a superset safety layer for ordinary stacking.
- Unit-test pure geometry occlusion helpers; wire into `WorkspaceSensor` / hard protect path without changing actuators.

## Capabilities

### New Capabilities

- `window-occlusion-guard`: Detect whether watched apps are fully occluded vs partially visible; gate optimize eligibility and background timer.

### Modified Capabilities

- `idle-optimization`: Optimize conditions now require full occlusion (or no on-screen windows), not merely non-frontmost + elapsed background seconds.
- `restore-and-safety`: Hard protect path includes partial visibility (same class of “must not optimize” as frontmost / Split View partner).

## Impact

- **Code**: new `OcclusionDetector` (or geometry helper next to `SplitViewDetector`), `RunningAppSnapshot` fields, `WorkspaceSensor` timer semantics, `isProtectedFromOptimize`.
- **APIs**: CoreGraphics `CGWindowListCopyWindowInfo` (already used for Split View).
- **Perf**: reuse one window-list sample per tick; keep ~1s evaluation cadence.
- **UX**: fewer false hides when an app is still visible behind/beside the front app; may delay optimize until fully covered.
- **Skills**: superpowers (TDD/verify) during apply; impeccable only if prefs copy needs a short hint (optional).
