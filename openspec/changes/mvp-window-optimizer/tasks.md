## 1. Project scaffold

- [x] 1.1 Initialize git repo and `.gitignore` (DerivedData, xcuserdata, build, .DS_Store)
- [x] 1.2 Create `RenderPausePro/` source tree folders: `App`, `Models`, `Store`, `Sensors`, `Engine`, `Actuators`, `Support`, `Resources`
- [x] 1.3 Add `Info.plist` with `LSUIElement=YES`, `LSMinimumSystemVersion=26.0`, bundle name RenderPause Pro
- [x] 1.4 Add `project.yml` (XcodeGen) or Xcode project with app target `RenderPausePro` (module name `RenderPausePro`, arm64) and unit test target `RenderPauseProTests`
- [x] 1.5 Implement minimal `@main` AppKit entry + `AppDelegate` accessory policy + placeholder `MenuBarController` status item
- [x] 1.6 `xcodebuild -scheme RenderPausePro -destination 'platform=macOS' build` succeeds

## 2. Domain models and RuleStore (use superpowers:test-driven-development)

- [x] 2.1 Add `OptimizeAction`, `AppRule` (idle clamp 5...600, default hide/30s), `WatchState`, `LogEntry`, `AppSettings`
- [x] 2.2 Write `RuleStoreTests` for empty default, upsert, remove, clamp, persistence via ephemeral `UserDefaults` suite
- [x] 2.3 Implement `RuleStore` to pass tests
- [x] 2.4 Implement `SessionStore`, `ActionLog` (ring buffer ≤200), `SettingsStore` with unit coverage for session optimized set and settings round-trip

## 3. PolicyEngine (use superpowers:test-driven-development)

- [x] 3.1 Define `RunningAppSnapshot` and `PolicyCommand` (`optimize` / `restore` / `setState`)
- [x] 3.2 Write `PolicyEngineTests` covering: no rules; optimize when inactive+idle; no optimize when frontmost; idle too low; restore when active; locked/exempt/disabled; monitoring off; hide when already hidden
- [x] 3.3 Implement pure `PolicyEngine.evaluate` restore-first logic + in-memory temp exemptions until date
- [x] 3.4 All unit tests green via `xcodebuild test`

## 4. Sensors and actuators

- [x] 4.1 Implement `IdleSensor` using CoreGraphics last-event ages (min across key/mouse types)
- [x] 4.2 Implement `WorkspaceSensor` (activate/deactivate/hide/unhide/launch/terminate → callback; snapshots for bundle IDs)
- [x] 4.3 Implement `HideActuator` and `PermissionGate` (AX trust check + open Accessibility settings URL candidates)
- [x] 4.4 Implement `MinimizeActuator` (minimize/deminiaturize via AX) and `RestoreCoordinator` mapping action → optimize/restore
- [x] 4.5 Ensure optimize path never uses SIGSTOP/SIGCONT

## 5. AppController orchestration

- [x] 5.1 Implement singleton `AppController` owning stores, engine, workspace sensor, 1s timer, `tick()` apply loop, action logging
- [x] 5.2 Wire `applicationDidFinishLaunching` → `start()`, `applicationWillTerminate` → restore all optimized + stop sensors
- [x] 5.3 Implement `restoreAll(reason:)`, `exempt(bundleID:duration:)`, and monitoring-driven timer behavior
- [x] 5.4 Reject self bundle ID on any rule upsert path

## 6. Menu bar shell

- [x] 6.1 Build status menu: monitoring state, today optimize count, restore all, rule quick toggles / empty guidance, preferences, AX status, quit (Chinese copy)
- [x] 6.2 Reload menu on settings/log/rule/session changes
- [x] 6.3 Manual smoke: app shows status item, no Dock icon under LSUIElement

## 7. Preferences, picker, onboarding, login item

- [x] 7.1 Preferences window: rules table (enable, name, bundle ID, action, idle, lock), add/remove, recent logs, AX status, launch-at-login toggle
- [x] 7.2 Running app picker sheet filtered to regular apps not already listed and not self
- [x] 7.3 Onboarding flow (purpose → AX guidance → add first app); persist `hasCompletedOnboarding`
- [x] 7.4 Temporary exemption actions (10m / 1h / until restart) from preferences or rule context
- [x] 7.5 `LaunchAtLogin` via `SMAppService.mainApp` register/unregister with error surfacing
- [x] 7.6 Optional: use **impeccable** (product/utility) to polish spacing, hierarchy, empty states—only after flows work

## 8. Verification and docs (use superpowers:verification-before-completion)

- [x] 8.1 README with build/run instructions, MVP scope, Accessibility note, link to PRD + architecture
- [x] 8.2 Manual checklist doc: add Safari/Notes, idle hide, Cmd+Tab restore, quit restore, minimize+AX, monitoring off, exemption
- [x] 8.3 Run full unit tests; fix failures
- [x] 8.4 Confirm PRD success criteria: opt-in only, restore on focus, no SIGSTOP, hide/minimize paths, low idle overhead intent
- [x] 8.5 `openspec validate mvp-window-optimizer --strict` passes
- [ ] 8.6 Archive change only after user accepts MVP (pending user acceptance)

## 9. Apply-phase skill notes

- [x] 9.1 Prefer **superpowers:executing-plans** or **subagent-driven-development** to walk this file top-to-bottom
- [x] 9.2 On hide/AX bugs, switch to **superpowers:systematic-debugging** before random API churn
- [x] 9.3 Do not start Phase 2 occlusion or Phase 3 SIGSTOP under this change
