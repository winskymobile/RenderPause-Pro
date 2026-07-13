## ADDED Requirements

### Requirement: Partial visibility is a hard protect against optimize
At apply time, the system SHALL treat partial visibility as a hard protection equivalent to frontmost/Split View partner protection and MUST NOT perform hide/minimize for that app.

#### Scenario: Protect partially visible app at apply
- **WHEN** the policy engine emits optimize for a bundle ID but the live sensor reports the app is partially visible
- **THEN** the system skips the optimize action and keeps the session in a non-optimized watched state

### Requirement: No process suspension remains
The system SHALL NOT introduce SIGSTOP/SIGCONT as part of occlusion handling; only window-layer hide/minimize/restore remain allowed optimize actuators.

#### Scenario: Occlusion path uses window actions only
- **WHEN** an app becomes fully occluded and is optimized
- **THEN** the applied action is only hide or Accessibility minimize
