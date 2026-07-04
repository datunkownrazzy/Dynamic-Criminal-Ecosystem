# DCE Weather

**Status:** Accepted
**Version:** 1.0
**Owner:** Architecture
**Dependencies:** World Engine, Regions, Configuration Philosophy

---

## Purpose

Weather is one of the environmental inputs to World State that the AI Director uses when scoring possible activities (per the scoring examples in the original design conversations — e.g., rain reducing patrols, fog raising ambush likelihood). This document specifies how DCE tracks weather and how it's exposed, without prescribing exactly how a given activity's score reacts to it (that belongs in the AI Director's own scoring configuration, since it's data-driven per `PROJECT_PRINCIPLES.md` #2).

---

## Source of Weather Data

DCE does not invent its own weather simulation. It reads current weather from whatever weather-sync resource is already running on the server (most FiveM servers already run one for visual/sync purposes). The World Engine wraps this through the same Integration Manager adapter pattern used for Dispatch/MDT (see `Architecture_Overview.md`), rather than assuming one specific weather resource is installed.

```lua
-- Conceptual, actual adapter mechanism follows the same pattern as dce-integrations
local currentWeather = WeatherAdapter.GetCurrentWeather() -- e.g. "RAIN", "CLEAR", "FOGGY", "THUNDER"
```

If no recognized weather resource is installed, DCE falls back to a simple internal weather cycle (config-driven — see below) so that weather-dependent scoring still has something to react to, consistent with the "graceful fallback" pattern used elsewhere in Integration Manager design.

---

## Normalized Weather Categories

Because different weather resources use different naming/enumerations, the World Engine normalizes incoming weather into a small, fixed set of categories that the rest of DCE reasons about, rather than every consumer needing to know every possible upstream weather string:

| DCE Category | Typical mapped upstream states |
|---|---|
| `Clear` | Clear, Extra Sunny, Clouds |
| `Rain` | Rain, Thunder |
| `Fog` | Foggy, Smog |
| `Storm` | Thunder (heavy), Blizzard (if applicable to the server's setting) |

The exact mapping table is config (`Config.Weather.CategoryMap`), not hardcoded, since different weather resources use different string names and a server owner integrating an unrecognized one should be able to fix the mapping without a code change.

---

## Exposure to World State

```lua
local World = DCE:GetService("World")
World.GetCurrentWeather() -> "Clear" | "Rain" | "Fog" | "Storm"
```

This is a single global value (weather is not currently modeled per-Region — FiveM weather sync is typically server-wide). If per-Region weather ever becomes relevant to a future feature, that's a breaking change to this API and would need an ADR.

## Emitted Events

```
"world:weather:changed" { from = "Clear", to = "Rain" }
```

Emitted only on category change, not on every tick — consistent with the debouncing guidance in `World_Engine.md`.

---

## Effect on Simulation (Guidance, Not Hardcoded Rule)

Per `PROJECT_PRINCIPLES.md` #2, DCE core does not hardcode "rain reduces patrols by X%" anywhere. Instead, the AI Director's per-activity scoring configuration (documented in its own future spec) includes weather as one of several optional scoring modifiers a Scenario/Behavior definition can reference, e.g.:

```json
{
  "activity": "patrol",
  "modifiers": {
    "weather": { "Rain": -10, "Storm": -25 }
  }
}
```

This document exists so `dce-ai` (and any plugin author writing new Behaviors) knows weather is available as a modifier input and what categories it can rely on — not to prescribe specific weights, which are content/tuning decisions, not architecture.

---

## Fallback Internal Cycle (No Weather Resource Installed)

```lua
Config.Weather.Fallback = {
    Enabled = true,
    CycleMinutes = 45,
    Sequence = { "Clear", "Clear", "Rain", "Clear", "Fog" },
}
```

A simple, config-driven rotation — not intended to be realistic, just enough that weather-dependent scoring has non-constant input on a server that hasn't installed a dedicated weather resource. If `Enabled = false`, `GetCurrentWeather()` always returns `Config.Weather.Fallback.DefaultValue` (default `"Clear"`).

---

## API Surface

```lua
World.GetCurrentWeather() -> string (normalized category)
World.SetWeatherOverride(category) -- admin/debug use, forces a value regardless of adapter/fallback
World.ClearWeatherOverride()
```
