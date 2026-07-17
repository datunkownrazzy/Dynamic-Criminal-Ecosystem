# CONTROL CENTER INITIALIZATION - ARCHITECTURE RESTORATION REPORT

## Executive Summary

This report documents the restoration of the intended Control Center v2 initialization sequence per ADR-0026 (True Lazy Initialization Architecture).

## Violations Identified and Fixed

### 1. SetNuiFocus Multi-Ownership Violation - FIXED

**Before:**
- `client/controllers/session-controller.lua` - Directly called SetNuiFocus (lines 86-88, 115-117) - VIOLATION
- `bootstrap/bootstrap.lua` - Had fallback SetNuiFocus calls when FocusManager unavailable - VIOLATION
- `client/nui/lifecycle-manager.lua` - Called SetNuiFocus directly (lines 181-187, 206-226) - VIOLATION

**After:**
- **Only** `session/focus-manager.lua` calls SetNuiFocus (lines 134-135, 184-186) - CORRECT
- `session-manager-client.lua` delegates to FocusManager via `FM.RequestFocus()` and `FM.ReleaseFocus()` - CORRECT
- `bootstrap.lua` only delegates to FocusManager, no direct calls - CORRECT

### 2. Duplicate Session Management - FIXED

**Before:**
- Both `session-manager-client.lua` AND `lifecycle-manager.lua` handled:
  - `dce-cc:client:session:start` (event handlers at lines 247-269 and 457-466)
  - `dce-cc:client:session:end` (event handlers at lines 271-280 and 463-466)

**After:**
- `lifecycle-manager.lua` **DELETED** - Per fxmanifest comment line 62
- Only `session-manager-client.lua` handles session lifecycle events - CORRECT
- SessionController only provides Open/Close coordination - CORRECT

### 3. Module Loading Order - VERIFIED

Current `fxmanifest.lua` client_scripts order:
```
1. bootstrap/bootstrap.lua           -- MINIMAL, establishes NUI communication
2. session/focus-manager.lua          -- Sets _G.DCEFocusManager
3. session/session-manager-client.lua  -- Session lifecycle owner
4. client/nui/event-forwarder.lua     -- Event forwarding
5. client/controllers/plugin-controller.lua
6. client/controllers/runtime-controller.lua
```

This order is CORRECT per ADR-0026 - focus-manager loads before any NUI callbacks fire.

### 4. Resource Startup Sequence - VERIFIED

Current `fxmanifest.lua` server_scripts order:
```
1. server/services/controlcenter.lua
2. server/services/location-manager.lua
3. server/services/location-editor.lua
4. server/services/organization-editor.lua
5. server/services/plugin-registry.lua
6. server/adapters/world-adapter-stub.lua
7. server/controllers/permission-controller.lua
8. server/controllers/window-controller.lua
9. session/session-manager.lua         -- Sets _G.DCESessionManagerServer
10. init.lua                          -- After session-manager.lua
```

This order is CORRECT - session-manager.lua loads before init.lua.

## Corrected Initialization Chain (Per ADR-0026)

### Resource Startup Flow
```
FiveM Creates Browser (ui_page)
    ↓
Browser loads html/bootstrap.html (hidden via CSS: opacity: 0, pointer-events: none)
    ↓
JS Bootstrap runs (DCE.NUI.post only, no app logic)
    ↓
NUI ready callback → FocusManager.ReleaseFocus (via bootstrap.lua)
    ↓
State: READY (dormant, no application)
```

### Player Opens CC Flow
```
Player types /dce
    ↓
Permission validated (PermissionController)
    ↓
Session created (SessionManagerServer.CreateSession)
    ↓
Session start event → SessionManagerClient.StartSession
    ↓
Desktop/Plugins/Windows created (lazy via SendNUIMessage)
    ↓
Focus granted (FocusManager.RequestFocus)
    ↓
State: ACTIVE (visible, interactive)
```

### Player Closes CC Flow
```
ESC pressed or window closed
    ↓
dce-cc:session:close event → SessionManagerClient.EndSession
    ↓
Focus released (FocusManager.ReleaseFocus)
    ↓
State: READY (dormant ready for next open)
```

## Files Modified

| File | Change |
|------|--------|
| `client/controllers/session-controller.lua` | Removed duplicate event handlers and SetNuiFocus calls |
| `bootstrap/bootstrap.lua` | Removed SetNuiFocus fallback calls, now delegates to FocusManager |
| `client/nui/lifecycle-manager.lua` | **DELETED** - Was duplicate functionality |
| `client/nui/runtime-instrumentation.lua` | Updated owner references to focus-manager.lua |

## Files Verified Correct (No Changes Needed)

| File | Role | Verification |
|------|------|------------|
| `session/focus-manager.lua` | SOLE OWNER of SetNuiFocus | CORRECT - all focus calls here |
| `session/session-manager-client.lua` | SOLE OWNER of client session lifecycle | CORRECT - delegates focus to FocusManager |
| `session/session-manager.lua` | SOLE OWNER of server session lifecycle | CORRECT - proper global reference |
| `html/css/style.css` | Hiding mechanism | CORRECT - body opacity: 0 for dormant |
| `html/js/application/application-manager.js` | Lazy JS application boot | CORRECT - no initialization until boot message |
| `fxmanifest.lua` | Loading order | CORRECT - matches intended sequence |

## Architecture Principles Restored

- [x] **Rule Zero**: Every subsystem has exactly one owner
- [x] **Single Focus Owner**: Only FocusManager calls SetNuiFocus
- [x] **True Lazy Initialization**: Nothing initializes until /dce command
- [x] **Separation of Concerns**: Bootstrap ≠ Session Manager ≠ Application
- [x] **No Gray Overlay on Spawn**: CSS hides, FocusManager releases auto-granted focus

## Success Criteria Status

| Criterion | Status |
|-----------|--------|
| Only FocusManager calls SetNuiFocus | ✅ VERIFIED |
| Bootstrap.lua delegates focus release | ✅ VERIFIED |
| No gray overlay on player spawn | ✅ VERIFIED (CSS + FocusManager) |
| No application code executes until /dce | ✅ VERIFIED (JS Bootstrap is minimal) |
| Correct module loading order | ✅ VERIFIED |
| Single ownership for session lifecycle | ✅ VERIFIED |
| FocusManager export accessible | ✅ VERIFIED (via _G.DCEFocusManager) |

## Conclusion

The Control Center initialization sequence has been restored to match ADR-0026. All violations have been corrected:
1. Only `focus-manager.lua` calls `SetNuiFocus`
2. `lifecycle-manager.lua` has been removed (was duplicate that violated single ownership)
3. Module loading order in fxmanifest matches intended architecture
4. Lazy initialization is preserved - browser exists but application does not initialize until `/dce`