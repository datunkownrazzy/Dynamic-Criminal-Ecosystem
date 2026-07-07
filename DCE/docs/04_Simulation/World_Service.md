# World Service

## Overview

The World Service maintains world state, regions, and layer simulation. Other systems query this through the Service Registry — they never mutate it directly. The service provides both Layer 0 (statistical) and Layer 1 (ambient) simulation ticks.

## Resource Location

`src/dce-world/services/world.lua`

## Service Registration

```lua
DCE.RegisterService("World", {
    GetRegionState = function(regionId) return DCEWorldService.GetRegionState(regionId) end,
    GetAdjacentRegions = function(regionId) return DCEWorldService.GetAdjacentRegions(regionId) end,
    GetAllRegionIds = function() return DCEWorldService.GetAllRegionIds() end,
    GetRegionLayer = function(regionId) return DCEWorldService.GetRegionLayer(regionId) end,
    GetTime = function() return DCEWorldService.GetTime() end,
    GetWeather = function() return DCEWorldService.GetWeather() end,
    GetAllRegionStates = function() return DCEWorldService.GetAllRegionStates() end,
})
```

## Dependencies

- **dce-core** - For EventBus and Scheduler services

## Public API

### GetRegionState(regionId)

Get the current state of a specific region.

```lua
local state = DCE.GetService("World").GetRegionState("vinewood")
-- Returns: { id, displayName, state, layer, territories } or nil
```

### GetAdjacentRegions(regionId)

Get all regions adjacent to a given region.

```lua
local adjacent = DCE.GetService("World").GetAdjacentRegions("vinewood")
-- Returns: { "rockford", "downtown", ... }
```

### GetAllRegionIds()

Get all registered region IDs.

```lua
local regions = DCE.GetService("World").GetAllRegionIds()
-- Returns: { "vinewood", "rockford", "downtown", ... }
```

### GetRegionLayer(regionId)

Get the simulation layer for a region (0 or 1).

```lua
local layer = DCE.GetService("World").GetRegionLayer("vinewood")
-- Returns: 0 or 1
```

### GetTime()

Get the current simulated time.

```lua
local time = DCE.GetService("World").GetTime()
-- Returns: { hour, minute, day, isNight }
```

### GetWeather()

Get the current weather.

```lua
local weather = DCE.GetService("World").GetWeather()
-- Returns: "CLEAR", "EXTRASUNNY", "RAIN", etc.
```

### GetAllRegionStates()

Get a summary of all region states.

```lua
local states = DCE.GetService("World").GetAllRegionStates()
-- Returns: { { id, state, layer }, ... }
```

## Scheduled Tasks

The World Service registers the following scheduled tasks:

| Task | Interval | Function |
|------|----------|----------|
| `world:layer0:tick` | 30 seconds | Layer0Tick - Statistical simulation |
| `world:layer1:tick` | 5 seconds | Layer1Tick - Ambient materialization |
| `world:time:tick` | Configurable | TimeTick - Advance simulated time |
| `world:weather:tick` | Configurable | WeatherTick - Update weather |

## Events Emitted

| Event | Payload |
|-------|---------|
| `world:tick:started` | { tickId, priority } |
| `world:tick:completed` | { tickId, durationMs, regionsProcessed } |
| `world:region:state_changed` | Region state change data |
| `world:region:layer_changed` | { regionId, fromLayer, toLayer } |
| `world:time:changed` | { hour, minute, day, isNight } |
| `world:weather:changed` | { weather } |

## Configuration

```lua
Config.World = {
    Layer0Interval = 30000,  -- ms between Layer 0 ticks
    Layer1Interval = 5000,   -- ms between Layer 1 ticks
    Time = {
        Enabled = true,
        TickInterval = 10000,  -- ms between time advances
    },
    Weather = {
        Enabled = true,
        TickInterval = 300000, -- ms between weather changes
    },
}
```

## Architecture Notes

Per ADR-0004, the World Service uses a two-layer simulation model:
- **Layer 0**: Statistical simulation that runs infrequently (30s), updates crime rates, organization heat, etc.
- **Layer 1**: Ambient materialization that runs more frequently (5s), promotes activities to Layer 1 when conditions are right

Per ADR-0015, the World Service integrates with the Profiler:
- All ticks are measured for CPU time
- Events are emitted before and after processing for observability
- Budget alerts trigger on performance issues