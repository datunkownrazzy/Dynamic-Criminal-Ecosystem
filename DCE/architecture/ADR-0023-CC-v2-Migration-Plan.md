# ADR-0023: Control Center v2 Migration Plan

## Status
Proposed

## Context
The existing `dce-admin` resource has fundamental architectural issues:
- NUI lifecycle problems causing gray overlay traps
- No proper separation of concerns
- Direct native calls scattered throughout
- Not designed for hot-reload or runtime editing
- Missing plugin architecture

This is a complete rebuild following DCE architecture patterns.

## Decision

### Phase 1: Core Foundation (COMPLETE)

#### 1.1 NUI Lifecycle Manager ✅
- **File**: `client/nui/lifecycle-manager.lua`
- **Purpose**: Single point of truth for all `SetNuiFocus` calls
- **Key Features**:
  - State machine (closed → opening → open → closing)
  - Defensive cleanup on resource start/stop
  - Player spawn defense for orphaned focus
  - NUI confirmation callbacks for state transitions

#### 1.2 Control Center Service ✅
- **File**: `server/services/controlcenter.lua`
- **Purpose**: Central service for window management and event forwarding
- **Key Features**:
  - Session management (open/closed per player)
  - Event subscription management
  - Permission checking integration
  - Service/Plugin registry exposure

#### 1.3 Location Editor Service ✅
- **File**: `server/services/location-editor.lua`
- **Purpose**: Runtime editing of locations with undo/redo
- **Key Features**:
  - Full CRUD operations
  - Undo/redo stack per player
  - Location validation against schema
  - Territory management

### Phase 2: UI Framework (COMPLETE)

#### 2.1 Desktop Environment ✅
- **File**: `html/index.html`
- **Features**:
  - Dock/toolbar for plugin launching
  - Window container with templates
  - Status bar with breadcrumb
  - Notification system
  - Modal overlay

#### 2.2 Window Manager ✅
- **File**: `html/js/ui/window-manager.js`
- **Features**:
  - Draggable windows
  - Resizable with handles
  - State persistence via localStorage
  - Z-index management
  - Window close coordination with lifecycle

#### 2.3 Plugin Architecture ✅
- **Plugins Created**:
  - `world-manager` - Locations, territories, providers
  - `organization-manager` - Organization editor
  - `dispatch-manager` - Dispatch zones and stations
  - `evidence-manager` - Evidence tracking
  - `ai-manager` - AI population control
  - `analytics` - Real-time metrics
  - `server-monitor` - Server stats
  - `dev-tools` - Debugging tools

### Phase 3: Service Integration (IN PROGRESS)

#### 3.1 Plugin Registry Service ✅
- **File**: `server/services/plugin-registry.lua`
- **Purpose**: Plugin discovery and manifest management

#### 3.2 Permission Controller ✅
- **File**: `server/controllers/permission-controller.lua`
- **Purpose**: Role-based access control

#### 3.3 Window Controller ✅
- **File**: `server/controllers/window-controller.lua`
- **Purpose**: Window state coordination

### Phase 4: Provider Architecture (IN PROGRESS)

#### 4.1 Native Provider ✅
- **File**: `server/adapters/native-provider.lua`
- Simple teleport locations

#### 4.2 MLO Provider ✅
- **File**: `server/adapters/mlo-provider.lua`
- Walk-in interiors support

#### 4.3 Instanced Provider ✅
- **File**: `server/adapters/instanced-provider.lua`
- Routing bucket interiors

### Phase 5: Event Definitions

Required events to be defined in DCE Core:
```
controlcenter:opened        - When CC opens for a player
controlcenter:closed        - When CC closes
controlcenter:window:open   - When a window opens
controlcenter:window:close  - When a window closes
controlcenter:permission:check - Permission check request
```

## Migration Steps (For Developers)

### Step 1: Replace Resource

1. Stop server
2. Delete `resources/[local]/dce-admin`
3. Add `resources/[local]/dce-controlcenter` to server.cfg
4. Start server

### Step 2: Permission Migration

Old permission structure:
```lua
-- dce-admin used direct ace permissions
AddEventHandler('onResourceStart', function()
    -- Old permission check
end)
```

New permission structure:
```lua
-- dce-controlcenter uses Config.CC.Permissions
Config.CC = {
    Permissions = {
        Roles = {
            admin = { "command.dce", "dce.admin" },
            moderator = { "dce.moderator" }
        }
    }
}
```

### Step 3: Command Migration

Old commands:
- `/admin` - Opens old admin menu
- `/dce` - Potential conflict

New commands:
- `/dce` - Opens Control Center v2
- `/dce admin` - Explicit admin open

### Step 4: NUI Integration Points

Replace old NUI calls with new pattern:
```lua
-- OLD (problematic)
SetNuiFocus(true, true)
SendNUIMessage({ action = "open" })

-- NEW (controlled)
local LifecycleManager = _G.DCELifecycleManager
LifecycleManager.requestOpen()
```

## Breaking Changes

| Component | Old | New |
|-----------|-----|-----|
| Resource name | dce-admin | dce-controlcenter |
| NUI visibility | Auto-open on load | Explicit open via lifecycle |
| Focus management | Scattered SetNuiFocus calls | Single Lifecycle Manager |
| Event subscription | Polling | EventBus subscription |
| Location editing | Limited | Full undo/redo support |

## Deprecation Path

1. **v1.x**: dce-admin works but is deprecated
2. **v2.0**: dce-controlcenter becomes primary
3. **v2.1**: dce-admin removal planned
4. **v3.0**: dce-admin fully removed

## Rollback Procedure

If issues occur:
1. Stop dce-controlcenter
2. Restore dce-admin
3. Report issue with diagnostics mode enabled

## Testing Checklist

- [ ] Resource starts without errors
- [ ] NUI loads hidden (no gray overlay)
- [ ] `/dce` command opens control center
- [ ] ESC closes control center properly
- [ ] Focus releases on close
- [ ] Resource stop cleanup works
- [ ] Player spawn defense works
- [ ] All plugins render correctly
- [ ] Undo/redo works for locations
- [ ] Event forwarding works

## References

- ADR-0021: NUI Lifecycle Diagnostic Mode
- ADR-0022: Control Center v2 Architecture
- NUI-RUNTIME-FORENSIC-REPORT.md