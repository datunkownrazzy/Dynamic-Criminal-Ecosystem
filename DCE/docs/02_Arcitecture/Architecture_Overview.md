# DCE Architecture Overview

**Status:** Accepted
**Version:** 1.0
**Owner:** Datunkownrazzy

---

## Purpose

This document describes how DCE's major systems fit together at a high level. It is the map you should read before touching any individual service. Detailed behavior for each piece lives in its own specification under `/specifications/`; this document only covers shape and relationships.

---

## High-Level Structure

```
                            DCE CORE
                                │
    ┌───────────────────────────┼───────────────────────────┐
    │                           │                           │
 World Engine            Integration Manager          Admin Framework
    │                           │                           │
 ┌──┼─────────────┐       ┌──────┼───────┐          ┌────────┼────────┐
 │  │             │       │      │       │          │        │        │
AI      Territory  Economy  Dispatch  Evidence     UI Panel Analytics Profiles
Director
 │
 ├── Organizations
 ├── Civilian AI
 ├── Heat System
 ├── Intelligence System
 ├── Investigation System
 └── Persistence
```

Everything sits underneath three foundational mechanisms, described in their own specs:

- **Service Registry** — how modules find each other (`DCE-0001`)
- **Event Bus** — how modules talk to each other (`DCE-0002`)
- **Persistence Layer** — how state survives restarts (own spec, later milestone)

For the next milestone, the architecture foundation is being documented in the following contracts:

- [SimulationScheduler.md](SimulationScheduler.md) — master timing model and update loop contract
- [StateMachine.md](StateMachine.md) — lifecycle and state transition rules for Services and entities
- [ServiceContracts.md](ServiceContracts.md) — Service Registry interface and dependency contract
- [EventContracts.md](EventContracts.md) — event naming, payload, and compatibility rules
- [DataOwnership.md](DataOwnership.md) — module ownership of state and change-request boundaries
- [SimulationBudget.md](SimulationBudget.md) — performance budgets, LOD behavior, and graceful degradation

No module is permitted to reach into another module's internal tables or call its private functions. All cross-module interaction goes through a registered Service interface or the Event Bus. This is not a style preference — it's what makes the plugin system and adapter pattern possible at all (see `PROJECT_PRINCIPLES.md` #4).

---

## Resource Boundaries

DCE ships as multiple independently loadable FiveM resources rather than one monolith, so server owners can disable pieces they don't want without breaking the rest:

| Resource | Responsibility |
|---|---|
| `dce-core` | Service Registry, Event Bus, Scheduler, Logger, Config loader |
| `dce-world` | World state, statistical simulation (Layer 0), Ambient simulation (Layer 1) |
| `dce-ai` | AI Director, Organization decision-making, Event Escalation |
| `dce-dispatch` | Generic Dispatch service + adapter loading |
| `dce-evidence` | Evidence registry, lifecycle, confidence, chain of custody, Investigation Graph |
| `dce-territories` | Territory state and lifecycle |
| `dce-economy` | Organization finances, supply chain modeling |
| `dce-investigations` | Higher-level detective/case tooling built on Evidence |
| `dce-ui` | Admin dashboard, Live World Inspector (NUI) |
| `dce-admin` | Admin commands, permissions, config editing |
| `dce-integrations` | CAD/MDT/inventory adapter registrations |
| `dce-sdk` | Public exports and interfaces for plugin authors |

`dce-core` is the only hard dependency for everything else. A server owner who disables `dce-investigations`, for example, should lose detective-tooling depth but keep dispatch, evidence generation, and the AI Director working normally.

---

## The Simulation Loop (System View)

This is the same loop from `Vision.md`, mapped onto the systems that implement each stage:

```
World State                →  dce-world
Organization Goals         →  dce-ai
AI Planning                →  dce-ai (AI Director)
Task Selection              →  dce-ai
World Events                →  dce-world / dce-ai
Civilian Reactions          →  dce-world (Civilian AI)
Dispatch Generation         →  dce-dispatch
Player Interaction          →  (player, via Layer 2/3 materialized content)
Evidence Created             →  dce-evidence
Organization Learns          →  dce-ai (memory/intelligence feedback)
World State Updates          →  dce-world
      └── loop repeats
```

Each arrow is an Event Bus interaction, not a direct function call. `dce-ai` never calls into `dce-dispatch` directly — it publishes something like `"organization:activity:escalated"`, and `dce-dispatch` (having subscribed) decides what to do with it. This means a plugin can subscribe to the same event without `dce-ai` knowing or caring that it exists.

---

## Simulation Layers and System Ownership

| Layer | Who's simulating | Owning resource(s) |
|---|---|---|
| 0 — Statistical | Entire map, numbers only | `dce-world`, `dce-ai` |
| 1 — Ambient | Near players, flavor NPCs | `dce-world` |
| 2 — Interactive | Player-affectable events | `dce-ai`, `dce-dispatch` |
| 3 — Major Incident | Full fidelity | `dce-ai`, `dce-dispatch`, `dce-evidence` |

A single Organization can have activity running at Layer 0 across the whole map while one specific Scenario near a player is being simulated at Layer 3. The layer is a property of the *event/agent*, not the whole server.

---

## Integration Manager

`dce-integrations` is responsible for:

1. Scanning installed resources at startup (`GetResourceState`) to detect known CAD/MDT/evidence/inventory systems.
2. Loading the matching adapter (or the highest-priority one, if multiple are installed and no admin override is set).
3. Exposing the generic interface (`CreateCall`, `UpdateCall`, `CloseCall`, `AttachEvidence`, etc.) that `dce-dispatch` and `dce-evidence` use, regardless of what's actually installed.
4. Falling back to DCE's own lightweight native implementation if nothing recognized is installed.

Full detail lives in the future `DCE-0004 Dispatch & Integration Adapter Spec`.

---

## Admin & Observability

`dce-ui` and `dce-admin` are intentionally separate from the simulation resources. Their job is to observe and configure, not to participate in the simulation loop directly. This keeps admin tooling from becoming a hidden dependency that other systems accidentally rely on.

Planned tooling (see `Goals.md` for what's required at v1.0 vs. deferred):
- Live World Inspector (per-agent/organization reasoning view)
- Developer console (`dce.debug <system>`)
- Performance monitor (per-system tick cost)
- Analytics dashboard

---

## Plugins

Plugins are not a separate resource type from the ones above — a plugin is any resource that depends only on `dce-sdk` and registers itself through the Service Registry / Event Bus like any other module would internally. There is no special-cased "plugin mode" inside core; if core needs a special code path to support plugins, that's a sign core isn't decoupled enough yet.

---

## What This Document Deliberately Leaves Out

- Exact function signatures — those belong in each system's own specification.
- Database schema — belongs in the Persistence spec.
- UI layout/design — belongs in `dce-ui` documentation.

This document should stay stable even as individual specs evolve underneath it. If a change here is needed, it likely deserves an ADR.
