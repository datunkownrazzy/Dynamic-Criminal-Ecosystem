# Location Manager

## Overview

The Location Manager is DCE's single source of truth for every physical location used by DCE. It supports multiple location provider types and enables runtime editing of locations.

## Resource Location

`src/dce-world/services/location-manager.lua`

## Service Registration

```lua
DCE.RegisterService("LocationManager", {
    GetLocation = function(locationId) return DCELocationManager.GetLocation(locationId) end,
    GetOrganizationLocations = function(orgId) return DCELocationManager.GetOrganizationLocations(orgId) end,
    ListLocations = function(locationType) return DCELocationManager.ListLocations(locationType) end,
    ListProviders = function() return DCELocationManager.ListProviders() end,
    RegisterProvider = function(name, module) return DCELocationManager.RegisterProvider(name, module) end,
    RegisterLocation = function(location) return DCELocationManager.RegisterLocation(location) end,
    ResolveLocation = function(locationId, playerSource) return DCELocationManager.ResolveLocation(locationId, playerSource) end,
})
```

## Location Types

The Location Manager supports the following location types:

| Type | Description |
|------|-------------|
| `walkin-mlo` | Walk-in MLO interiors |
| `instanced` | Instanced interiors |
| `hybrid` | Hybrid interiors |
| `native` | Native GTA interiors |
| `custom` | Custom provider locations |
| `organization-facility` | Organization-owned facilities |
| `business` | Business locations |
| `crime-scene` | Crime scene locations |
| `safehouse` | Safehouse locations |
| `territory` | Territory boundaries |
| `evidence-zone` | Evidence processing zones |
| `scenario-location` | Scenario interaction points |
| `patrol-route` | Patrol route waypoints |
| `roadblock` | Roadblock positions |
| `spawn` | NPC/vehicle spawn points |

## Location Provider Interface

Providers implement the `ILocationProvider` interface:

```lua
--- Location Provider interface
---@class ILocationProvider
---@field GetLocation fun(self:ILocationProvider, locationId:string):LocationInfo|nil Get location by ID
---@field ListLocations fun(self:ILocationProvider, locationType:string|nil):table List locations
---@field ResolveLocation fun(self:ILocationProvider, location:LocationInfo, playerSource:number|nil):table|nil Resolve full location info
```

## Public API

### GetLocation(locationId)

Gets a location by ID.

```lua
local location = DCE.GetService("LocationManager").GetLocation("ballas_hq")
-- Returns: { id, name, type, coordinates, provider, metadata } or nil
```

### RegisterLocation(location)

Registers a location directly (bypasses providers).

```lua
DCE.GetService("LocationManager").RegisterLocation({
    id = "ballas_hq",
    name = "Ballas HQ",
    type = "organization-facility",
    coordinates = { x = 0, y = 0, z = 0 },
    metadata = { orgId = "ballas" }
})
```

### ListLocations(locationType?)

Lists all locations, optionally filtered by type.

```lua
-- All locations
local all = DCE.GetService("LocationManager").ListLocations()

-- Only crime scenes
local crimeScenes = DCE.GetService("LocationManager").ListLocations("crime-scene")
```

### GetOrganizationLocations(orgId)

Gets locations owned by an organization.

```lua
local locations = DCE.GetService("LocationManager").GetOrganizationLocations("ballas")
```

### RegisterProvider(providerName, providerModule)

Registers a new location provider.

```lua
DCE.GetService("LocationManager").RegisterProvider("custom-mlo", {
    GetLocation = function(id) return someCustomGetter(id) end,
    ListLocations = function() return someCustomLister() end,
})
```

### ResolveLocation(locationId, playerSource?)

Resolves location coordinates (handles instanced/hybrid).

```lua
local resolved = DCE.GetService("LocationManager").ResolveLocation("ballas_hq", playerId)
-- Returns: { coords, heading, routingBucket, instanceId } or nil
```

## Configuration

Location providers are configured through their own modules. The manager itself is initialized at startup and requires no configuration.

## Architecture Notes

Per ADR-0021, the Location Manager follows these principles:

1. **Single Source of Truth** - All location queries go through this service
2. **Provider Registration** - New providers can be added without modifying DCE Core
3. **Runtime Editing** - Locations can be registered at runtime
4. **Caching** - Frequently accessed locations are cached for performance
5. **Cleanup** - Clear/Shutdown methods remove cached data

## Integration Points

- **Organizations** - Organizations query their facilities
- **Scenarios** - Scenarios use location resolution for spawns
- **Dispatch** - Dispatch uses location names for call descriptions
- **Evidence** - Evidence may be tied to specific locations