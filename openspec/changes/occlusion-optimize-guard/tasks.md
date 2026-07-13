## 1. Occlusion geometry (TDD)

- [x] 1.1 Add pure `OcclusionDetector` residual-area helpers with residual threshold constant (~2%)
- [x] 1.2 Write unit tests: fully covered, partial peek, no covering windows, multi-cover stack, empty target windows
- [x] 1.3 Implement helpers to pass tests (axis-aligned rect subtraction, front-to-back covers)

## 2. Sensor wiring

- [x] 2.1 Extend `RunningAppSnapshot` with `isPartiallyVisible`
- [x] 2.2 In `WorkspaceSensor.snapshots`, reuse one CGWindow list; compute occlusion; only start/advance `deactivatedAt` when fully occluded and not effective-foreground
- [x] 2.3 Extend `isProtectedFromOptimize` to include partial visibility
- [x] 2.4 Ensure Split View partner path still clears timer / treats as effective-foreground

## 3. Policy / apply safety

- [x] 3.1 Keep PolicyEngine restore-first; optimize still driven by snapshot seconds (now occlusion-gated upstream)
- [x] 3.2 Confirm `AppController` hard protect uses updated `isProtectedFromOptimize`
- [x] 3.3 Update PolicyEngine tests if snapshot initializer signature changes

## 4. Verification

- [x] 4.1 `xcodebuild test` green
- [x] 4.2 Debug build succeeds; reinstall `/Applications/RenderPausePro.app`
- [x] 4.3 `openspec validate occlusion-optimize-guard --strict` passes
- [x] 4.4 Mark tasks complete; note manual check: partially covered watched app must not hide

## 5. Docs (light)

- [x] 5.1 Brief note in `docs/MVP-Architecture.md` that occlusion guard is landed (Scheme A)
