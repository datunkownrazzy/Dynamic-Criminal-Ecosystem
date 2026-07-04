# DCE World Persistence

**Status:** Draft — pending review
**Version:** 1.0
**Owner:** Architecture
**Dependencies:** DataOwnership, Configuration_Core_Loader, Organizations, Territories, Economy, Evidence, Regions

---

## Purpose

Per `Goals.md` v1.0 requirement #5, DCE must survive a server restart with no loss of simulation state. This document specifies the mechanism — not the specific column-by-column schema for every module (each owning Service defines its own schema, per `DataOwnership.md`), but the shared contract every persistable Service follows so save/load behaves predictably across the whole framework.

This is the missing piece referenced but never specified in `Configuration_Core_Loader.md` and required by `StateMachine.md`'s shutdown rules ("finalize state in a way that allows clean resource restart").

---

## What Must Persist

Per `Goals.md` and `DataOwnership.md`'s ownership matrix, the following domains are persistence-critical for v1.0:

| Domain | Owning Service | Examples of persisted fields |
|---|---|---|
| Organization state | `Organizations` (within `dce-ai`, per ADR-0001) | money/wealth ledger (pending the ownership ADR flagged in the last review), members, vehicles, safehouses, heat, influence, morale, state |
| Territory state | `Territories` | ownership, influence-per-organization, lifecycle stage |
| Economy state | `Economy` | Illicit Funds, Operating Budget, laundering throughput |
| Evidence records | `Evidence` (Evidence Registry) | evidence records, custody chain, confidence metadata, investigation graph links |
| Investigation state | `Investigations` | case files, tier, linked evidence, status |
| World/Region runtime state | `World` | per-Region influence/heat/violence values (not ambient NPCs — those are ephemeral, see below) |

**Explicitly NOT persisted:** anything that is regenerated cheaply on demand — materialized Layer 1 ambient Agents, active Layer 2/3 Scenario NPCs, in-progress pathing state. Per `Simulation_Layers.md`, these rematerialize from persisted statistical state on the next server start; persisting them directly would be redundant and would fight with the layer-demotion model.

---

## Ownership Rule

Consistent with `DataOwnership.md` principle #1 ("each domain of state has exactly one authoritative owner"): **each Service persists only its own state.** There is no central "save everything" god-function that reaches into every module's tables. Persistence is a responsibility each Service already has, exercised through its own save/load functions, coordinated by a shared scheduling/timing contract (below) — not a separate system that knows about everyone else's internals.

```lua
-- Each owning Service implements its own persistence, e.g.:
local Organizations = DCE:GetService("Organizations")
Organizations.SaveState()   -- Organizations decides its own schema/serialization
Organizations.LoadState()   -- called during that module's own Starting phase
```

`dce-core` does not provide a generic "persist this table" helper that bypasses Service boundaries — that would recreate exactly the cross-module coupling `DataOwnership.md` exists to prevent. What `dce-core` does provide is a shared **Persistence Coordinator** (below) that tells every registered persistable Service *when* to save, without touching *what* they save.

---

## Persistence Coordinator

A lightweight core service (`dce-core`) that:

1. Maintains a registry of Services that have declared themselves persistable (`DCE:RegisterPersistable(serviceName, saveFn, loadFn)`).
2. Triggers `loadFn` for every registered persistable Service during startup, in dependency order established by each module's own `Lifecycle` phases (per `Lifecycle_and_Dependency_Injection.md`) — Persistence Coordinator does not impose its own separate ordering.
3. Triggers `saveFn` on a config-driven interval (`Config.Persistence.AutosaveIntervalMs`) and on `onResourceStop`/graceful server shutdown.
4. Exposes `DCE:ForceSaveAll()` for admin-triggered manual saves.

```lua
DCE:RegisterPersistable("Organizations", Organizations.SaveState, Organizations.LoadState)
```

This mirrors the Service Registry pattern (`DCE-0001`) deliberately — registration by name, resolved generically, no module needing to know about any other module's persistence details.

---

## Storage Backend

Per the tech stack decision in the original project brief, persistence uses **SQL via oxmysql**, consistent with everything else in the framework rather than introducing a second storage mechanism (e.g., JSON files) for some modules and SQL for others. All database access is async (`AGENTS.md` rule #8, `Coding_Standards.md`) — no synchronous queries during a save/load cycle, including at startup, since blocking startup on a slow synchronous query would delay every dependent Service's `Starting` phase.

Each Service's schema lives in its own migration file under `/src/<resource>/migrations/` (or equivalent), not in a shared central schema file — this follows the same single-owner principle as everything else.

---

## Save Timing and Data Loss Window

- **Autosave interval** (`Config.Persistence.AutosaveIntervalMs`) — default should favor a conservative window (e.g., 5 minutes) balanced against the async write cost of the busiest Service (likely Evidence, given volume).
- **Graceful shutdown save** — `onResourceStop`/server shutdown triggers an immediate full save across all registered persistables before the process exits, per the shutdown requirements in `StateMachine.md`.
- **Crash recovery** — a hard crash between autosaves will lose state changed since the last autosave. This is an accepted, documented limitation for v1.0, not something DCE attempts to fully solve (e.g., via write-ahead logging) — flag as a possible v1.5+ enhancement rather than a v1.0 requirement, consistent with `Goals.md`'s deferred-scope philosophy.

---

## Load Failure Handling

If a Service's `LoadState()` fails (corrupted data, schema mismatch after an update, missing table), that Service must:

- Log an `error` via the Logger (`Logger.md`) naming exactly what failed.
- Fall back to a safe default/empty state rather than crashing the whole framework — consistent with `StateMachine.md`'s `Failed` state handling (the Service enters `Failed`, not the entire server).
- Emit `persistence:load:failed` — `{ serviceName, reason }` so the admin dashboard (`Admin_UI.md`) can surface it prominently rather than it being silently swallowed in server console scrollback.

A framework-wide crash on one module's bad save data would violate `PROJECT_PRINCIPLES.md` #3 (every feature is optional) in spirit — one corrupted table shouldn't take down organizations, territories, and evidence together.

---

## Versioned Schema Migrations

Each persistable Service tracks its own schema version and provides a migration path when that version changes between DCE releases, consistent with the backwards-compatibility discipline in `Coding_Standards.md`/`AGENTS.md` rule #14. A schema version bump without a migration path is a breaking change and needs an ADR, same as any other breaking change to a public contract.

---

## Emitted Events

- `persistence:save:completed` — `{ serviceName, durationMs }`
- `persistence:load:completed` — `{ serviceName, durationMs }`
- `persistence:load:failed` — `{ serviceName, reason }`
- `persistence:autosave:triggered` — `{ timestamp }`

---

## API Surface

```lua
DCE:RegisterPersistable(serviceName, saveFn, loadFn)
DCE:ForceSaveAll()
DCE:GetPersistenceStatus() -> { [serviceName] = { lastSaveAt, lastLoadAt, status }, ... }
```

## What This Document Does Not Cover

- The exact SQL schema for any individual Service's data — that belongs in each Service's own specification and migration files.
- Cross-server/cluster persistence — explicitly deferred in `Goals.md` and the v3.0 roadmap.
