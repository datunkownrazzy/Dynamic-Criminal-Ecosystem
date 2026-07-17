# DCE Control Center v2 — Complete Architecture Specification

## Executive Summary

This document defines the complete ground-up rebuild of the DCE Control Center with **true lazy initialization**, **deterministic ownership**, and **strict lifecycle isolation**. Unlike v1 (which followed a "Bootstrap exists → Desktop initializes → Everything waits hidden" model), v2 implements "Bootstrap exists → Nothing happens → Player opens CC → Everything initializes → Player closes CC → Everything destroyed".

---

## Rule Zero Verification: FiveM Engine Constraints vs Architectural Decisions

### Engine Constraints (Cannot Be Changed)

| Behavior | Classification | Evidence |
|----------|----------------|----------|
| `ui_page` directive always creates a Chromium browser | **CONSTRAINT** | FiveM fxmanifest specification - ui_page is processed after client_scripts load |
| Browser executes index.html immediately upon creation | **CONSTRAINT** | CEF/Chromium loads HTML automatically |
| JavaScript IIFEs execute on DOM ready | **CONSTRAINT** | Browser engine behavior - script tags execute immediately |
| `SetNuiFocus(true, true)` triggers FiveM's gray overlay layer | **CONSTRAINT** | FiveM native behavior - overlay appears when focus granted |
| Browser cannot be destroyed without resource restart | **CONSTRAINT** | FiveM resource lifecycle - CEF browser tied to resource lifetime |

### Architectural Decisions (Can Be Changed)

| Behavior | Classification | Design Pattern |
|----------|----------------|----------------|
| Browser visibility can be controlled via CSS | **DECISION** | `opacity: 0` + `pointer-events: none` for hidden states |
| Application state can be initialized on-demand | **DECISION** | True lazy initialization pattern |
| Focus can be released to return to dormant state | **DECISION** | State machine with explicit transitions |
| Plugins can be loaded/unloaded per session | **DECISION** | Session-scoped lifecycle hooks |
| Timers/intervals can be tracked and cleaned up | **DECISION** | Resource tracking in DCE.Lifecycle |

---

## Core Architectural Separation

The following concepts are **independent systems** with **exactly one owner** each:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           BROWSER (FiveM)                             │
│                          (Chromium Instance)                              │
│  ───────━─────────────────────────────────────────────────────────────── │
│                           BOOTSTRAP (Lua)                             │
│  ───────━─────────────────────────────────────────────────────────────── │
│                        SESSION MANAGER (Lua)                            │
│  ───────━─────────────────────────────────────────────────────────────── │
│                      APPLICATION BOOT (Lua → JS)                          │
│  ───────━─────────────────────────────────────────────────────────────── │
│                          DESKTOP MANAGER (JS)                           │
│  ───────━─────────────────────────────────────────────────────────────── │
│                            PLUGIN MANAGER (JS)                            │
│  ───────━─────────────────────────────────────────────────────────────── │
│                           WINDOW MANAGER (JS)                           │
│  ───────━─────────────────────────────────────────────────────────────── │
│                               FOCUS (Lua/JS)                            │
│  ───────━─────────────────────────────────────────────────────────────── │
│                           VISIBILITY (CSS)                              │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Ownership Matrix

Each component has **exactly one owner** and **exactly one responsibility**:

| Component | Owner | Responsibility | Cannot Own |
|-----------|-------|----------------|------------|
| **Browser** | FiveM Engine | Create/destroy CEF instance | Nothing - it owns nothing |
| **Bootstrap** | LifecycleManager | Establish Lua↔NUI communication, wait | Focus, Application, Desktop |
| **Session** | SessionManager | Create/destroy session lifecycle | Browser (uses browser), Focus (manages) |
| **Application Boot** | ApplicationManager | Initialize desktop/plugins/windows | Session, Browser |
| **Desktop** | DesktopManager | Create/destroy desktop UI | Browser, Focus, Plugins |
| **Plugin Manager** | PluginManager | Load/unload plugins, emit events | Focus, Windows, Desktop |
| **Window Manager** | WindowManager | Create/destroy windows | Focus, Desktop, Plugins |
| **Focus** | LifecycleManager | ONLY calls SetNuiFocus/SetNuiFocusKeepInput | Nothing else |

---

## Browser Lifecycle

