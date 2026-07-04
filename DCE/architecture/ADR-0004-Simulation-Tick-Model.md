# ADR-0004: Simulation Tick Model

**Status:** Accepted
**Date:** 2026-07-04
**Author:** Architecture
**Dependencies:** Scheduler.md, SimulationScheduler.md, SimulationBudget.md, Simulation_Layers.md

---

## Problem

`Scheduler.md` specifies how individual modules register named recurring tasks. `SimulationScheduler.md` already sketches a master-loop phase model (world → AI → dispatch/evidence → observability), and `SimulationBudget.md` already defines per-layer performance budgets. None of these three documents, individually, commits to a single authoritative priority ordering for what runs when under load — which is exactly what's needed for the framework to degrade predictably instead of unpredictably once a server has many organizations, territories, and active incidents running at once. This ADR is the single source of truth for tick ordering, formalizing and connecting the three existing documents rather than introducing a fourth parallel model.

## Decision

### Priority Tiers

Every scheduled task (`DCE:Schedule`, per `Scheduler.md`) is assigned to one of four priority tiers. The Persistence Coordinator's simulation loop runs tiers in strict order, every server tick:

```
Server Tick
    │
    ▼
Simulation Scheduler
    │
    ▼
High Priority   — Dispatch, active Incident AI (Layer 3), Combat-adjacent state
    │
    ▼
Medium Priority — Territory, Economy, Organization decision-making (Layer 2, AI Director scoring)
    │
    ▼
Low Priority    — Civilian ambient simulation (Layer 1), background Intelligence decay, Analytics/Statistics
    │
    ▼
Deferred Jobs   — Non-time-critical work: persistence autosave batching, World Chronicle writes (once built), log flushing
```

**High Priority** exists because a delayed dispatch update or a stalled active-incident tick is directly player-visible and breaks immersion immediately — per `Vision.md`'s core promise, an Incident in progress must feel responsive.

**Medium Priority** covers the actual "decision-making" core of the simulation — Territory/Economy/Organization state changes matter a great deal but are not sub-second-latency-sensitive the way an active Incident is.

**Low Priority** covers ambient flavor and background bookkeeping that can visibly lag under load without breaking anything a player is directly interacting with.

**Deferred Jobs** are work that has no real-time requirement at all and exists purely to eventually happen — these are the first candidates `SimulationBudget.md`'s degradation rules should throttle or skip entirely when the server is under load.

### Assignment Rule

A task's tier is declared at registration time, not inferred:

```lua
DCE:Schedule("dispatch:call:tick", interval, fn, { priority = "High" })
DCE:Schedule("territory:tick", interval, fn, { priority = "Medium" })
DCE:Schedule("world:layer1:ambient:tick", interval, fn, { priority = "Low" })
DCE:Schedule("persistence:autosave", interval, fn, { priority = "Deferred" })
```

If a module registers a task without a priority, it defaults to **Medium** — never silently High (which would let modules opt into contention for player-visible latency without a deliberate decision) and never silently Low (which would let a module's degraded behavior go unnoticed by its own author).

### Ordering Guarantee

Within a tick, tiers execute strictly in the order above — no Medium-priority task begins until every High-priority task registered for that tick has completed, and so on down. This is a deliberate, strict ordering, not a weighted/interleaved scheduler, because predictability under load matters more for this framework than fairness between tiers — per `PROJECT_PRINCIPLES.md` #7 (performance before features), a server owner should be able to reason about exactly what gets sacrificed first when the server is under strain, not have it vary tick to tick.

### Relationship to Simulation Layers

Priority tier and Simulation Layer (`Simulation_Layers.md`) are related but distinct axes — a task's tier is about *time-sensitivity*, a Layer is about *simulation fidelity/scope*. In practice they correlate strongly (Layer 3 work tends to be High priority, Layer 0 tends to be Low/Medium) but a module should declare its tier explicitly rather than assuming the Layer implies it, since exceptions exist — e.g., a Layer 0 statistical update that's cheap but time-sensitive for dispatch accuracy could still warrant High.

### Budget Enforcement

`SimulationBudget.md`'s per-system cost budgets are enforced per tier, using the Scheduler's existing per-task timing (`DCE:GetSchedulerStats()`, `Scheduler.md`). If a tier's aggregate cost exceeds its configured budget (`Config.SimulationBudget.<Tier>MaxMs`) for a sustained period, the degradation response defined in `SimulationBudget.md` applies **starting with Deferred, then Low, then Medium** — High priority tasks are the last to be throttled, and only as a last resort, since throttling Dispatch/active-Incident work directly degrades the player experience DCE exists to protect.

### Emitted Events

- `scheduler:tier:budget_exceeded` — `{ tier, actualMs, budgetMs }` (already implied by `SimulationBudget.md`; this ADR formalizes that it's tier-scoped, not just system-scoped)
- `scheduler:tier:degraded` — `{ tier, action }` (e.g., `{ tier = "Low", action = "skipped_this_tick" }`)

These feed directly into the Admin UI's Performance Monitor (`Admin_UI.md`), which already sources from `SimulationBudget.md`'s warning events.

## Consequences

- Every module author must now make an explicit, documented choice about tier when registering a scheduled task — this is new required ceremony beyond what `Scheduler.md` alone required, but it's what makes graceful degradation possible at all.
- Strict tier ordering means a pathological High-priority task that runs long can delay Medium/Low tiers for that entire tick. This is an accepted tradeoff (predictable degradation) but means High-priority task authors carry extra responsibility to keep their per-task cost genuinely small — this should be called out explicitly in `Coding_Standards.md`'s review checklist.
- `SimulationScheduler.md` and `SimulationBudget.md` remain the detailed specs for *how* the loop and budget mechanics work internally; this ADR is the canonical statement of *the ordering itself* and should be the first thing referenced when either of those documents is updated, to avoid the two drifting into a third, undocumented model over time.

## Related

- `docs/03_Core/Scheduler.md`
- `docs/02_Arcitecture/SimulationScheduler.md`
- `docs/02_Arcitecture/SimulationBudget.md`
- `docs/04_Simulation/Simulation_Layers.md`
- `docs/14_Admin/Admin_UI.md`
