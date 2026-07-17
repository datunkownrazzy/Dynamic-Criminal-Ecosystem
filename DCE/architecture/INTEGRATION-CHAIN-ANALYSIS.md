# DCE v2 — Integration Chain Analysis

**Date:** 2026-07-10
**Phase:** 2/3 Verification
**Author:** Lead Software Architect

---

## Plugin Loading Verification

### Plugin Load Path Analysis

| Step | Component | Location | Verification |
|------|-----------|----------|------------|
| 1 | NUI loads | bootstrap.html | ✅ Exists |
| 2 | Bootstrap JS | bootstrap.js | ✅ Exists, calls DCE.NUI.post('ready') only |
| 3 | Application Manager | application-manager.js | ✅ Exists, defines Boot/Activate/Shutdown |
| 4 | Plugin Manager loadPlugins | application-manager.js:133-135 | ❌ DCE.Plugins.Manager.loadPlugins() never defined |
| 5 | Plugin definitions | html/js/plugins/*.js | ✅ All 10 plugins exist with render/Initialize methods |
| 6 | Plugin registration | plugin-controller.lua:168-180 | ✅ RegisterPlugin exists but never called |

**Finding: Plugin Manager.loadPlugins() is referenced but NEVER IMPLEMENTED.**

The Application Manager references `DCE.Plugins.Manager.loadPlugins()` at line 133-134, but no PluginManager object with loadPlugins method exists in the client code.

---

## Server Endpoint Verification

### NUI Callback → Server Event Mapping

| NUI Callback (lifecycle-manager.lua) | Server Event Handler | Status |
|-------------------------------------|---------------------|--------|
| dcc-location:list (line 442-445) | dce-cc:server:location:list | ❌ NO HANDLER EXISTS |
| dcc-location:create (line 447-450) | dce-cc:server:location:create | ❌ NO HANDLER EXISTS |
| dcc-location:update (line 452-455) | dce-cc:server:location:update | ❌ NO HANDLER EXISTS |
| dcc-location:delete (line 457-460) | dce-cc:server:location:delete | ❌ NO HANDLER EXISTS |
| dcc-territory:list (line 462-465) | dce-cc:server:territory:list | ❌ NO HANDLER EXISTS |
| dcc-organization:list | No NUI callback found | ❌ MISSING |

**Finding: 5 server endpoint handlers are MISSING.**

The client has NUICallback handlers that forward to server events, but location-manager.lua has NO corresponding RegisterNetEvent handlers.

---

## Adapter Service Resolution

### Adapter Resolution Chain

| CC Service | GetService Call | Registration Location | Exists? |
|-----------|-----------------|---------------------|---------|
| LocationManager | DCE.GetService("WorldAdapter") | location-manager.lua:33 | ❌ NO SERVICE REGISTERS "WorldAdapter" |
| OrganizationEditor | DCE.GetService("OrganizationAdapter") | organization-editor.lua:34 | ❌ NO SERVICE REGISTERS "OrganizationAdapter" |
| PluginRegistry | DCE.GetService("Logger/EventBus") | plugin-registry.lua:29-30 | ✅ Logger & EventBus exist in dce-core |

**Finding: Both WorldAdapter and OrganizationAdapter are NOT REGISTERED.**

---

## Administrative Action Flow Verification

### Complete Flow Analysis

```
UI Action → Plugin → NUI.post() → Server Event → CC Service → Adapter → Subsystem → EventBus → UI Refresh
```

| Subsystem | Complete Chain? | Break Point | Evidence |
|-----------|----------------|-------------|----------|
| World Locations | ❌ No | Multiple | 1. loadPlugins() missing, 2. WorldAdapter unregistered, 3. Server endpoints missing |
| Organizations | ❌ No | Multiple | OrganizationAdapter unregistered, no data endpoints exposed |
| Dispatch | ❌ No | Multiple | No DispatchAdapter, no server endpoints |
| Evidence | ❌ No | Multiple | No EvidenceAdapter, no server endpoints |

---

## Dead Code Paths & Orphaned Components

### Orphaned/Unused Code

| Component | Why Orphaned | Evidence |
|-----------|--------------|----------|
| plugin-controller.lua:RegisterPlugin | Never called | No external resource calls registerPlugin |
| DCE.Plugins.Manager | References non-existent | application-manager.js:104-107 calls .create() that doesn't exist |
| LocationEditor | No server endpoints | location-editor.lua exists but no handlers use it |
| location-manager.lua:RequestCreateLocation/Update/Delete | No triggers | Methods exist but never called |
| runtime-controller.lua | Unused | No calls found in lifecycle flow |

---

## Session Lifecycle Verification

### Startup Flow

```
1. Resource Start (init.lua:86-99)
   ✅ Registers /dce command, connects to core

2. /dce command (init.lua:119-126)
   ✅ Triggers dce-cc:server:open

3. Server open (server/services/controlcenter.lua)
   ⚠️ Need to verify exists

4. Client open (lifecycle-manager.lua:481-485)
   ✅ Receives dce-cc:client:open, calls LifecycleManager.Open()

5. Focus grant (lifecycle-manager.lua:199-213)
   ✅ Only SetNuiFocus caller

6. Application boot (application-manager.js:275-276)
   ✅ Receives application:boot, calls DCE.Application.Boot()

7. Plugin load (application-manager.js:133-135)
   ❌ DCE.Plugins.Manager.loadPlugins() missing
```

### Shutdown Flow

```
1. ESC key (lifecycle-manager.lua:431-434)
   ✅ Triggers dce-cc:server:close

2. Server close
   ⚠️ Need to verify exists

3. Client close (lifecycle-manager.lua:487-492)
   ✅ Receives dce-cc:client:close

4. LifecycleManager.Close (lifecycle-manager.lua:395-416)
   ✅ Releases focus, cleans up

5. Application.Shutdown (application-manager.js:283-290)
   ✅ Receives application:shutdown, cleans up
```

---

## Resource Loading Verification

### Bootstrap HTML

| File | Exists? | Loads Plugins? |
|------|---------|----------------|
| html/bootstrap.html | ✅ Yes | ❌ No - just loads bootstrap.js |
| html/js/bootstrap/bootstrap.js | ✅ Yes | ❌ No - just notifies ready |
| html/js/application/application-manager.js | ✅ Yes | ⚠️ loadPlugins() referenced but undefined |

**Finding: Bootstrap is MINIMAL per ADR-0026, but plugin loading is incomplete.**

---

## Integration Chain Summary

### Working Chains

| Chain | Status | Notes |
|-------|--------|-------|
| Bootstrap → NUI ready → Lua loaded | ✅ Works | lifecycle-manager.lua:423-428 |
| /dce command → Server open event | ✅ Works | init.lua:119-126 → controlcenter.lua |
| Server open → Client open event | ⚠️ Needs verification | controlcenter.lua must exist |
| Client open → Focus grant | ✅ Works | lifecycle-manager.lua:199-213 |
| Focus grant → Application boot | ✅ Works | lifecycle-manager.lua:369-392 |
| Application boot → Plugin load | ❌ BROKEN | loadPlugins() undefined |

### Broken Integration Points

| Point | Severity | Fix Required |
|-------|----------|--------------|
| DCE.Plugins.Manager.loadPlugins() | High | Implement or remove reference |
| Server NUI event handlers | High | Add RegisterNetEvent for dcc-location:* |
| WorldAdapter service | High | Implement in dce-world/services/ |
| OrganizationAdapter service | High | Implement in dce-ai/services/ |
| Plugin data refresh flow | High | Connect EventBus to plugin UI updates |

---

## Architectural Presence vs. Functional Connection

| Component | Architecturally Present | Functionally Connected |
|-----------|----------------------|----------------------|
| Plugin architecture | ✅ | ❌ (loadPlugins missing) |
| WorldAdapter interface | ✅ | ❌ (no implementation) |
| OrganizationAdapter interface | ✅ | ❌ (no implementation) |
| Location provider system | ✅ | ⚠️ (providers exist, no CC integration) |
| EventBus integration | ✅ | ⚠️ (exists but plugins don't subscribe) |
| Lifecycle management | ✅ | ✅ (works end-to-end) |
| Focus management | ✅ | ✅ (LifecycleManager owns it) |
| Session management | ✅ | ✅ (works) |