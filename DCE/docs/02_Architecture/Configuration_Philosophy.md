# DCE Configuration Philosophy

**Status:** Accepted
**Version:** 1.0
**Owner:** Datunkownrazzy
**Dependencies:** PROJECT_PRINCIPLES.md, Philosophy.md

---

## Purpose

This document establishes how configuration works across DCE and why it's structured the way it is. Individual modules will document their own specific config keys in their own specs; this document covers the shared conventions and reasoning so config stays consistent as more modules are added.

---

## Config Is How Server Owners Express Intent

Per `Philosophy.md`: "Configuration is a UI, not an escape hatch." A server owner running a slow-burn, heavy-roleplay server and one running a fast-paced action server should both be well served by DCE, and the thing that lets that happen is configuration — not forked code. Every module's design should be checked against: *could two very differently-paced servers both be happy with this, given only config changes?*

---

## Layered Config Structure

Configuration is split into layers, from most general to most specific, so a server owner can change broad behavior in one place without having to edit dozens of files:

1. **Global simulation profile** — one top-level setting (e.g., `Config.SimulationStyle = "Balanced"` — see "Simulation Profiles" below) that adjusts many underlying defaults at once.
2. **Per-module config** — each resource (`dce-world`, `dce-ai`, `dce-dispatch`, etc.) has its own `config.lua` with its own tunables, following the naming conventions in `Coding_Standards.md`.
3. **Per-organization / per-territory data** — personality weights, starting resources, and territory definitions live in data files (see `/schemas/` for format examples), not in module config, because they describe *content* (which organizations exist and how they behave) rather than *framework behavior*.
4. **Plugin config** — a plugin ships its own config following the same conventions; it must not require editing core config files to function.

### Simulation Profiles

A small number of named presets (`Arcade`, `Balanced`, `Realistic`, `Custom`) exist as a convenience layer over per-module config, not as a replacement for it. Selecting `Realistic` should set a batch of underlying values (event frequency, escalation aggressiveness, persistence weighting) to sensible defaults for that style; a server owner can still override any individual value afterward under `Custom`, or after selecting a named preset. Presets are sugar, not a separate code path — under the hood, a preset is just a table of config overrides applied before per-module config loads.

---

## What Must Be Configurable

At minimum, per `PROJECT_PRINCIPLES.md` #2 and #8, the following categories must be config-driven in every module that has them, not hardcoded:

- Tick/update intervals
- Probabilities and thresholds (success chances, escalation odds, decay rates)
- Feature toggles (can this module's subsystem be disabled independently — see below)
- Anything that differs meaningfully between a "quiet" and "chaotic" server

## Feature Toggles

Per Principle #3 (every feature is optional), every module should expose an `Enabled` flag, and every module must handle its own dependencies being disabled without crashing (this is the same concern as `Lifecycle_and_Dependency_Injection.md`'s missing-service handling, applied to intentional, config-driven disabling rather than just startup race conditions).

```lua
Config.Enabled = true
```

A module with `Enabled = false` should not register its Service, should not subscribe to events, and should not tick — it should behave as if the resource were never started, from the rest of DCE's perspective, while still being present so an admin can re-enable it without a restart if the module supports hot-reload (not required for v1.0, but shouldn't be architecturally precluded).

---

## Config Validation

Every module should validate its own config at startup (Declare/Register phase, per `Lifecycle_and_Dependency_Injection.md`) and log clear, specific warnings for invalid values (e.g., a probability outside 0–100, a negative tick interval) rather than silently clamping or crashing later during simulation. A bad config value should be loud and immediate, not a mystery three days later.

---

## Config vs. Data: Where's the Line?

This distinction matters enough to state explicitly, because it's easy to blur:

- **Config** describes *how the framework behaves* — tick rates, probabilities, toggles. It's the same shape regardless of what content is loaded.
- **Data** describes *what content exists* — which organizations, which territories, which escalation chains, their specific stats and weights. It's what actually varies between two servers' unique "worlds," and follows the schemas defined in `/schemas/`.

A new organization should never require a code change or a config schema change — it's a new data file. A new *kind* of tunable behavior (e.g., introducing a wholly new mechanic) is a config/code change, appropriately gated behind its own spec and versioning.

---

## Consequences

- Slightly more indirection for module authors (checking `Config.Enabled`, pulling values instead of inlining constants) in exchange for a framework that genuinely serves different server styles without forking.
- Config sprawl risk — as more modules ship, the number of config files grows. The Simulation Profile layer exists specifically to keep the *common* case simple (pick a preset) while leaving the *detailed* case fully available for server owners who want it.
