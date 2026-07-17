# CONTROL CENTER INITIALIZATION SEQUENCE - ARCHITECTURAL VIOLATION REPORT

## Executive Summary

After comparing the current implementation against the intended architecture (ADR-0026, ADR-0024), multiple critical violations have been identified that break the true lazy initialization pattern and violate the single ownership principle for focus management.

---

## CRITICAL VIOLATIONS IDENTIFIED

### 1. SetNuiFocus Multi-Ownership Violation (ARCHITECTURAL BREAKING CHANGE)

**Intended Architecture (per ADR-0026):**
- FocusManager (`session/focus-manager.lua`) is the SOLE owner of SetNuiFocus
- All other modules MUST delegate to FocusManager

**Current Violations:**

| File | Line | Violation | Fix Required |
|------|------|-----------|--------------|
| `client/nui/lifecycle-manager.lua` | 181-183, 206, 222 | Calls SetNuiFocus directly in EnsureCleanState, RequestFocus, ReleaseFocus | Must delegate to FocusManager |
| `session/session-manager-client.lua` | 58-94 | Has fallback SetNuiFocus call when FocusManager unavailable | Must use exports:GetFocusManager or fail gracefully |
| `bootstrap/bootstrap.lua` | 79-84, 122-124 | Calls SetNuiFocus in NUIReady() and onClientResourceStop | Must delegate to FocusManager |
| `client/controllers/session-controller.lua` | 85-88, 114-117 | Calls SetNuiFocus directly | Must delegate to FocusManager |

**Root Cause:** These modules were converted from the v1 architecture where focus was distributed, but the v2 architecture requires centralized ownership.

---

### 2. Duplicate Session Management - Conflicting Responsibilities

**Intended Architecture:**
- SessionManagerClient (`session/session-manager-client.lua`) owns client session lifecycle
- LifecycleManager (`client/nui/lifecycle-manager.lua`) owns state machine and cleanup

**Current Violation:**
Both files handle the same events:
- `dce-cc:client:session:start` - handled in BOTH files (lifecycle-manager.lua:457-466, session-manager-client.lua:271-292)
- `dce-cc:client:session:end` - handled in BOTH files (lifecycle-manager.lua:463-466, session-manager-client.lua:295-303)

**Fix:** Consolidate session lifecycle handling to session-manager-client.lua only, remove duplicate handlers from lifecycle-manager.lua

---

### 3. Bootstrap Initialization Timing Violation

**Intended Architecture (per ADR-0026):**
```
Resource Startup Flow:
FiveM Creates Browser (ui_page)
    ↓
Browser loads bootstrap.html (hidden via CSS)
    ↓
JS Bootstrap runs (only DCE.NUI.post, no app logic)
    ↓
NUI ready callback → FocusManager.ReleaseFocus (delegating)
    ↓
State: READY (dormant, no application)
```

**Current Violation:**
- `bootstrap/bootstrap.lua` calls SetNuiFocus directly instead of delegating to FocusManager
- This violates the lazy initialization principle during the critical startup phase
- The bootstrap module should be truly minimal - only establishing communication

---

### 4. FocusManager Export Missing Proper Client Export

**Current fxmanifest.lua (lines 127-135):**
```lua
function GetFocusManager()
    return nil  -- Always returns nil!
end
```

**Issue:** FocusManager is CLIENT-SIDE ONLY but the export always returns nil, making it impossible for other modules to access it via `exports['dce-controlcenter']:GetFocusManager()`.

---

### 5. Session Manager Module Loading Order Confusion

**Current fxmanifest.lua server_scripts order:**
```
1. server/services/controlcenter.lua
2. server/services/location-manager.lua
3. server/services/location-editor.lua
4. server/services/organization-editor.lua
5. server/services/plugin-registry.lua
6. server/controllers/permission-controller.lua
7. server/controllers/window-controller.lua
8. session/session-manager.lua
9. init.lua
```

**Issue:** `init.lua` loads BEFORE `session/session-manager.lua` in the fxmanifest, but `init.lua` tries to access `_G.DCESessionManagerServer` which is set by `session-manager.lua`. This creates a race condition where the module may not be available.

---

## INTENDED INITIALIZATION CHAIN (per ADR-0026)

### Resource Startup Sequence

```
/server_scripts (order matters):
1. server/services/controlcenter.lua     → Registers service
2. server/services/location-manager.lua    → Registers location service
3. server/services/location-editor.lua     → Uses LocationManager
4. server/services/organization-editor.lua → Uses OrganizationAdapter
5. server/services/plugin-registry.lua     → Registers plugin registry
6. session/session-manager.lua             → Sets _G.DCESessionManagerServer
7. init.lua                              → Safe to access session-manager

/client_scripts (order matters):
1. bootstrap/bootstrap.lua               → TRUE entry point, minimal
2. session/focus-manager.lua             → Sets _G.DCEFocusManager
3. session/session-manager-client.lua      → Client session lifecycle
4. client/nui/event-forwarder.lua        → Event forwarding
5. client/controllers/plugin-controller.lua → Plugin coordination
6. client/controllers/runtime-controller.lua → Runtime editing
7. client/nui/lifecycle-manager.lua      → REMOVED per redesign (duplicate)
```

---

## RECOMMENDED FIXES

### Fix 1: bootstrap/bootstrap.lua - Delegating Focus Release
- Remove direct SetNuiFocus calls
- Call FocusManager.ReleaseFocus via global reference or exports

### Fix 2: session/session-manager-client.lua - Remove Fallback
- Remove the inline SetNuiFocus fallback in GetFocusManager (lines 58-94)
- Use exports:GetFocusManager() only, or access _G.DCEFocusManager

### Fix 3: client/controllers/session-controller.lua - Delegate Focus
- Replace direct SetNuiFocus calls with FocusManager delegation

### Fix 4: fxmanifest.lua - Fix Client Exports
- Remove lifecycle-manager.lua from client_scripts (duplicate functionality)
- Fix GetFocusManager export to return the actual module

### Fix 5: fxmanifest.lua - Correct Loading Order
- Ensure session-manager.lua loads before init.lua in server_scripts
- Ensure focus-manager.lua loads before session-manager-client.lua in client_scripts

### Fix 6: bootstrap.html - Verify Minimal Structure
- Ensure no application initialization happens at load time
- Bootstrap JS only provides DCE.NUI.post

---

## ARCHITECTURAL PRINCIPLES VIOLATED

1. **Rule Zero - Every subsystem must justify its existence:**
   - lifecycle-manager.lua duplicates SessionManagerClient duties
   
2. **Single Focus Owner:**
   - Multiple modules call SetNuiFocus directly
   - No enforcement of centralized focus management

3. **True Lazy Initialization:**
   - Focus operations happen during bootstrap before /dce command
   - This breaks the "nothing exists until opened" principle

4. **Separation of Concerns:**
   - Client session lifecycle split between two files incorrectly

---

## SUCCESS CRITERIA FOR FIX

- [ ] Only FocusManager calls SetNuiFocus (verified by runtime trace)
- [ ] Bootstrap.lua delegates focus release to FocusManager
- [ ] No gray overlay on player spawn
- [ ] No application code executes until /dce command
- [ ] Correct module loading order with no race conditions
- [ ] Single ownership for session lifecycle (session-manager-client.lua only)
- [ ] FocusManager export accessible from client modules