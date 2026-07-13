## ADDED Requirements

### Requirement: Rules are opt-in and empty by default
The system SHALL ship with an empty watched-app rule list so that no third-party application is optimized until the user explicitly adds it.

#### Scenario: Fresh install has no rules
- **WHEN** the app launches for the first time with no persisted rules
- **THEN** the rule list is empty and the system performs no hide or minimize actions on any app

### Requirement: User can add a rule from a running regular app
The system SHALL allow the user to add a rule for a currently running application that uses regular activation policy, capturing its bundle identifier and display name.

#### Scenario: Add from running apps picker
- **WHEN** the user selects a running regular GUI app that is not already in the rule list and is not RenderPause Pro itself
- **THEN** the system creates an enabled rule with action `hide`, idle threshold 30 seconds, and `locked` false

#### Scenario: Self target is rejected
- **WHEN** the user attempts to add RenderPause Pro’s own bundle identifier as a rule
- **THEN** the system rejects the addition and leaves the rule list unchanged

#### Scenario: Non-regular apps are not offered
- **WHEN** the running-apps picker is shown
- **THEN** applications with non-regular activation policy (agents / UIElement) are not listed

### Requirement: Rule fields are configurable and validated
Each rule SHALL support enable/disable, optimize action (`hide` or `minimize`), idle threshold clamped to 5–600 seconds, and a permanent lock flag that forbids optimization.

#### Scenario: Idle seconds are clamped
- **WHEN** a rule is saved with idle seconds below 5 or above 600
- **THEN** the stored idle seconds are clamped into the inclusive range 5–600

#### Scenario: Disable rule stops optimization eligibility
- **WHEN** a rule’s enabled flag is false
- **THEN** the policy engine MUST NOT issue optimize commands for that bundle ID

#### Scenario: Locked rule never optimizes
- **WHEN** a rule has `locked` true
- **THEN** the policy engine MUST NOT issue optimize commands for that bundle ID even if enabled and idle

### Requirement: Rules persist across launches
The system SHALL persist the rule list locally and reload it on subsequent launches.

#### Scenario: Rules survive restart
- **WHEN** the user adds or edits rules and quits the app, then relaunches
- **THEN** the same rules (bundle ID, action, idle, enabled, locked, display name) are restored

### Requirement: Upsert is keyed by bundle identifier
The system SHALL treat bundle identifier as the unique rule key so upserting an existing ID updates rather than duplicates.

#### Scenario: Upsert replaces existing rule
- **WHEN** a rule already exists for bundle ID `com.example.app` and the user saves a new configuration for the same ID
- **THEN** exactly one rule remains for that ID with the new configuration
