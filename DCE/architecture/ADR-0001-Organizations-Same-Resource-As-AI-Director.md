# ADR-0001: Organizations and AI Director Share `dce-ai`

**Status:** Accepted  
**Date:** 2026-07-04  
**Owner:** Architecture  
**Related:** Organizations, AI Director, Architecture Overview, PROJECT_PRINCIPLES

---

## Context

DCE separates **what an Organization is** from **what an Organization decides to do**:

- The `Organizations` Service owns organization identity, runtime state, resources, leadership, emitted events, and state exposure.
- The `AIDirector` Service reads Organization state, World Engine state, memory/intelligence, and configuration to score and select behavior.

This creates a clear conceptual boundary. The open architectural question was whether that boundary should also be enforced structurally by splitting Organizations into a separate FiveM resource, such as `dce-organizations`, instead of keeping both Services inside `dce-ai`.

FiveM resources run in separate Lua VMs. Cross-resource calls through exports require crossing the resource boundary and marshaling arguments between VMs. That is measurably more expensive than a plain Lua function call inside a single resource.

The Organizations/AIDirector relationship is hot-path behavior. The AI Director reads Organization state during Layer 0 simulation scoring across the map, potentially for every organization on recurring ticks. This is not an occasional integration boundary like Dispatch, Evidence, Analytics, or Chronicle reactions to resolved incidents.

---

## Decision

Keep **Organizations** and **AI Director** in the same FiveM resource: `dce-ai`.

Within `dce-ai`, implement them as two distinct registered Services:

- `Organizations`
- `AIDirector`

The architectural boundary is enforced by Service ownership and API discipline, not by a separate FiveM resource boundary.

Organizations remain responsible for state shape, persistence-critical fields, leadership references, state enum exposure, and emitted organization events.

AI Director remains responsible for scoring, planning, transition decisions, and behavior selection.

---

## Rationale

The shared-resource design best satisfies DCE's performance and modularity goals:

| Concern | Same `dce-ai` resource | Separate `dce-organizations` resource |
|---|---|---|
| Call cost | Plain Lua function calls inside one VM | Cross-resource export calls with marshaling overhead |
| Call frequency | Very high between AI Director and Organizations | Same high frequency, but with extra overhead |
| Runtime independence | Not independently enableable | Technically enableable separately, but not practically useful |
| Architectural separation | Enforced by Services and conventions | Enforced by VM/resource boundary |
| Fit for hot path | Strong | Weak |

The AI Director and Organizations are not independently useful at runtime. The AI Director cannot make meaningful decisions without Organization state, and Organization state exists primarily to be read and acted on by the AI Director and related systems.

By contrast, systems such as Dispatch, Evidence, Analytics, and Chronicle are better candidates for separate resources because they react to coarser events, such as resolved incidents, rather than being queried continuously during scoring ticks.

---

## Consequences

### Positive

- Avoids cross-VM overhead on the Layer 0 organization scoring hot path.
- Keeps the most tightly coupled simulation services close together.
- Preserves conceptual separation through distinct Service APIs.
- Keeps implementation simpler for v1.0.
- Supports plugin data loading for Organizations without requiring per-organization code changes.

### Negative

- The Organization/AI Director boundary is not physically enforced by the FiveM resource system.
- `dce-ai` becomes a larger resource with multiple internal responsibilities.
- Care is required to prevent AI Director logic from leaking into the Organizations Service.

### Mitigations

- Maintain separate files/modules for `Organizations` and `AIDirector`.
- Register them as separate Services through the DCE Service Registry.
- Treat Organization mutation APIs as owned by `dce-ai` and only called through controlled internal paths.
- Keep decision-making logic out of `Organizations` documentation and implementation.
- Add tests or validation checks that Organization schemas remain data-only.
