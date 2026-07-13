## MODIFIED Requirements

### Requirement: Optimize only when inactive and idle threshold met
For an eligible enabled rule, the system SHALL issue an optimize action only when all of the following hold: the target app is not effective-foreground (not frontmost/active and not a Split View partner), the app is fully occluded (or has no significant on-screen windows), continuous fully-occluded background duration is greater than or equal to the global background seconds threshold, global monitoring is on, and the rule is enabled.

#### Scenario: Hide after fully occluded background threshold
- **WHEN** Notes is in the rule list with action `hide`, Notes is not effective-foreground, Notes is fully occluded, monitoring is on, and fully occluded background duration is at least the global threshold
- **THEN** the system hides Notes and records an optimize log entry with reason indicating background duration

#### Scenario: Frontmost app is not optimized
- **WHEN** the target app is frontmost or active
- **THEN** the system MUST NOT issue an optimize command for that app

#### Scenario: Partially visible app is not optimized
- **WHEN** the target is not frontmost but remains partially visible
- **THEN** the system MUST NOT issue an optimize command even if wall-clock time since last focus exceeds the threshold

#### Scenario: Background duration below threshold does not optimize
- **WHEN** the target is inactive and fully occluded but fully occluded background seconds are below the global threshold
- **THEN** the system MUST NOT issue an optimize command

## ADDED Requirements

### Requirement: Optimize eligibility includes occlusion
Optimize eligibility SHALL require full occlusion in addition to non-frontmost status and background duration; Split View partners remain non-eligible as effective-foreground.

#### Scenario: Split partner still not optimized
- **WHEN** a watched app is a Split View partner of the regular frontmost app
- **THEN** the system MUST NOT issue an optimize command for that partner
