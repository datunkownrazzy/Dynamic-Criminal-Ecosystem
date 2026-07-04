# DCE Admin UI

**Status:** Draft — pending review
**Version:** 1.0
**Owner:** Architecture
**Dependencies:** Architecture_Overview, SimulationScheduler, SimulationBudget, Persistence, Logger, DataOwnership
**Drop into:** `docs/14_Admin/Admin_UI.md`

---

## Purpose

`Architecture_Overview.md` names `dce-ui`/`dce-admin` as planned resources and lists their intended tooling (Live World Inspector, developer console, performance monitor, analytics dashboard), but no document specifies how they're built, what they're allowed to touch, or how they relate to the rest of the framework. This document fills that gap for v1.0's required scope, per `Goals.md` requirement #7 ("Baseline admin visibility").

---

## Core Principle: Admin UI Observes, It Does Not Simulate

Per `Architecture_Overview.md`: *"Their job is to observe and configure, not to participate in the simulation loop directly."* This document exists to make that boundary concrete:

- `dce-ui`/`dce-admin` **read** state through the same Service Registry (`DCE-0001`) every other module uses — no special back-door access to internal tables.
- `dce-ui`/`dce-admin` **write** only through the same owning-Service action methods any other module would use (per `DataOwnership.md`'s Change Request Pattern) — an admin editing a Territory's influence in the dashboard calls `Territories`'s documented mutation method, it does not reach into `Territories`'s internal state directly just because it's "the admin panel."
- No simulation logic (scoring, escalation, decay) lives in `dce-ui`/`dce-admin`. If the dashboard needs a derived value, it asks the owning Service for it; it does not recompute simulation logic itself.

This keeps the admin surface from becoming a second, informal way to bypass the architecture — a common failure mode where "it's just the debug panel" quietly grows into a load-bearing shortcut.

---

## v1.0 Required Scope (per `Goals.md` #7)

1. **Organization overview** — list of current Organizations and key stats (money/wealth, per whichever ownership model the pending finance ADR settles on; members; heat; state).
2. **Active Incidents view** — currently running Layer 3 incidents, their stage, and location.
3. **Performance metrics** — per-system tick cost, sourced from the Scheduler (`Scheduler.md`, `SimulationScheduler.md`) and Budget contract (`SimulationBudget.md`).

Everything else described below (Live World Inspector, developer console, full analytics, World Chronicle) is **explicitly deferred** past this minimum, consistent with `Goals.md`'s "Explicitly Deferred" list — noted here as the target shape to build toward, not a v1.0 requirement.

---

## Live World Inspector (deferred beyond v1.0 minimum, documented for future work)

Referenced throughout the original design conversations and `Architecture_Overview.md`. Click any Agent/Organization/Territory and see:

- Current goal/state
- The AI Director's scoring breakdown for its last decision (per `AIDirector.md` section 4 — the composite score `S` and its contributing modifiers/deterrents)
- Risk/escalation percentages

This is a **read-only view** built entirely from existing Service query methods (`Organizations.GetState`, `AIDirector`'s decision log, `Territories.GetInfluence`, etc.) — it does not require new simulation-side APIs beyond exposing the AI Director's scoring trace, which should already exist for debugging purposes per `Coding_Standards.md`'s "legible why" requirement.

---

## Developer Console

Text-command interface (`dce.debug <system>`, e.g. `dce.debug territory davis`, `dce.debug gang families`) referenced in `Architecture_Overview.md`. Implementation notes:

- Each module can register its own debug subcommand (`DCE:RegisterDebugCommand("territory", handlerFn)`) rather than the console needing built-in knowledge of every module — same registration pattern as everything else in the framework.
- Console output goes through the shared Logger (`Logger.md`), not a separate print mechanism, so debug output is filterable and consistent with the rest of the framework's logging.
- Restricted to admin permission level — this is a data-exposure surface (safehouse locations, org finances, investigation state) and must not be reachable by non-admin players.

---

## Performance Monitor

Sources data directly from:
- `DCE:GetSchedulerStats()` (`Scheduler.md`)
- The Budget contract's per-layer categories (`SimulationBudget.md`)

Displays per-system tick cost and flags any system currently exceeding its configured budget (per `SimulationBudget.md`'s degradation rules — the dashboard surfaces the warning event `SimulationScheduler.md` already specifies being emitted; it does not independently decide what counts as "too slow").

---

## Analytics Dashboard (deferred beyond v1.0 minimum)

Aggregates data from emitted events across the framework (crime/hour, gang income, most dangerous district, arrests, average pursuit length) as described in the original design conversations. Because this only consumes Events (`DCE-0002`/`EventContracts.md`) rather than needing direct Service access, it can be built as a pure event-listener without touching module internals at all — worth noting as the cleanest possible admin feature to build, architecturally, since it needs zero special access.

---

## World Chronicle (deferred, per `Goals.md`)

Noted here only for completeness — a persistent, searchable event log. Not required for v1.0. When built, it should be an event-listener like Analytics, not a Service with write access to other modules' state.

---

## Integration Health Panel

Surfaces the status already described in `IntergrationManager.md` (Active/Fallback/Diagnostic states for detected CAD/MDT/Evidence/Inventory adapters) and `Persistence.md`'s load-failure events. This is the natural home for `persistence:load:failed` events (see `Persistence.md`) — a corrupted save on one Service should be visible here immediately, not buried in console scrollback.

---

## Permissions Model

All Admin UI/console functionality is gated behind a configurable permission check (`Config.Admin.PermissionCheck`, a function reference so it can integrate with whatever ACE/permission framework the server already uses — same "don't hardcode a specific framework" philosophy as the CAD/MDT adapter pattern in `IntergrationManager.md`). No hardcoded dependency on a specific permissions resource.

---

## Emitted Events

- `admin:action:executed` — `{ adminId, action, target }` (audit trail — who changed what)
- `admin:dashboard:opened` / `admin:dashboard:closed`

The audit event above matters specifically because Admin UI has write access to sensitive state (finances, territory ownership) — every mutation performed through the dashboard should be attributable, for the same reason financial and territory mutations elsewhere in the framework are already event-logged.

---

## What This Document Does Not Cover

- The exact NUI/HTML implementation — that's an implementation detail of `dce-ui`, not an architectural concern.
- Any new simulation capability — Admin UI must not introduce a Service method that only it uses; if it needs a query, that query should be generally useful and belong on the owning Service's public interface, not admin-only.
