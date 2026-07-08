# ADR-0022: DCE Control Center v2 Architecture

**Status:** Accepted  
**Date:** 2026-07-08  
**Author:** Architecture  
**Dependencies:** ADR-0006 (Plugin Architecture), ADR-0010 (Event Bus), ADR-0021 (Location Manager)

---

## Problem

The existing `dce-admin` implementation, while functional, suffers from architectural limitations:

1. **NUI Lifecycle Issues**: Gray overlay on spawn, stuck focus, unreleased input
2. **Tight Coupling**: UI modules directly call Lua service functions
3. **Limited Plugin System**: Plugins cannot extend the Control Center UI
4. **No Runtime Editing**: Live editing capabilities are superficial
5. **Missing Provider Architecture**: Location management lacks proper abstraction

The Control Center v2 must address these issues while becoming the "operating system" for DCE.

---

## Decision

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Control Center v2                           │
├─────────────────────────────────────────────────────────────────┤
│                      NUI Shell (HTML/CSS/JS)                    │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Desktop Environment (Hidden until opened)                 │  │
│  │ ┌────────┐ ┌────────┐ ┌────────┐                       │  │
│  │ │ Window │ │ Window │ │ Window │                       │  │
│  │ │   A    │ │   B    │ │   C    │                       │  │
│  │ └────────┘ └────────┘ └────────┘                       │  │
│  │ Toolbar | Status Bar | Notifications                    │  │
│  └───────────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                        ViewModel Layer                         │
│  Reactivity, State Management, Event Subscriptions               │
├─────────────────────────────────────────────────────────────────┤
│                      Controller Layer                          │
│  Window Management, Plugin Registration, Permission Checks        │
├─────────────────────────────────────────────────────────────────┤
│                      Service Layer                             │
│  ControlCenterService, LocationManagerService, OrgManagerService  │
├─────────────────────────────────────────────────────────────────┤
│                         EventBus                              │
│  All communication is event-driven                           │
└─────────────────────────────────────────────────────────────────┘
```

### NUI Lifecycle Manager (Critical)

The NUI Lifecycle Manager is the **only** component allowed to call `SetNuiFocus`. This eliminates the gray overlay issue through deterministic state management.

```lua
---@class INUILifecycleManager
---@field requestOpen fun(callback: function) Open the Control Center
---@field requestClose fun() Close the Control Center
---@field isFocused fun(): boolean Check if NUI has focus
---@field getState fun(): "closed"|"opening"|"open"|"closing"
```

**Lifecycle States:**
1. `closed` - Default state, no focus, opacity 0, pointer-events none
2. `opening` - Focus requested, waiting for NUI ready
3. `open` - Focus granted, UI visible
4. `closing` - Focus release requested, waiting for confirmation

**Focus Ownership Rules:**
- Only `NuiLifecycleManager` calls `SetNuiFocus`
- Every open has exactly one matching close
- Every focus acquisition has exactly one release
- All cleanup paths are guaranteed via state machine

### Plugin Registration Interface

Plugins extend the Control Center through a declarative manifest:

```lua
-- Plugin manifest for Control Center extension
manifest.controlcenter = {
    -- Window definitions
    windows = {
        {
            id = "myplugin:editor",
            title = "My Plugin Editor",
            icon = "fa-plugin",
            permissions = { "admin", "developer" },
            viewModel = "MyPluginViewModel",
            controller = "MyPluginController",
        }
    },
    
    -- Toolbar contributions
    toolbar = {
        {
            id = "myplugin:action",
            label = "Do Action",
            icon = "fa-bolt",
            requireWindow = "myplugin:editor",
        }
    },
    
    -- Lifecycle hooks
    onRegistered = function(pluginAPI) end,
    onStartup = function() end,
    onShutdown = function() end,
}
```

### Location Provider Architecture

Per ADR-0021, locations are managed through a provider system:

```lua
---@class ILocationProvider
---@field GetLocation fun(id: string): LocationInfo|nil
---@field ListLocations fun(type: string|nil): table
---@field ResolveLocation fun(location: LocationInfo, playerSource: number|nil): table|nil
---@field CreateLocation fun(data: table): boolean, string|nil
---@field UpdateLocation fun(id: string, data: table): boolean, string|nil
---@field DeleteLocation fun(id: string): boolean, string|nil
```

**Supported Location Types:**
- `vanilla` - Native GTA interiors
- `walkin-mlo` - Walk-in MLO interiors (Gabz, K4MB1)
- `instanced` - Routing bucket instanced interiors
- `hybrid` - Chained transitions (Lobby → Elevator → Instanced)
- `mlo` - Generic MLO
- `ipl` - IPL-based interiors
- `teleport` - Simple teleport locations
- `spawn` - Vehicle/NPC spawn points
- `business` - Business locations
- `safehouse` - Safehouse locations
- `druglab` - Drug lab locations
- `warehouse` - Warehouse locations
- `territory` - Territory centers
- `crimescene` - Crime scene locations
- `dispatch` - Police/fire/EMS stations
- `evidence` - Evidence locker locations
- `mission` - Mission-specific locations
- `roadblock` - Roadblock spawn locations
- `patrol` - Patrol zone locations
- `gangcorner` - Gang corner locations

### Service Dependencies

```
ControlCenterService (Primary service)
    ├── NuiLifecycleManager (NUI focus management)
    ├── WindowManager (Window state)
    ├── PluginRegistry (Plugin discovery)
    ├── ViewModelRegistry (Reactive state)
    └── EventForwarder (EventBus ↔ NUI)

LocationManagerService
    ├── LocationProviderRegistry
    ├── LocationValidator
    └── LocationEventHandlers

OrganizationManagerService
    ├── OrganizationRepository
    ├── OrganizationViewModelBuilder
    └── OrganizationEditor
```

### Data Models

All data models are immutable DTOs that flow through the EventBus:

```lua
---@class LocationDTO
---@field id string Unique location identifier
---@field provider string Provider name (native, mlo, instanced, etc.)
---id.type string Location type
---@field coords vector3|nil Coordinates
---@field heading number|nil Heading rotation
---@field metadata table Extended properties
---@field active boolean Whether location is active

---@class OrganizationDTO
---@field id string Unique organization ID
---@field identity IdentityDTO
---@field culture CultureDTO
---@field territory TerritoryDTO|nil
---@field facilities table[] Location relationships
---@field hierarchy HierarchyDTO
---@field state StateDTO
```

---

## Consequences

### Benefits
- Deterministic NUI lifecycle eliminates gray overlay issues
- Plugins can extend UI without modifying core
- Location providers enable third-party interior support
- Event-driven architecture improves observability
- Runtime editing is fully supported through immutability

### Costs
- New implementation from scratch (no reuse)
- More complex initial setup
- Requires adapter interfaces for existing systems

### Risks
- NUI lifecycle complexity (mitigated by dedicated manager)
- Plugin API surface area
- Performance with many providers

---

## Implementation Order

1. NUI Lifecycle Manager (critical path)
2. ControlCenterService core
3. Window/Plugin framework (UI)
4. Location Provider system
5. Organization Manager
6. Developer Tools module
7. Runtime editor integration