# DCE Simulation Layers

**Status:** Accepted
**Version:** 1.0
**Owner:** Datunkownrazzy
**Dependencies:** World Engine, Architecture Overview, Scheduler

---

## Purpose

This document specifies the four-layer simulation model referenced throughout the higher-level docs (`Architecture_Overview.md`, `Goals.md`) in concrete terms: what triggers a promotion or demotion between layers, what "materializing" actually means mechanically, and who owns that decision.

---

## The Four Layers

| Layer | Scope | What exists | Owning system |
|---|---|---|---|
| 0 — Statistical | Entire map | No NPCs. Numbers only. | `dce-world` |
| 1 — Ambient | Near players | Flavor NPCs/vehicles, not yet interactive incidents | `dce-world` |
| 2 — Interactive | Player-affectable events in progress | Full Scenario state, but not necessarily an active dispatch Incident yet | `dce-ai` |
| 3 — Major Incident | Escalated, player-interactive | Full AI, dispatch, evidence fidelity | `dce-ai`, `dce-dispatch`, `dce-evidence` |

A Region (see `Regions.md`) is always being simulated at *some* layer for its overall statistics (Layer 0 never stops), while individual Scenarios within it can independently be at Layer 1, 2, or 3 depending on player proximity and escalation state. Layer is a property of the entity (Region-wide simulation, or an individual Scenario/Agent), not a single global setting for the whole server.

---

## Promotion: Layer 0 → Layer 1 (Materialization)

**Trigger:** A player enters within `Config.World.AmbientRadius` of a Region that currently has simulated (but not yet materialized) organizational activity.

**What happens:**
1. The World Engine checks the Region's current statistical state (influence, heat, active organization presence).
2. Based on that state, it spawns appropriate ambient Agents — patrols, corner dealers, lookouts — consistent with what the statistics say *should* be happening there, not randomly.
3. These Agents run lightweight ambient behavior (per `Regions.md` / a future Civilian/Ambient AI spec) but do not yet constitute an interactive Scenario.

**Cost consideration:** This is the first point actual NPCs exist, so it must only happen near players — never map-wide. See `Config.World.AmbientRadius` and the Layer 0 tick guidance in `World_Engine.md`.

---

## Promotion: Layer 1 → Layer 2 (Scenario Begins)

**Trigger:** The AI Director (`dce-ai`), evaluating an Organization's goals against current World State, selects an activity to actually execute near a materialized Region (e.g., a drug sale is scored highly and chosen).

**What happens:**
1. `dce-ai` creates a Scenario instance (see `DCE-0002` event `organization:activity:started`) using the Event Escalation structure appropriate to that activity type.
2. The Scenario begins progressing through its stages (Planning → Travel → Preparation → Execution → ...).
3. Materialized Agents from Layer 1 may now be assigned roles in the Scenario (e.g., an ambient corner dealer becomes the actual dealer in a specific drug sale Scenario) rather than spawning entirely new Agents redundantly.

At this stage, the Scenario is player-affectable in principle (a player could walk up and interrupt it) but has not necessarily generated a Dispatch call yet — consistent with early escalation stages being dispatch-silent (see the Event Escalation examples in earlier design docs / the future `dce-ai` Event Escalation spec).

---

## Promotion: Layer 2 → Layer 3 (Incident)

**Trigger:** The Scenario's escalation reaches a stage explicitly flagged (in its Event Escalation data) as dispatch-triggering — e.g., "shots fired," "alarm triggered."

**What happens:**
1. `dce-dispatch` is notified (via Event Bus, e.g. `scenario:escalation:dispatch_triggered`) and generates a Dispatch call through the active adapter.
2. `dce-evidence` begins tracking anything the Scenario produces from this point (and potentially retroactively, depending on the Scenario type — e.g., earlier-stage evidence like a parked vehicle might already exist).
3. The Scenario is now a full Incident: fully simulated, fully interactive, subject to player and AI (police NPC, if applicable) intervention.

---

## Demotion

Demotion happens in the reverse direction and is just as important for performance as promotion:

- **Layer 3 → Layer 2/lower:** Once an Incident resolves (arrest, escape, timeout) and no player remains nearby, `dce-dispatch`/`dce-evidence` stop actively simulating it at full fidelity. Final state (outcome, any surviving evidence) is handed back to `dce-ai`/`dce-world` to fold into Organization memory and Region statistics.
- **Layer 1 → Layer 0:** When no player remains within `Config.World.AmbientRadius` of a Region for longer than `Config.World.AmbientLingerTime`, materialized ambient Agents despawn, and the Region returns to pure statistical simulation. `Config.World.AmbientLingerTime` should be nonzero — demoting instantly the moment a player looks away causes visible pop-in/pop-out and should be avoided.

**Rule:** Nothing should remain materialized (Layer 1+) indefinitely just because it once had a player nearby. Every layer above 0 must have a clear, config-driven condition for falling back down, or the "keep CPU cost low away from players" goal (`Architecture_Overview.md`, `PROJECT_PRINCIPLES.md` #7) silently erodes over a long server uptime as more and more things get stuck materialized.

---

## Ownership of the Promotion/Demotion Decision

To avoid two systems fighting over whether something should be materialized, exactly one system decides for each transition:

| Transition | Decided by |
|---|---|
| 0 → 1 | `dce-world` (proximity-based, doesn't need AI Director input) |
| 1 → 2 | `dce-ai` (this is an actual AI Director decision, not just proximity) |
| 2 → 3 | Whatever Scenario/Event Escalation data says (data-driven, not a hardcoded system decision) |
| Any → lower | The system currently owning that layer's simulation (see Demotion above) |

---

## API Surface (World Engine side)

```lua
World.GetRegionLayer(regionId) -> 0 | 1 -- overall Region ambient layer
World.IsPlayerNear(regionId, radius) -> boolean

-- Emitted, not called directly by consumers:
-- "world:region:layer_changed" { regionId, fromLayer, toLayer }
```

(Layer 2/3 transitions are owned by `dce-ai`/`dce-dispatch`/`dce-evidence` respectively and documented in their own future specs — referenced here for completeness of the overall model.)
