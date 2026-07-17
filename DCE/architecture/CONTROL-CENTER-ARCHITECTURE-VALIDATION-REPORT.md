# CONTROL CENTER ARCHITECTURAL VALIDATION REPORT

## Executive Summary

This report documents the complete architectural validation and correction of the DCE Control Center v2 communication paths, identifying and fixing critical architectural violations.

---

## CRITICAL ARCHITECTURAL VIOLATIONS CORRECTED

### 1. RegisterNUICallback in Server-Side Code (CRITICAL)
**File:** `DCE/src/dce-controlcenter/server/services/organization-editor.lua`

**Issue:** `RegisterNUICallback` was being called in server-side code (lines 381-412 originally). This is a FiveM API that only exists on the client side.

**Fix:** 
- Removed all `RegisterNUICallback` calls from server code
- Added proper `RegisterNetEvent` handlers for forwarded NUI callbacks
- Events now flow: Client RegisterNUICallback → TriggerServerEvent → Server RegisterNetEvent → TriggerClientEvent → Client SendNUIMessage

### 2. Duplicate NUI Callbacks in lifecycle-manager.lua
**File:** `DCE/src/dce-controlcenter/client/nui/lifecycle-manager.lua`

**Issue:** Location NUI callbacks were duplicated between lifecycle-manager.lua and event-forwarder.lua.

**Fix:**
- Removed location/territory NUI callbacks from lifecycle-manager.lua
- Consolidated all NUI callbacks to event-forwarder.lua (single owner principle)
- Maintained ESC key and lifecycle callbacks in lifecycle-manager.lua

---

## INTEGRATION PATHS VERIFIED

### Browser → Client → Server Communication Path

```
Browser (NUI)                            Client Lua                          Server Lua
-------------------                      ---------------                      ---------------
1. Fetch POST to 'dcc-organization:list'  
   │                                      ↓
   │                            RegisterNUICallback (CLIENT ONLY)
   │                                      ↓
   │                            TriggerServerEvent('dce-cc:server:nui:organization:list')
   │                                      ↓
   └────────────────────────────→ RegisterNetEvent('dce-cc:server:nui:organization:list')
                                    │
                                    ↓
                        OrganizationEditor.ListOrganizations()
                                    │
                                    ↓
                        TriggerClientEvent('dce-cc:client:nui:organization:list')
```

### Session Lifecycle Path (Verified)

```
Player Command (/dce)                         Control Center Logic                Session Manager
-------------------                          ------------------                 ----------------
1. RegisterCommand('dce')                    
   ↓
2. TriggerServerEvent('dce-cc:server:open')
   ↓
3. ControlCenterService.RequestOpen(source)
   ↓
4. SessionManagerServer.CreateSession(source)
   ↓
5. TriggerClientEvent('dce-cc:client:session:start')
   ↓
6. SessionManagerClient.StartSession(data)
   ↓
7. SendNUIMessage({ action: 'application:boot' })
   ↓
8. DCE.Application.Boot(sessionId)
   ↓
9. DCE.Application.Activate()
   ↓
10. FocusManager.RequestFocus() → SetNuiFocus(true, true)
```

### Focus Management (Verified - Single Owner)

```
Focus Owner: DCEControlCenter/session/focus-manager.lua
- SOLE owner of SetNuiFocus calls
- SessionManagerClient delegates to FocusManager
- LifecycleManager delegates to FocusManager
- All focus changes properly logged and instrumented
```

---

## SERVICE OWNERS VERIFIED

| Service | Owner File | Responsibilities |
|---------|-----------|------------------|
| ControlCenter | server/services/controlcenter.lua | Orchestration, Session coordination |
| SessionManagerServer | session/session-manager.lua | Session registry, browser coordination |
| SessionManagerClient | session/session-manager-client.lua | Client session state, NUI messaging |
| LocationEditor | server/services/location-editor.lua | Location CRUD (forwards to WorldAdapter) |
| OrganizationEditor | server/services/organization-editor.lua | Organization CRUD (forwards to OrganizationAdapter) |
| PluginRegistry | server/services/plugin-registry.lua | Plugin registration/discovery |
| FocusManager | session/focus-manager.lua | SOLE owner of SetNuiFocus |
| EventForwarder | client/nui/event-forwarder.lua | NUI callbacks → Server events |

