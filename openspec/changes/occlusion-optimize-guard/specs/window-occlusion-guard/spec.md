## ADDED Requirements

### Requirement: Detect partial visibility from on-screen window geometry
The system SHALL approximate whether a watched app still has significant residual visible area using public on-screen window geometry (CGWindow list), without injecting into third-party processes.

#### Scenario: Partially covered window remains visible
- **WHEN** a watched app has a significant on-screen window whose residual unoccluded area is above the configured residual threshold after subtracting front-to-back covering windows
- **THEN** the system classifies the app as partially visible

#### Scenario: Fully covered window is occluded
- **WHEN** every significant on-screen window of a watched app has residual unoccluded area at or below the residual threshold
- **THEN** the system classifies the app as fully occluded

#### Scenario: No significant on-screen windows counts as occluded for eligibility
- **WHEN** a watched app has no significant on-screen windows in the current sample (e.g. other Space)
- **THEN** the system treats the app as fully occluded for optimize eligibility

### Requirement: Partial visibility blocks optimization
The system MUST NOT issue hide or minimize optimize actions for a watched app while that app is classified as partially visible.

#### Scenario: Background but still peeking is not optimized
- **WHEN** a watched app is not frontmost, monitoring is on, background seconds would otherwise meet the global threshold, and the app is partially visible
- **THEN** the system MUST NOT optimize that app

### Requirement: Background timer only advances while fully occluded
The system SHALL accumulate seconds-since-deactivated for optimize eligibility only while the watched app is not effective-foreground and is fully occluded (or has no significant on-screen windows). Partial visibility SHALL reset or prevent accumulation of that timer.

#### Scenario: Partial visibility resets background timer
- **WHEN** a watched app becomes partially visible after being backgrounded
- **THEN** its seconds-since-deactivated used for optimize is zero (or not advanced) until it is fully occluded again

#### Scenario: Full occlusion then threshold optimizes
- **WHEN** a watched app remains non-frontmost and fully occluded for at least the global background seconds threshold, monitoring is on, and the rule is enabled
- **THEN** the system MAY issue optimize subject to existing action/permission rules
