# Change: mvp-window-optimizer

Phase 1 MVP for RenderPause Pro: opt-in auto Hide/Minimize of idle background apps to reduce WindowServer composition cost.

## Source of truth

- `PRD.md`
- `docs/MVP-Architecture.md`
- This change’s `proposal.md` → `specs/**` → `design.md` → `tasks.md`

## Workflow

```bash
openspec status --change mvp-window-optimizer
openspec validate mvp-window-optimizer --strict
openspec instructions apply --change mvp-window-optimizer
```

## Implementation skills (as needed)

- **superpowers**: plan execution, TDD for engine/stores, verification-before-completion, systematic-debugging
- **impeccable**: Preferences / onboarding UI polish after functional core

## Apply

Implement tasks in `tasks.md` in order; check boxes as you go. Do not expand into Phase 2/3.