---

## ARCHITECTURAL PRINCIPLES ENFORCED

### 1. FiveM API Boundaries
- ✅ **RegisterNUICallback** - CLIENT ONLY (fixed in organization-editor.lua)
- ✅ **SetNuiFocus** - CLIENT ONLY, SINGLE OWNER (focus-manager.lua)
- ✅ **SendNUIMessage** - CLIENT ONLY (event-forwarder.lua, lifecycle-manager.lua)
- ✅ **TriggerClientEvent/TriggerServerEvent** - SERVER-CLIENT boundaries correct

### 2. Event-Driven Communication
- ✅ Services communicate via EventBus (when applicable)
- ✅ State changes emit events (e.g., `controlcenter:state:*`)
- ✅ No direct module-to-module calls for state changes

### 3. Single Ownership Principle
- ✅ Each NUI callback has ONE owner (event-forwarder.lua)
- ✅ Focus has ONE owner (focus-manager.lua)
- ✅ No duplicate handlers for same events

### 4. Separation of Concerns
- ✅ Adapters don't own data (they forward)
- ✅ Services follow Administrative Contract interface
- ✅ Client/Server boundaries strictly enforced

---

## CRUD OPERATIONS VALIDATED

### Location CRUD Flow
```
Browser POST 'dcc-location:list' 
  → Client RegisterNUICallback (event-forwarder.lua)
  → TriggerServerEvent('dce-cc:server:nui:location:list')
  → Server RegisterNetEvent (location-editor.lua)
  → LocationEditor.ListLocations()
  → TriggerClientEvent('dce-cc:client:nui:location:list')
  → SendNUIMessage to Browser
```

### Organization CRUD Flow
```
Browser POST 'dcc-organization:list'
  → Client RegisterNUICallback (event-forwarder.lua)
  → TriggerServerEvent('dce-cc:server:nui:organization:list')
  → Server RegisterNetEvent (organization-editor.lua)
  → OrganizationEditor.ListOrganizations()
  → TriggerClientEvent('dce-cc:client:nui:organization:list')
  → SendNUIMessage to Browser
```

---

## REMAINING CONSIDERATIONS

### Non-Blocking Operations
- All database operations should be verified as async
- Services use lazy initialization pattern
- Event handlers are non-blocking

### Missing Server Event Handlers - ALL RESOLVED
All server events referenced in event-forwarder.lua now have corresponding handlers:
- ✅ `dce-cc:server:nui:territory:list` - Territory listing (added to location-editor.lua)
- ✅ `dce-cc:server:eventbus:subscribe` - EventBus subscription (added to controlcenter.lua)
- ✅ `dce-cc:server:eventbus:unsubscribe` - EventBus unsubscription (added to controlcenter.lua)
- ✅ `dce-cc:server:nui:ready` - NUI ready notification (added to controlcenter.lua)

### Plugin Loading Integration
- Plugin registry loads on resource start
- Plugins register via GetPluginAPI export
- Plugin lifecycle (Initialize/Start/Stop/Destroy) properly implemented

---

## FILES MODIFIED

1. **organization-editor.lua** - Removed RegisterNUICallback, added RegisterNetEvent handlers for NUI callbacks
2. **location-editor.lua** - Added RegisterNetEvent handlers for NUI callbacks including territory:list
3. **event-forwarder.lua** - Consolidated all NUI callbacks, added territory response handler
4. **lifecycle-manager.lua** - Removed duplicate location callbacks, fixed source variable reference
5. **controlcenter.lua** - Added eventbus:subscribe, eventbus:unsubscribe, and nui:ready handlers
6. **plugin-registry.lua** - Added global reference `_G.DCEPluginRegistry` for cross-module access
7. **organization-manager.js** - Updated to handle async NUI responses via message events

---

## CONCLUSION

The Control Center v2 architecture has been corrected to follow FiveM best practices:
- No client APIs exist in server code
- No server APIs exist in client code (except for intended cross-boundary calls)
- Single ownership for critical operations (focus, NUI callbacks)
- Event-driven communication patterns
- Proper service boundaries with EventBus integration

The architecture is now ready for production integration testing with actual WorldAdapter and OrganizationAdapter implementations.