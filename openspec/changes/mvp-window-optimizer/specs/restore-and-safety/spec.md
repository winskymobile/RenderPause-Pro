## ADDED Requirements

### Requirement: Restore has priority over optimize
When a target app becomes active or frontmost, the system SHALL immediately restore it if it is in optimized state, before considering any new optimize conditions.

#### Scenario: Cmd-Tab back restores
- **WHEN** an optimized app becomes frontmost
- **THEN** the system restores it (unhide or deminiaturize per last rule action) and sets state back to watched

#### Scenario: Restore uses matching action
- **WHEN** the app was optimized with `hide`
- **THEN** restore uses unhide; when optimized with `minimize`, restore deminiaturizes windows

### Requirement: Manual restore all
The system SHALL provide a user action to restore all currently optimized apps immediately.

#### Scenario: Menu restore all
- **WHEN** the user chooses “立即恢复全部” (or equivalent)
- **THEN** every session-optimized app is restored and logged with a manual reason

### Requirement: Quit restores optimized apps
On application termination, the system SHALL restore all apps currently tracked as optimized.

#### Scenario: Quit cleanup
- **WHEN** RenderPause Pro is quitting and one or more apps are optimized
- **THEN** those apps are restored before exit completes

### Requirement: Temporary exemption pauses optimization
The system SHALL support temporary per-app exemptions that prevent optimization until expiry, and MUST restore first if the app is currently optimized when exemption starts.

#### Scenario: Exempt ten minutes
- **WHEN** the user exempts an app for 10 minutes
- **THEN** the app is not optimized during that window even if inactive and idle

#### Scenario: Exempt while optimized restores first
- **WHEN** the user exempts an app that is currently optimized
- **THEN** the system restores the app, then marks it paused/exempt

### Requirement: No process suspension in MVP
The MVP SHALL NOT send `SIGSTOP`, `SIGCONT`, or otherwise freeze third-party process threads as an optimization strategy.

#### Scenario: No suspend APIs in optimize path
- **WHEN** an optimize command is applied
- **THEN** the only allowed window-layer actions are hide/unhide or Accessibility minimize/deminiaturize

### Requirement: Action log records key events locally
The system SHALL keep a local ring-buffer action log of optimize, restore, and error events with timestamp, app identity, action, and reason, without requiring network access.

#### Scenario: Optimize is logged
- **WHEN** an app is successfully optimized
- **THEN** a local log entry exists with event optimized, bundle ID, action, and reason

#### Scenario: Errors are logged
- **WHEN** minimize fails due to missing Accessibility
- **THEN** a local error log entry is recorded with a distinguishable reason