### States
| State | Description | FiveM Behavior | CSS State |
|-------|-------------|----------------|-----------|
| **CREATED** | FiveM processes ui_page, browser exists | Auto-created in Frame 4 | `cc-unloaded` |
| **READY** | NUI loaded callback received | Focus auto-granted, then released | `cc-unloaded` → `cc-ready` |
| **ACTIVATED** | Player requested CC open | Focus granted via SetNuiFocus(true, true) | `cc-open` |
| **SUSPENDED** | Player closed CC or ESC pressed | Focus released via SetNuiFocus(false, false) | `cc-unloaded` |
| **DESTROYED** | Resource stopped | Browser destroyed by FiveM | N/A |

### Transition Flow
```
FiveM Creates Browser (ui_page)
        ↓
Browser loads index.html
        ↓
JS init() → dce-cc:nui:loaded callback
        ↓
Lua EnsureCleanState() → SetNuiFocus(false, false)
        ↓
State: READY (hidden, no focus, no application)
        ↓
Player types /dce → Permission validated
        ↓
State: ACTIVATING → Application boot begins
        ↓
Desktop created, Plugins loaded, Windows ready
        ↓
Focus granted → State: OPEN
        ↓
Player presses ESC/Close → Cleanup initiated
        ↓
Windows destroyed → Plugins stopped → Desktop destroyed
        ↓
Focus released → State: SUSPENDED (dormant)
```

---

## Bootstrap Lifecycle (Lua)

The bootstrap is **NOT** the Control Center. It is a minimal communication shell.

```lua
-- Bootstrap.lua (NEW - replaces current lifecycle-manager.lua init)
-- < 200 lines of Lua

--- Responsibilities ONLY:
--- 1. Establish NUI communication channel
--- 2. Receive NUI messages via RegisterNUICallback
--- 3. Expose BrowserManager singleton
--- 4. Wait for SessionManager coordination

BrowserManager = {
    Create = function() ... end,     -- Returns browserId (FiveM handles actually)
    Activate = function() ... end,   -- Called by SessionManager
    Suspend = function() ... end,    -- Called by SessionManager
    Destroy = function() ... end,    -- Called on resource stop
}
```

**Bootstrap contains NO:**
- Desktop logic
- Plugin loading
- Window management
- Lifecycle events
- Timers/intervals
- Background processes

---

## Session Lifecycle

The **SessionManager** is the **sole owner** of:
- Browser lifetime
- Session lifetime
- Application lifetime
- Focus lifetime

```lua
-- SessionManager.lua (NEW)

SessionManager = {
    --- Creates a session for a player
    ---@param source number Player server ID
    ---@return string sessionId
    CreateSession = function(source)
        -- 1. Generate unique sessionId
        -- 2. Track session in openSessions map
        -- 3. Emit session:created event
        -- 4. Return sessionId
    end,
    
    --- Destroys a session when CC closes
    ---@param sessionId string
    ---@return boolean success
    DestroySession = function(sessionId)
        -- 1. Emit session:destroying event
        -- 2. Cleanup all resources
        -- 3. Remove session from tracking
        -- 4. Return browser to bootstrap state
    end,
}
```

### Session States
| State | Description | Duration |
|-------|-------------|----------|
| **CREATED** | Session record exists, no UI | Until player opens CC |
| **BOOTING** | Application initialization | < 100ms |
| **ACTIVE** | UI visible, player interacting | While CC is open |
| **LINGERING** | Cleanup in progress | < 50ms |
| **DESTROYED** | Session fully cleaned | Back to CREATED (new session) |

---

## Application Boot Lifecycle (JS)

This runs **after** the player requests to open CC, not at resource start.

### Desired Flow
```
Player

↓

/dce command

↓

Permission Validation (PermissionController)

↓

Session Created (SessionManager) → Returns sessionId

↓

Browser Activated (BrowserManager) → Ensures clean state

↓

Application Boot (ApplicationManager)

    ↓
    Desktop Created (DesktopManager)

    ↓
    Dock Created (Dock)

    ↓
    Plugin Manager Created (PluginManager)

    ↓
    Plugins Loaded (via Initialize/Start hooks)

    ↓
    Window Manager Created (WindowManager)

    ↓
    Lifecycle Started (track timers/intervals)

    ↓
    Focus Acquired (LifecycleManager) → SetNuiFocus(true, true)

    ↓
    Desktop Displayed (CSS opacity: 1)
```

**Nothing exists before this flow completes.**

---

