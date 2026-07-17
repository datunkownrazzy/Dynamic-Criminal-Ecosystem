# ADR-0024: DCE Control Center v2 - Application Lifecycle Redesign

**Status:** Proposed  
**Date:** 2026-07-08  
**Author:** Architecture  
**Supersedes:** ADR-0022 (Control Center v2 Architecture)

---

## Problem

The current dce-controlcenter architecture has fundamental lifecycle issues:

1. **NUI Gray Overlay**: FiveM's `ui_page` directive auto-grants focus, creating phantom focus that cannot be released
2. **Incomplete State Machine**: Missing LOADING, READY, CLOSING, SHUTDOWN states
3. **Hardcoded UI**: Dock buttons are hardcoded in HTML instead of being built dynamically from plugin manifests
4. **Missing Plugin Lifecycle**: No initialize/start/stop/destroy hooks are invoked
5. **No DCE Service Integration**: Control Center operates independently of DCE Core services
6. **Incomplete Cleanup**: EventBus subscriptions, timers, and windows not properly cleaned up on close

---

## Decision

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                   Control Center v2 Lifecycle                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   UNLOADED → LOADING → READY → OPEN → CLOSING → SHUTDOWN → UNLOADED
│                                                                 │
│   State transitions are ONE-WAY and GUARANTEED.                 │
│   No "hidden" state - only "closed" transitioning to "open".      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### FiveM NUI Lifecycle Solution

**Critical**: FiveM auto-grants focus when `ui_page` loads. We CANNOT prevent this.
**Solution**: 
1. Accept browser is created on resource load (unpreventable)
2. Release focus IMMEDIATELY after browser is ready (via NUICallback)
3. Add multiple defensive cleanup paths
4. Never let the gray overlay become visible

### Component Ownership

| Component | Owner | Responsibility |
|-----------|-------|----------------|
| Browser Creation | FiveM (ui_page) | Unpreventable - accept and respond |
| Browser Focus State | LifecycleManager | ONLY component that calls SetNuiFocus |
| Plugin Lifecycle | LifecycleManager | Initialize/start/stop/destroy in order |
| EventBus Subscriptions | LifecycleManager | Track and cleanup all subscriptions |
| Timers/Intervals | LifecycleManager | Track and cleanup all timers |
| Desktop State | Lifecycle.js (JS) | OPEN/CLOSED states only |
| Window Management | WindowManager | Create/destroy windows |

### Lifecycle Manager Interface

```lua
---@class INUILifecycleManager
---@field state "unloaded"|"loading"|"ready"|"open"|"closing"|"shutdown" Current state
---@field transition fun(newState: string): boolean Transition to new state
---@field open fun(): boolean Open Control Center
---@field close fun(): boolean Close Control Center
---@field initializePlugins fun(): boolean Initialize all plugins
---@field destroyPlugins fun(): boolean Destroy all plugins
---@field cleanup fun(): boolean Full cleanup on close
```

### Plugin Manifest Structure

```lua
---@class ControlCenterPluginManifest
---@field name string Plugin identifier
---@field displayName string Human-readable name
---@field version string Semantic version
---@field description string Plugin description
---@field icon string Icon unicode/character
---@field category string Category for grouping
---@field permissions string[] Required permission strings
---@field dependencies string[] Other plugins this depends on
---@field routes table<string, RouteDefinition> Route/path definitions
---@field commands table[] Commands contributed to command palette
---@field settings table Settings schema
---@field lifecycle table { initialize: fn, start: fn, stop: fn, destroy: fn }
---@field adapters string[] Supported adapter types
---@field events.subscribed string[] Events this plugin subscribes to
---@field events.published string[] Events this plugin publishes
---@field menuContributions table Toolbar contributions
```

### Required States

```lua
UNLOADED   - Resource loaded, browser ready but hidden, no focus
  ↓
LOADING    - Lifecycle manager initializing, plugins preparing
  ↓
READY      - All plugins loaded, waiting for open command
  ↓
OPEN       - Browser has focus, UI visible, player interacting
  ↓
CLOSING    - Cleanup in progress, windows being destroyed
  ↓
SHUTDOWN   - All cleanup complete, returning to UNLOADED
  ↓
UNLOADED   - Ready for next open cycle
```

---

## Consequences

### Benefits
- Deterministic lifecycle eliminates gray overlay issues
- Proper plugin lifecycle ensures clean startup/shutdown
- Dynamic UI from manifests enables true extensibility
- EventBus integration enables real-time updates
- Clean separation between NUI state and application state

### Costs
- Complete rewrite of lifecycle management
- Need to merge lifecycle.js and app.js into single coherent system
- Plugin manifests must be restructured for dynamic UI

### Risks
- FiveM NUI focus race conditions (mitigated by defensive cleanup)
- State transition validation complexity

---