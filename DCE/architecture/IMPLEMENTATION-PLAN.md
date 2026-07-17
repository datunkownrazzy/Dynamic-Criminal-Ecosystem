# DCE Control Center v2 - Implementation Plan

## Status: Phase 2 Complete, Phase 3 In Progress

## Analysis Summary

The DCE Control Center v2 has been rebuilt with a proper service-oriented architecture integrating with DCE Core.

### Completed Implementation
1. **NUI Lifecycle Manager** - Single point of SetNuiFocus calls ✅
2. **ControlCenter Service** - Self-registers with DCE Core ✅
3. **Location Manager Service** - Provider abstraction with EventBus integration ✅
4. **Location Editor Service** - CRUD with undo/redo ✅
5. **Plugin Registry Service** - Auto-registers built-in plugins ✅
6. **Native Provider** - Vanilla locations implemented ✅
7. **MLO Provider** - Walk-in interiors implemented ✅
8. **Instanced Provider** - Routing bucket interiors implemented ✅
9. **CSS Styles** - Full styling for desktop environment ✅

### Files Updated in This Session
- `DCE/src/dce-controlcenter/init.lua` - Simplified resource lifecycle
- `DCE/src/dce-controlcenter/server/services/controlcenter.lua` - Auto-registration, EventBus integration
- `DCE/src/dce-controlcenter/server/services/location-manager.lua` - Auto-registration, provider registration
- `DCE/src/dce-controlcenter/server/services/location-editor.lua` - Auto-registration
- `DCE/src/dce-controlcenter/server/services/plugin-registry.lua` - Auto-registration, built-in plugins
- `DCE/src/dce-controlcenter/server/adapters/native-provider.lua` - Complete implementation
- `DCE/src/dce-controlcenter/server/adapters/mlo-provider.lua` - Complete implementation
- `DCE/src/dce-controlcenter/server/adapters/instanced-provider.lua` - Complete implementation
- `DCE/src/dce-controlcenter/fxmanifest.lua` - Fixed load order, added server exports
- `DCE/src/dce-controlcenter/client/nui/event-forwarder.lua` - Simplified
- `DCE/src/dce-controlcenter/html/js/app.js` - Updated message handling
- `DCE/src/dce-controlcenter/html/css/style.css` - Complete styling

### Remaining Tasks

#### Phase 3: UI Framework Completion
- [ ] Dock - Dynamic plugin loading from registry (currently uses hardcoded buttons)
- [ ] Notifications - Full implementation test
- [ ] Command Palette - Integration
- [ ] Inspector - Service inspection UI
- [ ] Workspace Manager - Multiple workspaces

#### Phase 4: Plugin System
- [ ] World Manager - Complete with provider registration UI
- [ ] Organization Manager - Full CRUD
- [ ] Dispatch Manager - Zone management
- [ ] Evidence Manager - Evidence tracking
- [ ] AI Manager - Population controls
- [ ] Analytics - Real-time metrics
- [ ] Server Monitor - Server stats
- [ ] Dev Tools - Debugging utilities

#### Phase 5: Additional Providers
- [ ] Hybrid Provider - Chained transitions (extending instanced)
- [ ] IPL Provider - IPL-based interiors
- [ ] Teleport Provider - Simple teleports (extending native)

#### Phase 6: EventBus Integration
- [ ] Location events → Organizations (if Organizations service exists)
- [ ] Location events → Dispatch
- [ ] Location events → AI
- [ ] Location events → Scenario Manager

## Critical Architecture Rules Verified

✅ Only one file calls SetNuiFocus: `lifecycle-manager.lua`
✅ Browser is hidden by default (opacity: 0)
✅ Services register via DCE.RegisterService
✅ EventBus integration for all state changes
✅ Provider abstraction pattern implemented

## Testing Checklist (Pending)
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