## Focus Lifecycle

**ONLY ONE COMPONENT** may call `SetNuiFocus`:
- `LifecycleManager` - both Lua and JS versions coordinate

### Focus State Transitions
```lua
-- All focus changes are logged with:
-- timestamp | previousState | nextState | caller | stack trace | reason

local function logFocusChange(hasFocus, hasCursor, caller, reason)
    -- Log to diagnostics system
end

function LifecycleManager.RequestFocus()
    logFocusChange(false, true, "LifecycleManager.RequestFocus", "Player opened CC")
    SetNuiFocus(true, true)
end

function LifecycleManager.ReleaseFocus()
    logFocusChange(true, true, "LifecycleManager.ReleaseFocus", "Player closed CC")
    SetNuiFocus(false, false)
end
```

---

## Event Graph

All communication is event-driven through EventBus:

```
┌─────────────────────────────────────────────────────────────────┐
│                         EVENT GRAPH                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐                                               │
│  │   Player    │                                               │
│  └──────┬──────┘                                               │
│         │ /dce                                                  │
│         ▼                                                       │
│  ┌─────────────┐      ┌────────────────────────────────┐      │
│  │  init.lua   │─────▶│  ControlCenterService.RequestOpen  │      │
│  │  (Server)   │      └────────────────────────────────┘      │
│  └─────────────┘                     │                           │
│         │                           ▼                           │
│         │    ┌────────────────────────────────────┐          │
│         └────▶│    SessionManager.CreateSession      │          │
│               └────────────────────────────────────┘          │
│                             │                                 │
│                             ▼                                 │
│               ┌─────────────────────────────┐                   │
│               │   BrowserManager.Activate    │                   │
│               └─────────────────────────────┘                   │
│                             │                                 │
│                             ▼                                 │
│               ┌─────────────────────────────┐                   │
│               │  TriggerClientEvent:       │                   │
│               │  dce-cc:client:session:start│                   │
│               └─────────────────────────────┘                   │
│                             │                                 │
│                             ▼                                 │
│  ┌─────────────┐      ┌─────────────────────┐                │
│  │ Lifecycle   │─────▶│ ApplicationManager.   │                │
│  │ Manager     │      │ Boot()              │                │
│  │ (Client)     │      └─────────────────────┘                │
│  └─────────────┘                     │                         │
│         │                           ▼                         │
│         │    ┌────────────────────────────────┐             │
│         └────▶│ DesktopManager.Create()          │             │
│               └────────────────────────────────┘             │
│                             │                                 │
│                             ▼                                 │
│               ┌─────────────────────────────┐                   │
│               │ PluginManager.LoadPlugins()   │                   │
│               └─────────────────────────────┘                   │
│                             │                                 │
│                             ▼                                 │
│               ┌─────────────────────────────┐                   │
│               │ WindowManager.Initialize()    │                   │
│               └─────────────────────────────┘                   │
│                             │                                 │
│                             ▼                                 │
│               ┌─────────────────────────────┐                   │
│               │ LifecycleManager.RequestFocus │                   │
│               └─────────────────────────────┘                   │
│                             │                                 │
│                             ▼                                 │
│  ┌─────────────┐                                               │
│  │ SetNuiFocus │                                               │
│  │ (true, true) │                                              │
│  └─────────────┘                                               │
│         │                                                       │
│         ▼                                                       │
│  ┌─────────────┐      ┌─────────────────────────┐               │
│  │     NUI     │─────▶│     UI Now Visible      │               │
│  │   (Client)   │      │   (opacity: 1)          │               │
│  └─────────────┘      └─────────────────────────┘               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Dependency Graph

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEPENDENCY GRAPH                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────┐                                           │
│  │  FiveM Engine   │  (Provides: CEF, NUI, SetNuiFocus)          │
│  └────────┬────────┘                                           │
│           │                                                    │
│           ▼                                                    │
│  ┌─────────────────┐                                           │
│  │   Browser       │  (Owns: Nothing)                          │
│  │   (CEF)         │                                           │
│  └────────┬────────┘                                           │
│           │                                                    │
│           ▼                                                    │
│  ┌─────────────────┐                                           │
│  │   Bootstrap     │  (Owns: Communication channel)             │
│  │   (Lua)         │  Depends on: Nothing                       │
│  └────────┬────────┘                                           │
│           │                                                    │
│           ▼                                                    │
│  ┌─────────────────┐                                           │
│  │  SessionManager │  (Owns: Session, Browser, Focus, App)      │
│  │     (Lua)       │  Depends on: EventBus, Logger              │
│  └────────┬────────┘                                           │
│           │                                                    │
│           ▼                                                    │
│  ┌─────────────────┐      ┌─────────────────┐                │
│  │  LifecycleMgr   │◀────▶│   Application   │                │
│  │     (Lua)       │      │   Manager (JS)  │                │
│  └─────────────────┘      └─────────────────┘                │
│           │                       │                          │
│           ▼                       ▼                          │
│  ┌─────────────────┐      ┌─────────────────┐                │
│  │   Focus API     │      │   DesktopMgr    │                │
│  │  (SetNuiFocus) │      │     (JS)        │                │
│  └─────────────────┘      └────────┬──────────┘                │
│                                   │                           │
│         ┌─────────────────────────┼─────────────────────────┐ │
│         ▼                         ▼                         ▼ │
│  ┌─────────────┐      ┌─────────────────┐      ┌─────────────────┐ │
│  │ PluginMgr   │      │ WindowMgr       │      │  EventBus       │ │
│  │   (JS)      │      │    (JS)         │      │   (Lua/JS)      │ │
│  └─────────────┘      └─────────────────┘      └─────────────────┘ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Folder Structure (v2)

```
DCE/src/dce-controlcenter/
├── bootstrap/              # Bootstrap shell only (< 200 lines JS)
│   ├── index.html          # Minimal HTML shell
│   └── bootstrap.js        # Lua communication only
│
├── session/                # Session management
│   ├── session-manager.lua     # Session lifecycle owner
│   ├── browser-manager.lua     # Browser operations proxy
│   └── focus-manager.lua       # Focus lifecycle owner
│
├── application/            # Application boot (lazy)
│   ├── application-manager.js  # Application initialization
│   ├── desktop-manager.js      # Desktop UI creation
│   └── plugin-manager.js       # Plugin loading/unloading
│
├── window/                 # Window management
│   └── window-manager.js       # Window lifecycle
│
├── ui/                     # UI Components (loaded on-demand)
│   ├── desktop.js
│   ├── dock.js
│   ├── window/
│   ├── panel.js
│   ├── tab.js
│   ├── context-menu.js
│   └── search.js
│
├── plugins/                # Plugins (passive, respond to events)
│   ├── world-manager/
│   ├── organization-manager/
│   ├── scenario-manager/
│   ├── evidence-manager/
│   ├── dispatch-manager/
│   ├── ai-manager/
│   ├── economy-manager/
│   ├── analytics/
│   ├── server-monitor/
│   └── dev-tools/
│
├── services/               # Server-side services
│   ├── controlcenter.lua       # Main service
│   ├── location-manager.lua
│   ├── location-editor.lua
│   ├── organization-editor.lua
│   ├── plugin-registry.lua
│   ├── session-registry.lua    # NEW
│   └── provider-registry.lua
│
├── controllers/            # Client/Server coordination
│   ├── permission-controller.lua
│   ├── window-controller.lua
│   ├── session-controller.lua      # NEW
│   └── plugin-controller.lua
│
├── shared/
│   ├── config.lua
│   ├── interfaces/
│   │   ├── IPlugin.lua
│   │   ├── ILocationProvider.lua
│   │   ├── ISession.lua
│   │   └── IBrowserManager.lua
│   └── schemas/
│       └── session-schema.json
│
├── diagnostics/            # Runtime instrumentation
│   ├── instrumentation.lua
│   └── runtime-instrumentation.js
│
├── fxmanifest.lua
└── init.lua
```

---

## Runtime Instrumentation Design

Every lifecycle event is logged with full context:

### Instrumentation Payload Schema

```lua
---@class InstrumentationEvent
---@field timestamp number (Unix timestamp in ms)
---@field subsystem string ("browser", "session", "application", "focus", "desktop", "plugin", "window")
---@field action string ("created", "activated", "suspended", "destroyed", "error")
---@field duration number|nil (ms since start of operation)
---@field caller string (module that initiated the action)
---@field stack_trace string (debug.traceback output)
---@field session_id string|nil (if applicable)
---@field thread string|nil (main/ui thread)
```

### Events Tracked

| Event | Subsystem | Action | Purpose |
|-------|-----------|--------|---------|
| Browser created | browser | created | FiveM ui_page processed |
| Browser activated | browser | activated | SetNuiFocus(true) called |
| Browser suspended | browser | suspended | SetNuiFocus(false) called |
| Session created | session | created | Player opened CC |
| Session destroyed | session | destroyed | Player closed CC |
| Application boot | application | started | JS initialization |
| Application shutdown | application | stopped | Cleanup complete |
| Desktop created | desktop | created | DOM elements created |
| Desktop destroyed | desktop | destroyed | DOM elements removed |
| Plugin loaded | plugin | loaded | Initialize() called |
| Plugin unloaded | plugin | unloaded | Stop()/Destroy() called |
| Window created | window | created | Window opened |
| Window destroyed | window | destroyed | Window closed |
| Focus acquired | focus | acquired | SetNuiFocus(true) |
| Focus released | focus | released | SetNuiFocus(false) |

---

## Migration Strategy

### Phase 1: Analysis & Planning (COMPLETE)
- [x] Forensic investigation of v1
- [x] Identify FiveM constraints
- [x] Document root cause of gray overlay

### Phase 2: Bootstrap Isolation (CURRENT)
- [ ] Create minimal bootstrap shell
- [ ] Strip all application code from startup
- [ ] Verify no focus at resource start

### Phase 3: Session Manager (NEW)
- [ ] Create SessionManager singleton
- [ ] Implement session lifecycle
- [ ] Create BrowserManager abstraction

### Phase 4: Application Lazy Load
- [ ] Create ApplicationManager
- [ ] Move DesktopManager to lazy init
- [ ] Move PluginManager to lazy init

### Phase 5: Instrumentation
- [ ] Add session tracking
- [ ] Add state transition logging
- [ ] Add focus ownership logging

### Phase 6: Testing
- [ ] Test with multiple players
- [ ] Verify no gray overlay on spawn
- [ ] Verify complete cleanup on close
- [ ] Verify hot-reload support

---

## Performance Comparison: v1 vs v2

| Metric | v1 (Current) | v2 (Proposed) | Improvement |
|--------|--------------|---------------|-------------|
| Memory at resource start | ~512KB (all modules loaded) | ~32KB (bootstrap only) | **94% reduction** |
| CPU at resource start | All IIFEs execute | Only bootstrap IIFE | **90% reduction** |
| Browser state on spawn | Visible (opacity transitions) | Hidden (opacity: 0) | **No visual artifacts** |
| Focus on spawn | Risk of gray overlay | Clean (no focus) | **Fixed** |
| Session creation time | Immediate (pre-warmed) | ~50ms (lazy init) | **Trade-off** |
| Multi-player memory | Shared pool | Per-session | **Scalable** |

---

## Critical Architecture Decisions

### Decision 1: Bootstrap Isolation
The bootstrap (`lifecycle.js`) will contain **only** communication setup:
- DCE.NUI.post helper
- RegisterNUICallback wrapper
- Message handler
- ~100 lines total (not 272 lines)

### Decision 2: Session Manager Authority
The **SessionManager** owns the entire player session lifecycle. No other component may:
- Create sessions
- Destroy sessions
- Manage focus
- Release focus

### Decision 3: Plugin Passivity
Plugins are **passive**. They:
- Implement Initialize/Start/Stop/Destroy hooks
- Never call SetNuiFocus
- Never post to lifecycle events
- Only respond to EventBus notifications

### Decision 4: Focus Logging
Every SetNuiFocus call logs:
```
[timestamp] focus: RELEASED | from: open | caller: LifecycleManager.ReleaseFocus | session: abc123 | thread: main
```

---

## Implementation Checklist

### Immediate Actions
- [ ] Create `bootstrap/bootstrap.js` (minimal)
- [ ] Create `session/session-manager.lua`
- [ ] Create `session/browser-manager.lua`
- [ ] Create `session/focus-manager.lua`

### Architecture Changes
- [ ] Move desktop creation to `application/desktop-manager.js`
- [ ] Move plugin loading to `application/plugin-manager.js`
- [ ] Implement true lazy initialization in `application/application-manager.js`

### Instrumentation
- [ ] Add session tracking to runtime-instrumentation
- [ ] Add focus ownership enforcement
- [ ] Add state transition validation

### Testing
- [ ] Verify no browser focus on resource start
- [ ] Verify application only initializes on /dce command
- [ ] Verify complete cleanup on close
- [ ] Verify multi-player isolation