# ADR-0011: DCE Control Center Architecture

**Status:** Accepted  
**Date:** 2026-07-05  
**Author:** Architecture  
**Dependencies:** ADR-0006 (Plugin Architecture), ADR-0005 (Domain Boundaries), ADR-0010 (Event Bus)

---

## Problem

The DCE Admin Panel requires transformation from a basic admin menu into a full-featured Control Center for ecosystem development, configuration, and monitoring. This interface must support:

- Modular, plugin-discoverable UI components
- Vendor-neutral adapter management
- Event-driven real-time updates
- Professional desktop-style UX
- In-game world editing capabilities
- Persistent runtime configuration

The challenge is implementing this within FiveM's NUI constraints (single UI page) while maintaining the existing DCE service architecture.

---

## Decision

### Single-Page Desktop Environment

FiveM resources support only one `ui_page`. The Control Center implements an **internal desktop environment** within this single page rather than multiple UI pages.

```
┌─────────────────────────────────────────────────────────┐
│ Control Center Shell (Desktop Environment)              │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Window Manager                                      │ │
│ │ ┌────────────┐ ┌────────────┐ ┌────────────┐       │ │
│ │ │ Organizations│ │ Dispatch    │ │ Analytics  │       │ │
│ │ │ [Header]    │ │ [Header]    │ │ [Header]   │       │ │
│ │ │ [Content]   │ │ [Content]   │ │ [Content]  │       │ │
│ │ └────────────┘ └────────────┘ └────────────┘       │ │
│ └─────────────────────────────────────────────────────┘ │
│ Status Bar | Toolbar | Notifications                   │
└─────────────────────────────────────────────────────────┘
```

### Window Manager

The Window Manager is a NUI-side system that simulates OS-like windows:

```javascript
// Window Manager API
DCE.Windows.create({
    id: 'organizations',
    title: 'Organizations',
    width: 600,
    height: 400,
    x: 100,
    y: 100,
    module: 'organizations.js',
    permissions: ['admin', 'developer'],
});
```

Features:
- **Draggable**: Click-drag on header
- **Resizable**: Resize handles on edges
- **Snap-to-edge**: Magnetic window positioning
- **Minimize/Maximize/Restore**: Window state management
- **Tab Groups**: Multiple windows in tabbed interface
- **Saved Layouts**: Per-player window positions persisted

### Plugin UI Discovery

Plugins declare UI components in their manifest (extends DCE-0003):

```lua
manifest.ui = {
    windows = {
        { id = 'myplugin:editor', title = 'My Plugin Editor' },
    },
    toolbar = {
        { id = 'myplugin:action', label = 'Do Action', icon = 'fa-bolt' },
    },
    inspectors = {
        { target = 'organization', fields = { ... } },
    },
    analytics = {
        metrics = { 'custom_metric' },
    },
}
```

The Admin Service discovers and registers these automatically.

### Adapter Discovery & Health

All adapters implement a standard diagnostics interface:

```lua
---@class IAdapterDiagnostics
---@field status "active"|"inactive"|"error" Current adapter state
---@field health number 0-100 Health score
---@field latency number Milliseconds
---@field queue number Pending operations
---@field errors number Total errors
---@field lastCheck number Unix timestamp
---@field capabilities string[] Supported features
function GetDiagnostics()
    return {
        status = self.isActive and "active" or "inactive",
        health = self.healthScore or 100,
        latency = self.latencyMs or 0,
        queue = #self.pending or 0,
        errors = self.errorCount or 0,
        lastCheck = os.time(),
        capabilities = self.capabilities or {},
    }
end
```

### Event-Driven Updates

All UI data flows through the Event Bus. The NUI subscribes to relevant events:

```javascript
// NUI receives EventBus events via Lua message forwarding
DCE.EventHandler.subscribe('organization:update', (data) => {
    DCE.Modules.organizations.update(data);
});
```

No polling is permitted except for expensive calculations that are rate-limited.

### Configuration Management

The Control Center provides a unified configuration editor:

1. **Discovery**: Each service exposes its editable config via `GetEditableConfig()`
2. **Validation**: Schema-based validation before apply
3. **Persistence**: Changes saved to cache, broadcast via EventBus
4. **Live Apply**: Affected services reload configuration without restart

### World Editor Integration

World editing requires client-server coordination:

1. **Client captures position** via raycasting or player position
2. **Server validates and persists** the location data
3. **EventBus broadcasts** changes to affected systems
4. **Visual preview** shows placement before commit

---

## Consequences

### Benefits
- Single resource manages all admin UI
- Plugin authors can extend the Control Center without core changes
- Adapter status visible in real-time
- Professional UX comparable to game engines
- All configuration accessible in-game

### Costs
- Larger initial bundle size (Chart.js, window manager)
- More complex NUI codebase
- Additional service methods required on adapters

### Risks
- Performance impact if not carefully optimized
- Risk of NUI memory leaks if window disposal not implemented correctly
- Backward compatibility must be maintained for existing plugins

---

## Implementation Order

1. Window Manager shell and base CSS
2. Event forwarding from EventBus to NUI
3. Chart.js integration
4. Plugin/adapter registration extensions
5. World editor components (deferred)