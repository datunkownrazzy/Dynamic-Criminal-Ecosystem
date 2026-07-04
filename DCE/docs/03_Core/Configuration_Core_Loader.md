# DCE Configuration (Core Loader)

**Status:** Accepted
**Version:** 1.0
**Owner:** Datunkownrazzy
**Dependencies:** Configuration Philosophy, DCE Core Overview, Logger

---

## Purpose

`Configuration_Philosophy.md` explains *why* config is layered and what must be configurable. This document specifies the actual mechanism `dce-core` provides for loading, layering, and validating config, which every other module builds on.

---

## Loading Order

Per the layers defined in `Configuration_Philosophy.md`, the Config Loader applies, in order (later layers override earlier ones for any overlapping key):

1. **Framework defaults** — hardcoded fallback values shipped inside `dce-core` itself, used only if nothing else specifies a value. These exist so a missing config file doesn't crash the framework, not as the intended way to configure anything.
2. **Simulation Profile** — if `Config.SimulationStyle` is set (`Arcade` / `Balanced` / `Realistic` / `Custom`), the corresponding preset table is applied over the defaults.
3. **Per-module config file** — each resource's own `config.lua`, applied over the above.
4. **Server owner overrides** — an optional `server_overrides.lua` (or per-module override file) that a server owner maintains separately from the shipped config, so upgrades don't silently clobber their customizations (see Upgrade Safety below).

### Accessing Config

```lua
local value = DCE:GetConfig("Territory", "TickInterval")
-- equivalent to a fully-resolved Config.Territory.TickInterval after all layers applied
```

Modules may also just reference their own local `Config` table directly after it's been resolved at load time — `DCE:GetConfig` exists primarily so *other* modules (or the admin dashboard) can inspect a module's effective config without requiring that module's file directly, consistent with the Service Registry pattern in `DCE-0001`.

---

## Validation

Each module is responsible for validating its own config values at startup (per `Configuration_Philosophy.md` — "loud and immediate, not a mystery three days later"). The Core Loader provides small helper functions to make this consistent rather than every module reinventing bounds-checking:

```lua
DCE:ValidateConfig("Territory", {
    TickInterval = { type = "number", min = 1000 },
    BaseInfluenceDecay = { type = "number", min = 0, max = 100 },
})
```

If validation fails, the Core Loader logs an `error` via the Logger (`Logger.md`) naming the exact key and the problem, and the module should refuse to activate that specific feature rather than proceeding with a clamped or guessed value — silent clamping hides real misconfigurations from server owners.

---

## Upgrade Safety

Because DCE ships with default config files that server owners will edit, a version upgrade must not silently overwrite those edits. The convention:

- Shipped files (`config.lua` in each resource) are treated as **replaceable on update** — server owners are expected to not hand-edit these directly for anything they want to survive an upgrade.
- A separate, gitignored-by-convention `server_overrides.lua` (or equivalent per-resource override file) is where server owners put persistent customizations. This file is never touched by an update.

This should be stated clearly in each resource's own README so it doesn't have to be rediscovered painfully during a server's first update.

---

## Hot-Reloading (Scoped for v1.0)

Full hot-reload of config without a resource restart is **not** a v1.0 requirement (see `Goals.md` deferred list doesn't explicitly list this, but it follows the same reasoning — ship the mechanism simply first). For v1.0:

- Config is loaded once at each resource's startup.
- Changing a config value requires restarting that resource.
- Modules must handle being restarted cleanly regardless (per `Lifecycle_and_Dependency_Injection.md`), so this isn't a new requirement — just a reminder that "restart the resource" is currently the supported way to apply a config change.

A true hot-reload path (admin dashboard edits a value, module picks it up live) is a reasonable v1.5+ enhancement once the Scheduler and Service patterns have proven out in practice — flag as a future ADR rather than guessing at the mechanism now.

---

## API Surface

```lua
DCE:GetConfig(moduleName, key) -> value

DCE:ValidateConfig(moduleName, schema) -> boolean, errors

DCE:GetSimulationProfile() -> "Arcade" | "Balanced" | "Realistic" | "Custom"
```

## Consequences

- Requires every module to structure its own `config.lua` in a way the loader can layer predictably (flat-ish tables keyed by the module's own name) — worth codifying a small config-file template in `/examples/` once the first real module is built, so this isn't reverse-engineered per-module.
- The override-file convention adds one more file per module for server owners to be aware of, in exchange for upgrade safety that avoids the much worse failure mode of "the update wiped my custom probabilities."
