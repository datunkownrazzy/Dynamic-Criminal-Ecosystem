# DCE Simulation Budget Contract

**Status:** Draft
**Version:** 0.1
**Owner:** Datunkownrazzy
**Applies To:** All simulation systems and scheduled work

---

## Purpose

This document defines the performance envelope for DCE's simulation systems. It establishes how budget is measured, how work is prioritized, and how the framework degrades gracefully when the simulation load exceeds sustainable limits.

The intent is to keep DCE playable and observable even as the number of Organizations, Territories, and active Incidents grows.

---

## Budget Principles

1. Performance is a first-class system concern, not an afterthought.
2. Layer 0 work must remain cheap at map scale.
3. Expensive work should be scoped to active content rather than run everywhere by default.
4. Budget pressure should trigger predictable degradation, not random instability.
5. Budget metrics must be visible to admins and developers.

---

## Budget Categories

### Layer 0 Budget

Layer 0 work is global and must be bounded tightly. It should be cheap enough to run for all Organizations and Territories on the map without causing visible hitching.

Expected characteristics:

- low per-entity cost,
- high frequency but shallow work,
- and no expensive pathfinding, database I/O, or full incident simulation.

### Layer 1 Budget

Layer 1 work is ambient and should be limited to nearby or relevant content. It can be slightly more expensive than Layer 0 but must remain bounded.

### Layer 2 and Layer 3 Budget

Layer 2 and Layer 3 work may be more expensive because it is tied to active player-affectable events and major incidents. These systems may spend more CPU time, but only for the specific active scope.

---

## Budgeting Rules

Each recurring task should be assigned a budget target in terms of expected cost per tick.

Recommended policy:

- Layer 0 tasks should remain near the lower end of the budget envelope.
- Layer 1 tasks may use modestly more budget when they are near active players.
- Layer 2 and Layer 3 tasks may use higher budget but should be scoped and throttled.

Work that exceeds budget must be treated as a signal to degrade or defer.

---

## Degradation Strategy

When a system exceeds its budget, it should degrade in a controlled way:

1. reduce update frequency,
2. skip non-critical detail updates,
3. limit scope to the nearest or most relevant entities,
4. and preserve the core correctness of the simulation.

Examples:

- skip ambient flavor updates when the server is under pressure,
- reduce the number of active simulated Scenarios,
- and defer non-critical evidence processing until later.

Degradation must preserve the simulation's ability to recover rather than collapse into invalid state.

---

## LOD Behavior

DCE should use Level of Detail (LOD) behavior to adapt cost to context.

### Suggested LOD tiers

- **LOD 0**: global statistical activity with minimal detail
- **LOD 1**: nearby ambient activity with moderate detail
- **LOD 2**: player-affectable active content with high detail
- **LOD 3**: major incident simulation with full fidelity

The selected LOD must be based on relevance, distance, player proximity, and current budget pressure.

---

## Observability

Every subsystem should expose budget metrics that can be collected by the scheduler and surfaced to admins.

At minimum, the framework should report:

- task name,
- average runtime,
- last runtime,
- whether it was skipped or deferred,
- and whether the system entered a degraded state.

This data is required for future performance dashboards and debugging tools.

---

## Enforcement Expectations

The scheduler and the relevant services should work together to enforce the budget contract. A subsystem that exceeds its budget repeatedly should be considered a candidate for:

- higher-level throttling,
- lower-default frequency,
- or a redesign toward cheaper computation.

The framework should favor stable simulation over maximum detail under load.
