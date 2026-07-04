# DCE Simulation Scheduler Contract

**Status:** Draft
**Version:** 0.1
**Owner:** Datunkownrazzy
**Applies To:** Core simulation services, AI, Dispatch, Evidence, Territories, Economy

---

## Purpose

This document defines the master timing model for DCE's simulation loop. It standardizes how recurring work is scheduled, how update phases are ordered, and how modules participate in the shared loop without bypassing the Service Registry or Event Bus.

The scheduler contract exists so that every simulation system can be reasoned about in the same terms: cadence, scope, cost, and shutdown behavior.

---

## Core Principles

1. The simulation loop is a shared framework concern, not a private implementation detail of any one module.
2. Every recurring update must be named, observable, and cancelable.
3. Layer 0 work must remain cheap enough to run at map scale; Layer 3 work may be more expensive but must be scoped to the active Incident or Scenario.
4. Timing values are configurable and must come from Config, never from inline magic numbers.
5. Modules must not block the main thread with long-running work. Heavy work must be partitioned into scheduled tasks or deferred callbacks.

---

## Master Loop Model

DCE uses a staged simulation loop with a single authoritative coordinator.

1. **Tick start**
   - The scheduler announces a new simulation tick.
   - Metrics for the tick are initialized.

2. **World state refresh**
   - Layer 0 and Layer 1 systems update shared world state.
   - This phase may publish world-state events for downstream consumers.

3. **Organization and AI planning**
   - Organization goals, Heat, Intelligence, and Scenario selection are evaluated.
   - This phase is allowed to request Dispatch or Evidence work but must not directly mutate another module's internal state.

4. **Interactive and incident resolution**
   - Layer 2 and Layer 3 content becomes active when needed.
   - Active Incidents and Scenarios resolve their next decision step.

5. **Effects and observability**
   - State changes are persisted to the owning service, emitted through the Event Bus, and logged for observability.

6. **Tick end**
   - The scheduler records timing and budget data.
   - Any over-budget warnings are emitted for the admin and analytics surfaces.

---

## Timing Rules

### Cadence

Each module declares its own update cadence through Config. The scheduler only executes the task according to the declared interval.

### Ordering

Within a tick, systems must respect a stable ordering:

- World state systems first
- AI and Organization systems second
- Dispatch and Evidence systems third
- Observer and analytics systems last

If a subsystem depends on another subsystem's output, it must consume that output through the Event Bus or an explicitly registered Service interface.

### Scope

The scheduler must preserve the distinction between global and local work:

- Global work runs at the framework level and must be strictly budgeted.
- Local work runs for a specific Territory, Incident, or Scenario and may be more expensive but must be limited to the relevant scope.

---

## Scheduling Contract

Modules register recurring work using the scheduler interface.

```lua
DCE:Schedule("world:layer0:tick", intervalMs, function()
    -- perform bounded work
end)
```

Required behavior:

- The task name must be unique and stable.
- The interval must be configurable.
- The task must be cancellable on shutdown.
- The task must be observable in scheduler metrics.

One-off delayed work may also be scheduled for a specific future event, such as a decay or escalation timer.

---

## Budget and Degradation

The scheduler is responsible for enforcing the performance budget described in the Simulation Budget contract. If a subsystem exceeds its budget:

- the scheduler emits a warning event,
- the affected module may downgrade fidelity,
- and lower-priority work may be skipped until the next tick.

Budget degradation is a last resort and must preserve correctness, not merely reduce visibility.

---

## Lifecycle Expectations

A module that registers recurring work must:

1. register its tasks during startup,
2. cancel its tasks during shutdown,
3. avoid stale references after a restart,
4. emit state changes through the Event Bus where relevant.

The scheduler itself must not retain module-local state after the owning module has stopped.

---

## Observability

The scheduler must expose enough data for the admin dashboard and analytics layer to answer:

- which tasks ran,
- how long each task took,
- whether a task was skipped or deferred,
- and whether the simulation loop remained within budget.

This contract is intentionally lightweight. Implementation details may vary, but every scheduler tick must be measurable.
