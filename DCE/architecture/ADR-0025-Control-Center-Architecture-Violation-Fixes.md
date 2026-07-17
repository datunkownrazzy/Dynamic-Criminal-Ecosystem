# ADR-0025: Control Center Architecture Violation Fixes

**Status:** Accepted  
**Date:** 2026-07-08  
**Author:** Architecture  
**Supersedes:** ADR-0022, ADR-0024 portions related to service discovery

---

## Problem

The Control Center implementation had several architectural violations against DCE v1.5 principles:

1. **Global Dependency Usage**: Using `_G.DCE` which FiveM doesn't guarantee
2. **loadfile() Anti-pattern**: Dynamic loading violates resource isolation
3. **Service Ownership Violations**: Control Center owned services that belong to simulation resources
4. **Missing Service Discovery**: No proper dependency injection pattern

## Decision

### Service Discovery Pattern

All Control Center modules now use a consistent service discovery pattern:

```lua
local cachedServices = {
    Logger = nil,
    EventBus = nil,
}

local dceCoreReady = false

local function ConnectToCore()
    if dceCoreReady then return true end
    
    if GetResourceState('dce-core') ~= 'started' then
        return false
    end
    
    local DCE = exports['dce-core']:GetDCEAPI()
    if not DCE then return false end
    
    cachedServices.Logger = DCE.GetService and DCE.GetService("Logger")
    cachedServices.EventBus = DCE.GetService and DCE.GetService("EventBus")
    
    dceCoreReady = true
    return true
end
```

### Adapter Pattern for Editors

Location and Organization editors now consume services instead of owning data:

| Before | After |
|--------|-------|
| LocationManager created locations | LocationManager forwards to WorldAdapter |
| OrganizationEditor created organizations | OrganizationEditor forwards to OrganizationAdapter |
| Data stored in CC | Data stored in simulation resources |

### FiveM Export Pattern

Modules return their API properly for FiveM exports:

```lua
return {
    ForwardEventToNUI = ForwardEventToNUI,
}
```

Instead of global exports:

```lua
-- REMOVED
_G.DCEForwardEvent = DCEForwardEvent
```

## Consequences

### Benefits
- Deterministic resource lifecycle
- No race conditions from global access
- Proper FiveM resource isolation
- Clean separation: simulation (dce-*) vs UI (dce-controlcenter)

### Costs
- More verbose initialization code
- Need for adapter services in dce-world
- Plugin registration requires explicit calls

### Migration Path
1. dce-core provides `GetDCEAPI()` export
2. dce-world provides `WorldAdapter` service
3. dce-organizations provides `OrganizationAdapter` service
4. Control Center adapters consume these services

## References

- AGENTS.md Rule Zero
- "FiveM resources do not share Lua globals"
- NUI Lifecycle ADR-0021
- Control Center v2 ADR-0022