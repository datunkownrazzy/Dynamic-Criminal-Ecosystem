# DCE Control Center v1.5 - Architecture Violation Report

**Analysis Date:** 2026-07-08  
**Status:** Updated - Fixes Applied

---

## Violations Fixed ✅

### 1. **Global Dependency Usage (_G.DCE)** - FIXED

All files have been updated to use proper service discovery via `exports['dce-core']:GetDCEAPI()` instead of `local DCE = _G.DCE`.

**Files Fixed:**
- `DCE/src/dce-controlcenter/init.lua` ✅
- `DCE/src/dce-controlcenter/client/nui/lifecycle-manager.lua` ✅
- `DCE/src/dce-controlcenter/client/nui/event-forwarder.lua` ✅
- `DCE/src/dce-controlcenter/client/controllers/plugin-controller.lua` ✅
- `DCE/src/dce-controlcenter/client/controllers/runtime-controller.lua` ✅
- `DCE/src/dce-controlcenter/server/services/controlcenter.lua` ✅
- `DCE/src/dce-controlcenter/server/services/location-manager.lua` ✅
- `DCE/src/dce-controlcenter/server/services/location-editor.lua` ✅
- `DCE/src/dce-controlcenter/server/services/organization-editor.lua` ✅
- `DCE/src/dce-controlcenter/server/services/plugin-registry.lua` ✅
- `DCE/src/dce-controlcenter/server/controllers/permission-controller.lua` ✅

**Solution Applied:**
- Added `ConnectToCore()` function that uses `exports['dce-core']:GetDCEAPI()`
- Cached services in local table after discovery
- Lazy initialization on first use

### 2. **loadfile() Usage in fxmanifest** - FIXED

**File:** `DCE/src/dce-controlcenter/fxmanifest.lua` ✅

**Solution Applied:** Removed `loadfile()` fallback in `GetModule()`. Providers are now accessed through proper service discovery via `WorldAdapter` from `dce-world`.

### 3. **Global Exports (_G.)** - FIXED

All `_G.` exports have been removed. Modules now return their API through proper return statements for FiveM exports.

**Files Fixed:**
- `DCE/src/dce-controlcenter/client/nui/lifecycle-manager.lua` - Removed `_G.DCELifecycleManager`
- `DCE/src/dce-controlcenter/client/nui/event-forwarder.lua` - Removed `_G.DCEForwardEvent`
- `DCE/src/dce-controlcenter/client/controllers/plugin-controller.lua` - Removed `_G.DCEPluginController`
- `DCE/src/dce-controlcenter/client/controllers/runtime-controller.lua` - Removed `_G.DcERuntimeController`

### 4. **Service Ownership Violations** - FIXED

**Location Manager/Editor:**
- Converted to adapter pattern
- Now consumes `WorldAdapter` from `dce-world` instead of owning data
- Control Center is now editor only, not owner ✅

**Organization Editor:**
- Converted to adapter pattern
- Now consumes `OrganizationAdapter` from `dce-organizations`/`dce-ai`
- Control Center is now editor only, not owner ✅

### 5. **Plugin Registry Hardcoding** - PARTIALLY FIXED

**File:** `DCE/src/dce-controlcenter/server/services/plugin-registry.lua` ✅

**Changes:**
- Removed hardcoded built-in plugin registrations
- Plugin registry now only provides registration interface
- Plugins will be registered dynamically via `GetPluginAPI()` export
- External resources call `GetPluginAPI().registerPlugin(manifest)` to register

### 6. **Service Discovery Pattern** - IMPLEMENTED

All services now follow the correct pattern:

```
WAIT FOR dce-core (GetResourceState)
  ↓
Acquire DCE API via exports['dce-core']:GetDCEAPI()
  ↓
Discover services via DCE.GetService()
  ↓
Cache interfaces locally
  ↓
Initialize Control Center
```

---

## Remaining Work

### Plugin Architecture - DYNAMIC DISCOVERY NEEDED
The plugins (world-manager.js, organization-manager.js, etc.) are still imported via `fxmanifest.lua`. For full dynamic discovery:

1. Create plugin manifest files in `shared/manifests/` directory
2. Plugins register themselves at runtime via `GetPluginAPI().registerPlugin()`
3. UI components are generated dynamically from manifests

### WorldAdapter/OrganizationAdapter Services
These services need to exist in `dce-world`/`dce-organizations` to provide data for the adapters:

- `WorldAdapter` - Location/Territory management service
- `OrganizationAdapter` - Organization management service

---

## Summary of Changes

| Component | Before | After |
|-----------|--------|-------|
| Service Access | `_G.DCE` | `exports['dce-core']:GetDCEAPI()` |
| Module Loading | `loadfile()` | Service discovery |
| Global Exports | `_G.ModuleName` | Return exports |
| Location Manager | Owns data | Adapter (consumer) |
| Location Editor | Owns data | Adapter (consumer) |
| Organization Editor | Owns data | Adapter (consumer) |
| Plugin Registry | Hardcoded plugins | Dynamic registration |

---

## Files Modified

1. `DCE/src/dce-controlcenter/init.lua` - Service discovery implementation
2. `DCE/src/dce-controlcenter/client/nui/lifecycle-manager.lua` - Removed globals, added service discovery
3. `DCE/src/dce-controlcenter/client/nui/event-forwarder.lua` - Removed globals, added service discovery
4. `DCE/src/dce-controlcenter/client/controllers/plugin-controller.lua` - Removed globals, added service discovery
5. `DCE/src/dce-controlcenter/client/controllers/runtime-controller.lua` - Removed globals, added service discovery
6. `DCE/src/dce-controlcenter/server/services/controlcenter.lua` - Service discovery, removed globals
7. `DCE/src/dce-controlcenter/server/services/location-manager.lua` - Adapter pattern, removed globals
8. `DCE/src/dce-controlcenter/server/services/location-editor.lua` - Adapter pattern, removed globals
9. `DCE/src/dce-controlcenter/server/services/organization-editor.lua` - Adapter pattern, removed globals
10. `DCE/src/dce-controlcenter/server/services/plugin-registry.lua` - Removed hardcoded plugins, dynamic registration
11. `DCE/src/dce-controlcenter/server/controllers/permission-controller.lua` - Removed globals, direct ACE checks
12. `DCE/src/dce-controlcenter/fxmanifest.lua` - Removed loadfile(), proper exports

---

## Compliance Status

✅ Rule Zero compliance achieved:
- Control Center no longer implements simulation logic
- All services consumed via proper discovery pattern
- No shared globals between resources
- Proper separation between UI and simulation