## ADDED Requirements

### Requirement: Menu bar only presentation
The app SHALL run as a menu bar / accessory agent (`LSUIElement`) without a regular Dock presence for normal operation.

#### Scenario: Launch shows status item
- **WHEN** the app finishes launching
- **THEN** a status item is visible in the menu bar and the app uses accessory activation policy

### Requirement: Status menu exposes core controls
The status menu SHALL show monitoring state, today’s optimize count, per-rule quick toggles (or empty-state guidance), restore all, preferences entry, Accessibility status/action, and quit.

#### Scenario: Empty rules guidance
- **WHEN** the rule list is empty
- **THEN** the menu indicates that the user should add apps in Preferences

#### Scenario: Toggle monitoring from menu
- **WHEN** the user toggles monitoring from the status menu
- **THEN** global monitoring state flips and the menu reflects the new state

### Requirement: Preferences manage rules and settings
The preferences UI SHALL allow adding running apps, removing rules, editing enable/action/idle/lock, viewing recent logs, checking Accessibility, and configuring launch-at-login.

#### Scenario: Open preferences from menu
- **WHEN** the user chooses Preferences
- **THEN** a preferences window is shown with the rules management surface

### Requirement: First-run onboarding
On first launch (onboarding not completed), the system SHALL present a short onboarding flow covering purpose, Accessibility (for minimize), and adding the first app; completion MUST be persisted.

#### Scenario: First launch onboarding
- **WHEN** `hasCompletedOnboarding` is false at startup
- **THEN** onboarding is presented before or alongside normal menu bar operation

#### Scenario: Onboarding completion persists
- **WHEN** the user finishes onboarding
- **THEN** subsequent launches do not show onboarding again unless settings are reset

### Requirement: Accessibility guidance for minimize
The system SHALL detect Accessibility trust state and provide a control that prompts and/or opens System Settings to the Accessibility privacy pane.

#### Scenario: Untrusted Accessibility deep link
- **WHEN** Accessibility is not trusted and the user activates the permission guidance control
- **THEN** the system attempts to prompt and/or open the system Accessibility settings

### Requirement: Optional launch at login
The system SHALL allow the user to register or unregister the app as a login item via the modern Service Management API, defaulting to enabled after onboarding unless the user turns it off.

#### Scenario: Enable launch at login
- **WHEN** the user enables launch at login in Preferences
- **THEN** the app registers `SMAppService.mainApp` (or equivalent) successfully or surfaces a clear failure

### Requirement: Chinese-first MVP copy
MVP UI strings SHALL be Chinese-primary for menus, onboarding, and preferences labels, with structure that can accept localization later.

#### Scenario: Status menu is Chinese
- **WHEN** the status menu is opened on a default MVP build
- **THEN** primary control labels are presented in Chinese
