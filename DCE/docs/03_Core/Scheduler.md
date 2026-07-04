# DCE Scheduler

**Status:** Accepted
**Version:** 1.0
**Owner:** Datunkownrazzy
**Dependencies:** DCE Core Overview, Configuration Philosophy

---

## Purpose

Every module in DCE needs to run recurring work — Layer 0 statistical ticks, ambient simulation checks, evidence decay, etc. The Scheduler centralizes how that recurring work is registered, named, timed, and measured, instead of every module managing its own raw `CreateThread`/`Wait` loop independently.

This directly supports the performance-observability goals in `Architecture_Overview.md` and `Goals.md` — you can't show "AI: 0.46ms per tick" in an admin dashboard if nothing is tracking which named piece of work took how long.

---

## Design

### Registering a Recurring Task

```lua
DCE:Schedule("territory:tick", Config.TerritoryTickInterval, function()
    -- runs every Config.TerritoryTickInterval ms
end)
```

- The first argument is a unique task name, following the same `domain:subject` style as event names (see `DCE-0002`), used for logging and the performance monitor.
- The interval is expected to come from that module's own `Config`, per `Configuration_Philosophy.md` — never a bare hardcoded number.
- The Scheduler measures execution time for each task automatically and makes it available via `DCE:GetSchedulerStats()` for the (future) admin performance monitor described in `Architecture_Overview.md`.

### One-Off Delayed Tasks

```lua
DCE:ScheduleOnce("evidence:decay:check:" .. evidenceId, 30000, function()
    -- runs once, 30s from now
end)
```

Useful for things like a single evidence item's next decay check, where a full recurring task per item would be wasteful to track individually forever.

### Cancelling

```lua
local taskId = DCE:Schedule("territory:tick", interval, fn)
DCE:CancelSchedule(taskId)
```

Modules must cancel their scheduled tasks on `onResourceStop`, per the shutdown requirements in `Lifecycle_and_Dependency_Injection.md`. A scheduled task referencing a torn-down module's state is a common source of post-restart errors.

### Interval Changes at Runtime

If a config value changes at runtime (e.g., an admin adjusts `TerritoryTickInterval` via the dashboard), the owning module is responsible for cancelling and re-registering its own task with the new interval — the Scheduler does not watch config for changes on a module's behalf. This keeps the Scheduler simple and keeps "who's responsible for reacting to config changes" unambiguous (the module that owns the config, always).

---

## Layer-Awareness

Per the Simulation Layers described in `Architecture_Overview.md`, tasks differ enormously in scope and frequency:

- Layer 0 (statistical) tasks tend to run frequently but do very little per organization — cheap, wide.
- Layer 3 (major incident) tasks tend to run less frequently but do meaningfully more per call — expensive, narrow, and usually scoped to a specific active incident rather than the whole map.

The Scheduler doesn't enforce this distinction structurally, but task names should make it visually obvious which layer a task belongs to (e.g., `world:layer0:economy:tick` vs. `incident:<id>:escalation:tick`) so the performance monitor's breakdown is actually legible to whoever's reading it.

---

## What the Scheduler Is Not

- It is not a distributed job queue — everything runs in-process, same as raw FiveM threads.
- It does not guarantee sub-millisecond precision; it's built on the same `Wait()`-based timing FiveM already uses, just with consistent naming and measurement wrapped around it.
- It does not replace one-off use of raw `CreateThread` for something that isn't really "recurring scheduled work" (e.g., a single long-running blocking operation) — use judgment; the Scheduler is specifically for the "this needs to happen every N ms, and I want visibility into its cost" case.

---

## API Surface

```lua
DCE:Schedule(name, intervalMs, fn) -> taskId
DCE:ScheduleOnce(name, delayMs, fn) -> taskId
DCE:CancelSchedule(taskId)
DCE:GetSchedulerStats() -> { [taskName] = { lastRunMs = ..., avgRunMs = ..., intervalMs = ... }, ... }
```

## Consequences

- Slightly more ceremony than a bare `CreateThread` loop, in exchange for every recurring task in the framework being nameable, measurable, and cancelable through one consistent interface — which is what makes the admin performance panel and orderly shutdown behavior possible at all.
