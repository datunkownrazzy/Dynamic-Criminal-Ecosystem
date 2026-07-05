# ADR-0007: Migration Away from Global State

**Status:** Accepted
**Date:** 2026-07-04
**Author:** Architecture
**Dependencies:** DCE-0001 (Service Registry), Coding_Standards.md, AGENTS.md
**Drop into:** `architecture/ADR-0007-Migration-Away-From-Global-State.md`

**Note on numbering:** this was proposed informally as "ADR-010." Renumbered to `0007` since that's the next unused slot — `architecture/` currently has two files both numbered `0003` (`Configurable-Dispatch-Evidence-Integrations` and `Event-Bus-Architecture`) that still need reconciling before any further ADRs are added. See that fix first; it's unrelated to this ADR but sits in the same folder and will cause confusion if left as-is.

---

## Problem

`AGENTS.md` rule #11 already says "avoid globals beyond the single `DCE` table," and `Core_Overview.md` establishes `DCE` as the one sanctioned global namespace. In practice, early implementation work (via `globals.lua`) has been accumulating responsibility on that global rather than shrinking toward it being a thin entry point — the natural failure mode `PROJECT_PRINCIPLES.md`'s discipline is meant to prevent. This ADR commits to an explicit, staged migration rather than either (a) tolerating global-state growth indefinitely or (b) attempting to rip it out all at once mid-implementation, which would be disruptive during the proof-of-concept stage and risks breaking every module at once.

## Decision

**`globals.lua` gets smaller over time, not smarter.** The target end-state, restated from `Core_Overview.md`, is:

```lua
local DCE = require(...)
local World = DCE:GetService("World")
```

No module should ever come to depend on new convenience functions bolted onto the global table — if a module needs something, it should be reachable through `DCE:GetService(...)` (`DCE-0001`) or a typed interface (see the companion `Type_System_and_Contracts.md`), not through an expanding global surface.

### Staged Migration

```
Phase 1 — Add typed interfaces and contracts while maintaining full compatibility.
    │
    ▼
Phase 2 — Transition services to dependency injection via the Service Registry
          (modules stop reaching for globals directly, start resolving through DCE:GetService).
    │
    ▼
Phase 3 — Deprecate _G accessors
          (mark old global-table shortcuts as deprecated; log a warning on use; document the replacement).
    │
    ▼
Phase 4 — Remove _G usage from the core framework
          once all first-party modules have migrated.
```

Each phase is a prerequisite for the next — Phase 3 (deprecation warnings) must not begin until Phase 1's typed interfaces actually exist as a real replacement path, or the warnings would be pointing developers at nothing.

### What This ADR Does Not Do

- It does not authorize a rewrite of runtime behavior. This is a structural migration of *how modules reach each other*, not a change to *what the simulation does* — consistent with the constraint that this work must not touch Event Bus or Service Registry architecture (those are already correctly specified in `DCE-0001`/`DCE-0002`/`ADR-0003-Event-Bus-Architecture`; this ADR is about getting the rest of the codebase to actually use them consistently instead of falling back to globals).
- It does not set a hard deadline for Phase 4. Removing `_G` usage from core only happens once all dependent modules have migrated — forcing it prematurely would break working modules for the sake of architectural tidiness, which is exactly the kind of unrelated refactor `Coding_Standards.md` already warns against ("prefer the smallest change that satisfies the rules... don't restructure unrelated code while you're in there").

### Backwards Compatibility During Migration

Per `AGENTS.md` rule #14, anything currently reachable via the global table that gets deprecated is a breaking-change candidate for whichever module depends on it — Phase 3's deprecation warnings exist specifically to give module authors (first-party and plugin) visible notice before Phase 4 actually removes anything.

## Consequences

- Slower short-term velocity on anything touching cross-module access, since new code should route through the Service Registry/typed interfaces even while the old global shortcuts still technically work — this is accepted as the cost of not accumulating more of the problem this ADR exists to fix.
- `globals.lua` becomes a shrinking, closely-watched file rather than a general-purpose utility drop point. Any PR that adds a new function to `globals.lua` should be treated as a design smell worth a second look, per this ADR's intent, not a routine change.
- This ADR should be revisited once Phase 2 is substantially complete, to set a concrete plan (not necessarily a hard date) for Phases 3–4.

## Related

- `docs/03_Core/Core_Overview.md`
- `specifications/DCE-0001-Service-Registry.md`
- `docs/02_Architecture/Type_System_and_Contracts.md` (companion document — the replacement path Phase 1 builds)
- `docs/01_Project/AI_Developer_GUIDE.md` / `AGENTS.md` rule #11
