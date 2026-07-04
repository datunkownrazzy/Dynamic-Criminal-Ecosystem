# DCE World Engine

**Status:** Accepted
**Version:** 1.0
**Owner:** Datunkownrazzy
**Dependencies:** Architecture Overview, DCE-0001, DCE-0002, Core Overview
---

## Purpose

The World Engine (`dce-world`) is the system that maintains the state everything else in DCE reacts to. It owns Regions (spatial/data structure), the values that make up World State (police presence, civilian density, weather, time, etc.), and the Layer 0/1 simulation ticks that keep those values moving over time. It does not decide what organizations do with that state — that's the AI Director's job (`dce-ai`) — the World Engine's job is to maintain an honest, current picture of the world for the AI Director to read.

---

## Relationship to Other Systems

```
World Engine  ──publishes state──▶  AI Director (dce-ai)
     │                                     │
     │                              scores & decides
     │                                     │
     ▼                                     ▼
Regions / Weather / Time            Organization activity
     ▲                                     │
     └─────────── feeds back ──────────────┘
        (activity affects world state: heat, civilian fear, etc.)
```

The World Engine and the AI Director have a clean separation of concerns:
- **World Engine owns "what is currently true about the world."**
- **AI Director owns "given what's true, what does an organization plausibly do."**

This split matters because it means World Engine has no opinion about organizations at all — a server could theoretically run DCE's World Engine under a completely different AI/decision system, or test the AI Director against synthetic world states, without the two being entangled.

---

## Components Owned by the World Engine

| Component | Spec |
|---|---|
| Simulation Layers (0–3) — promotion/demotion, materialization | `docs/04_Simulation/Simulation_Layers.md` |
| Regions — spatial/data structure for districts | `docs/04_Simulation/Regions.md` |
| Weather — current conditions and their effect on World State | `docs/04_Simulation/Weather.md` |
| Time — day/night cycle and its effect on World State | `docs/04_Simulation/Time.md` |
| Civilian Ambient Simulation (Layer 1) | Own future spec — out of scope for this document |

---

## World State as a Read Model

Other systems (primarily `dce-ai`, but also `dce-dispatch` for context and `dce-ui` for the admin dashboard) should treat World State as a **read model** — something they query or subscribe to, never something they mutate directly. All mutation happens inside `dce-world` itself, in response to its own ticks or in response to Events it subscribes to (e.g., `organization:activity:completed` might nudge a Region's `Heat` value up).

```lua
local World = DCE:GetService("World")
local state = World.GetRegionState("davis")
-- state.policePresence, state.civilianDensity, state.weather, state.time, state.heat, ...
```

Never:
```lua
-- WRONG — dce-ai reaching in and mutating World Engine's owned state directly
World.regions["davis"].heat = World.regions["davis"].heat + 10
```

If another module needs a Region's state to change, it should emit an event describing what happened (e.g., `territory:incident:occurred`), and the World Engine decides how that affects its own state — consistent with Principle #4 (no service depends on another's internals) applied in the other direction: no service should be able to reach in and mutate the World Engine's internals either.

---

## Tick Structure

Per `Scheduler.md`, the World Engine registers its own named, config-interval scheduled tasks rather than ad hoc threads:

```lua
DCE:Schedule("world:layer0:tick", Config.World.Layer0Interval, function()
    -- update statistical values for every Region, cheaply
end)

DCE:Schedule("world:layer1:tick", Config.World.Layer1Interval, function()
    -- update ambient simulation near currently-active players
end)
```

Layer 0 should run for the entire map on every tick; Layer 1 should only evaluate Regions currently near a player (see `Simulation_Layers.md` for the promotion/demotion mechanism that decides this).

---

## Emitted Events (non-exhaustive — full list lives with implementation)

- `world:region:state_changed` — a Region's tracked values changed meaningfully (not necessarily every tick — see debouncing note below)
- `world:weather:changed`
- `world:time:changed` (e.g., crossing into "night" per `Time.md`'s thresholds)
- `world:region:layer_changed` — a Region was promoted/demoted between simulation layers

**Debouncing note:** Layer 0 ticks may run frequently; emitting a full event on every single tick for every Region would flood the Event Bus for little benefit (see the performance guidance in `DCE-0002-Event-Bus.md`). `world:region:state_changed` should be emitted only when a value crosses a meaningful threshold or changes by more than a configured amount, not on every tick regardless of magnitude. Exact thresholds are a config concern (`Config.World.StateChangeEmitThreshold`), not hardcoded.

---

## What the World Engine Explicitly Does Not Do

- It does not decide what an organization does — that's `dce-ai`.
- It does not generate dispatch calls — that's `dce-dispatch`, reacting to events the AI Director or World Engine emit.
- It does not know what a "drug deal" or a "patrol" is — those are AI Director/organization concepts. The World Engine only knows about ambient conditions and generic Simulation Events it's told about.
