# ADR-0021: Location Manager Provider Architecture

## Status
Accepted

## Context
DCE requires a unified location management system to serve as the single source of truth for all physical locations. Without this, each subsystem (Organizations, Dispatch, Evidence, AI) would maintain independent coordinate systems, leading to:

- Location duplication
- Inconsistent interior handling
- No unified provider registration
- Complex instanced location management
- No runtime editing capability

## Decision
Implement a provider-based Location Manager architecture where:

1. **Location Manager** (`dce-world/services/location-manager.lua`) owns all location resolution
2. **Providers** register for specific location types (vanilla, walkin-mlo, instanced, hybrid)
3. **Locations** are resolved through the manager, not direct coordinate references
4. **Provider interface** (`ILocationProvider`) standardizes location operations

### Provider Interface
```lua
---@class ILocationProvider
---@field GetLocation fun(locationId:string):LocationInfo|nil
---@field ListLocations fun(locationType:string|nil):table
---@field ResolveLocation fun(location:LocationInfo, playerSource:number|nil):table|nil
```

### Supported Location Types
| Type | Description | Examples |
|------|-------------|----------|
| vanilla | Native GTA interiors | Convenience stores, banks |
| walkin-mlo | Walk-in MLO interiors | Gabz, K4MB1 buildings |
| instanced | Routing bucket instanced | Mission interiors |
| hybrid | Chained transitions | Lobby → Elevator → Instanced floor |

## Consequences
- All DCE subsystems reference locations through LocationManager
- No direct coordinate system access outside the manager
- Providers can be added without modifying DCE Core
- Runtime location editing supported through the Control Center
- Location events emitted for observability

## Integration Points
- Organizations: HQ, facilities, safehouses
- Dispatch: Zones, stations
- Evidence: Crime scenes, areas
- AI: Patrol routes, spawn points
- Scenarios: Dynamic locations

## Files Added
- `DCE/src/dce-world/models/location.lua` - Location data model
- `DCE/src/dce-world/services/location-manager.lua` - Core service
- `DCE/src/types/services/location-manager.lua` - Type declarations

## Migration Path
Existing coordinate references should be migrated to location IDs during v2.0 development.