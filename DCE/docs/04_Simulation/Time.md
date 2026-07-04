# DCE Time

**Status:** Accepted
**Version:** 1.0
**Owner:** Datunkownrazzy
**Dependencies:** World Engine, Regions, Configuration Philosophy

---

## Purpose

Time of day is the other major environmental input to World State scoring (alongside Weather), referenced throughout the original design conversations — e.g., higher crime after 9 PM, lower activity around 4 AM, different plausible activities at 2 PM vs. 2 AM. This document specifies how DCE tracks and exposes time, following the same "normalize and expose, don't hardcode behavior" approach as `Weather.md`.

---

## Source of Time Data

Same pattern as Weather: DCE reads the server's existing game clock/time-sync resource (most FiveM servers already run one) rather than maintaining a separate clock. Wrapped through the Integration Manager adapter pattern.

```lua
local currentHour = TimeAdapter.GetCurrentHour() -- 0–23
```

If no time-sync resource is installed, the World Engine falls back to reading FiveM's native `GetClockHours()`/`NetworkGetServerTime`-style APIs directly, or a simple config-driven internal cycle if even that isn't meaningful in context — same fallback philosophy as Weather.

---

## Normalized Time Bands

Rather than every consumer reasoning in raw hour-of-day, the World Engine exposes named bands, config-defined so a server can adjust what counts as "night" for its own setting:

```lua
Config.Time.Bands = {
    { name = "Morning",   startHour = 6,  endHour = 11 },
    { name = "Afternoon", startHour = 11, endHour = 17 },
    { name = "Evening",   startHour = 17, endHour = 21 },
    { name = "Night",     startHour = 21, endHour = 2  }, -- wraps past midnight
    { name = "LateNight", startHour = 2,  endHour = 6  },
}
```

```lua
World.GetCurrentTimeBand() -> "Morning" | "Afternoon" | "Evening" | "Night" | "LateNight"
World.GetCurrentHour() -> 0-23
```

Both raw hour and named band are exposed — the AI Director's scoring modifiers (see below) will typically use the band, but a Behavior author may occasionally need finer granularity than the band gives.

---

## Emitted Events

```
"world:time:band_changed" { from = "Evening", to = "Night" }
```

Emitted only on band transition, not every tick, consistent with debouncing guidance in `World_Engine.md`. Raw hour changes are not emitted as events at all — a consumer needing per-hour precision should poll `World.GetCurrentHour()` from within its own scheduled tick rather than expect an event per hour.

---

## Effect on Simulation (Guidance, Not Hardcoded Rule)

Same principle as Weather: DCE core does not hardcode "night increases drive-bys by X%." The AI Director's per-activity scoring configuration includes time band as an available modifier:

```json
{
  "activity": "drive_by",
  "modifiers": {
    "timeBand": { "Night": 20, "LateNight": 10, "Afternoon": -30 }
  }
}
```

This lets a server owner (or plugin author adding a new Behavior) decide exactly how time-sensitive their content is, rather than DCE core baking in an opinion about what "feels realistic."

---

## Interaction With Weather

Time and Weather are tracked independently and both feed the same scoring mechanism as separate modifier keys — they are not combined into a single compound value by the World Engine itself. If a Behavior wants "rain at night is especially good for X," that's expressed as two separate modifier lookups combined by the AI Director's scoring formula (documented in its own future spec), not as a special `RainyNight` category invented at the World Engine level. Keeping Time and Weather orthogonal here avoids a combinatorial explosion of named states as more environmental factors get added later.

---

## API Surface

```lua
World.GetCurrentHour() -> number (0-23)
World.GetCurrentTimeBand() -> string
World.SetTimeOverride(hour) -- admin/debug use
World.ClearTimeOverride()
```
