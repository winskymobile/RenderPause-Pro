## ADDED Requirements

### Requirement: Optimize only when inactive and idle threshold met
For an eligible enabled rule, the system SHALL issue an optimize action only when the target app is not frontmost/active, system input idle time is greater than or equal to the rule’s idle seconds, global monitoring is on, and the rule is not locked or temporarily exempt.

#### Scenario: Hide after idle while in background
- **WHEN** Notes is in the rule list with action `hide` and idle 30s, Notes is not frontmost, monitoring is on, idle time is at least 30s, and Notes is not locked/exempt
- **THEN** the system hides Notes and records an optimize log entry with reason indicating inactive+idle

#### Scenario: Frontmost app is not optimized
- **WHEN** the target app is frontmost or active
- **THEN** the system MUST NOT issue an optimize command for that app

#### Scenario: Idle below threshold does not optimize
- **WHEN** the target is inactive but system idle seconds are below the rule threshold
- **THEN** the system MUST NOT issue an optimize command

### Requirement: Default optimize action is Hide via public AppKit API
The default optimize action SHALL be Hide using `NSRunningApplication.hide()` (or equivalent public AppKit API), without requiring Accessibility permission.

#### Scenario: Hide without Accessibility
- **WHEN** Accessibility is not granted and a rule action is `hide` meeting optimize conditions
- **THEN** the system still performs hide successfully

### Requirement: Minimize action uses Accessibility when available
When a rule action is `minimize`, the system SHALL minimize target windows via Accessibility APIs only if trusted; otherwise it SHALL fail closed for that action and record an error without silently rewriting the rule to hide.

#### Scenario: Minimize with Accessibility trusted
- **WHEN** Accessibility is trusted, rule action is `minimize`, and optimize conditions are met
- **THEN** the system minimizes the target app’s windows and records optimize success

#### Scenario: Minimize without Accessibility fails closed
- **WHEN** Accessibility is not trusted, rule action is `minimize`, and optimize conditions are met
- **THEN** the system does not minimize, records an error reason such as accessibility not trusted, and leaves the session state non-optimized

### Requirement: Hide path is idempotent with already-hidden apps
If the rule action is `hide` and the target app is already hidden, the system SHALL treat the app as optimized without re-issuing a harmful duplicate user-visible failure.

#### Scenario: Already hidden marks optimized without error spam
- **WHEN** optimize conditions are otherwise met and the target app reports `isHidden == true` for a hide rule
- **THEN** the system marks state optimized and does not require another successful hide call to avoid thrashing

### Requirement: Monitoring kill-switch disables new optimizations
When global monitoring is disabled, the system SHALL NOT issue new optimize commands.

#### Scenario: Monitoring paused
- **WHEN** the user turns monitoring off
- **THEN** no further optimize commands are produced for any rule until monitoring is turned on again

### Requirement: Event-driven evaluation with light idle polling
The system SHALL re-evaluate policy on workspace focus/hide/launch/terminate notifications and MAY poll idle time about once per second while monitoring, without continuous high-frequency scanning.

#### Scenario: Focus change triggers re-evaluation
- **WHEN** the frontmost application changes
- **THEN** the policy engine evaluates rules promptly (without waiting solely for a long poll interval)
