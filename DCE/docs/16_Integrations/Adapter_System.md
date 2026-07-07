# DCE Adapter System

**Status:** Accepted
**Version:** 1.0
**Owner:** Architecture
**Dependencies:** DCE-0001 (Service Registry), ServiceContracts.md

---

## Purpose

The DCE Adapter System provides a vendor-neutral integration layer for third-party resources. Adapters translate DCE's generic domain operations into the format expected by specific external systems (CAD/MDT, evidence/inventory, analytics).

This document explains how adapters work, how to implement them, and the integration patterns used.

---

## Architecture

### Adapter Pattern

```
DCE Core / Services
       │
       ▼
Generic Service Call
       │
       ▼
Active Adapter (from registry)
       │
       ▼
External Resource API
```

### Key Principles

1. **Adapters never own data** - Services own their data; adapters only translate
2. **Fallback always available** - Native adapters work when third-party unavailable
3. **Runtime detection** - Adapters check for resource availability at runtime
4. **Priority selection** - Multiple adapters resolved by priority when installed

---

## Supported Adapter Types

| Category | Purpose | Native Fallback | Third-Party Examples |
|---|---|---|---|
| Dispatch | Create/update dispatch calls | Yes | ERS, Sonoran CAD, PS-Dispatch |
| Evidence | Create/transfer/verify evidence | Yes | ERS Evidence, ps-inventory, qb-inventory |
| MDT | Push intel to MDT systems | No | Sonoran CAD MDT, ps-mdt |
| Analytics | Export metrics for analysis | No | Custom analytics plugins |
| Scenario | Scenario template extensions | No | Custom scenario packs |

---

## Dispatch Adapter

### Configuration

```lua
Config.Dispatch = {
    Integration = {
        Mode = "native" | "ers" | "custom",  -- Default: "native"
        ResourceName = "ers",                -- For ERS adapter
        Adapter = customAdapterTable,          -- For custom mode
        EnableStandaloneFallback = true,       -- Fall back to native
    }
}
```

### IDispatchAdapter Interface

All dispatch adapters must implement this interface:

```lua
--- @class IDispatchAdapter
--- Dispatch Adapter Interface: Integrates with external CAD/MDT systems
---@field Name string           -- Adapter identifier
---@field Priority number        -- Selection priority (higher wins)
---@field IsAvailable fun(self): boolean
---@field CreateCall fun(self, data: IDispatchCallSummary)
---@field UpdateCall fun(self, data: IDispatchCallSummary)
---@field ResolveCall fun(self, data: IDispatchCallSummary)
---@field CancelCall fun(self, data: IDispatchCallSummary)
---@field GetDiagnostics fun(self): table
---@field HealthCheck fun(self): boolean
```

### Dispatch Call Summary

```lua
--- @class IDispatchCallSummary
--- Dispatch call data structure
---@field callId string
---@field incidentId string
---@field description string
---@field priority string
---@field status string
---@field regionId string
---@field organizationId? string
---@field scenarioId? string
---@field created timestamp
```

### Native Dispatch Adapter

Located in: `dce-dispatch/adapters/native.lua`

- Always available (`IsAvailable()` returns true)
- No external integration
- Used when no third-party CAD installed
- Provides minimal functionality for testing

### ERS Dispatch Adapter

Located in: `dce-dispatch/adapters/ers.lua`

- Checks `GetResourceState("ers")` at startup
- Uses `exports.ers.CreateDispatchCall()` for integration
- Falls back to native if ERS unavailable

---

## Evidence Adapter

### Configuration

```lua
Config.Evidence = {
    Integration = {
        Mode = "native" | "ers" | "custom",
        EnableStandaloneFallback = true,
    }
}
```

### IEvidenceAdapter Interface

```lua
--- @class IEvidenceAdapter
--- Evidence/Inventory Adapter Interface
---@field Name string
---@field Priority number
---@field IsAvailable fun(self): boolean
---@field CreateEvidence fun(self, data: IEvidenceSummary)
---@field TransferEvidence fun(self, data: IEvidenceSummary)
---@field VerifyEvidence fun(self, data: IEvidenceSummary)
---@field LinkToCase fun(self, evidenceId: string, caseId: string)
---@field GetDiagnostics fun(self): table
---@field HealthCheck fun(self): boolean
```

### Evidence Summary

```lua
--- @class IEvidenceSummary
--- Evidence data structure
---@field evidenceId string
---@field type string
---@field description string
---@field source string
---@field organizationId? string
---@field scenarioId? string
---@field confidence? number
```

---

## MDT Adapter

### IMDTAdapter Interface

```lua
--- @class IMDTAdapter
--- MDT Adapter Interface
---@field Name string
---@field Priority number
---@field IsAvailable fun(self): boolean
---@field PushIntelTier fun(self, orgId: string, tier: number)
---@field SyncCaseFile fun(self, caseData: table)
---@field CreateWarrant fun(self, warrantData: table)
---@field UpdateWarrant fun(self, warrantId: string, updates: table)
---@field GetDiagnostics fun(self): table
---@field HealthCheck fun(self): boolean
```

---

## Adapter Lifecycle

### Detection

Adapters are detected at service startup:

```lua
function DetectAndLoadAdapter()
    local mode = Config.Dispatch.Integration.Mode
    
    if mode == "ers" then
        if GetResourceState("ers") == "started" then
            return _G.DCEERSDispatchAdapter.New()
        end
        -- Falls through to native
    end
    
    if mode == "custom" then
        return Config.Dispatch.Integration.Adapter
    end
    
    return _G.DCENativeDispatchAdapter.New()
end
```

### Runtime Switching

The framework supports adapter switching at runtime:

```lua
function SwitchAdapter(newMode)
    local adapter = DetectAndLoadAdapter()
    if adapter then
        DispatchService.SetAdapter(adapter)
        DCE.Emit("dispatch:adapter:switched", {
            mode = newMode,
            adapterName = adapter.Name,
        })
    end
end
```

### Health Monitoring

All adapters must implement health checks:

```lua
function MonitorAdapterHealth()
    if not ActiveAdapter:HealthCheck() then
        DCE.Emit("integration:adapter:unhealthy", {
            adapter = ActiveAdapter.Name,
        })
        -- Consider fallback activation
    end
end
```

---

## Creating Custom Adapters

### Step 1: Implement the Interface

```lua
local MyCADAdapter = {}
MyCADAdapter.__index = MyCADAdapter

function MyCADAdapter.New(config)
    local self = setmetatable({}, MyCADAdapter)
    self.config = config or {}
    self.Name = "MyCustomCAD"
    self.Priority = 80  -- Higher than default adapters
    return self
end

function MyCADAdapter:IsAvailable()
    return GetResourceState and GetResourceState("my-cad") == "started"
end

function MyCADAdapter:CreateCall(callData)
    if not self:IsAvailable() then return end
    exports["my-cad"]:CreateCall(self:TransformCall(callData))
end

-- Transform DCE format to your CAD format
function MyCADAdapter:TransformCall(callData)
    return {
        title = callData.description,
        priority = self:MapPriority(callData.priority),
        -- ... other transformations
    }
end
```

### Step 2: Register with DCE

```lua
-- Via config
Config.Dispatch.Integration.Mode = "custom"
Config.Dispatch.Integration.Adapter = MyCADAdapter

-- Or via plugin SDK
DCE:RegisterDispatchAdapter({
    Name = "MyCustomCAD",
    Priority = 80,
    -- ... methods
})
```

### Step 3: Implement Health Checks

```lua
function MyCADAdapter:GetDiagnostics()
    return {
        status = self:IsAvailable() and "active" or "inactive",
        health = self:IsAvailable() and 100 or 0,
        latency = self:MeasureLatency(),
        errors = self.errorCount or 0,
        capabilities = { "CreateCall", "UpdateCall", "ResolveCall" },
    }
end
```

---

## Adapter Events

| Event | Purpose |
|---|---|
| `integration:adapter:detected` | New adapter found at startup |
| `integration:adapter:unhealthy` | Adapter health check failed |
| `integration:adapter:switched` | Adapter changed at runtime |

---

## Best Practices

1. **Always implement IsAvailable()** - Check resource state at runtime
2. **Provide GetDiagnostics()** - Expose adapter health for admin UI
3. **Handle nil gracefully** - If adapter unavailable, don't error
4. **Log state changes** - Use DCE.Log for adapter lifecycle events
5. **Transform consistently** - Same DCE data should produce same external format
6. **Support priority** - Allow admin to override selection order

---

## Testing Adapters

For development and CI:

```lua
-- Test with native adapter
Config.Dispatch.Integration.Mode = "native"

-- Test with mock adapter
local MockAdapter = {
    CreateCall = function(data) print("Mock call: " .. data.description) end,
    IsAvailable = function() return true end,
}

-- Verify adapter interface
assert(adapter.CreateCall, "Missing CreateCall method")
assert(adapter.IsAvailable, "Missing IsAvailable method")
```

---

## Troubleshooting

### Adapter Not Detected

- Check `Config.*.Integration.Mode` value
- Verify resource name in `Config.*.Integration.ResourceName`
- Confirm resource is running (`GetResourceState`)

### Calls Not Reaching CAD

- Check `IsAvailable()` returns true
- Verify adapter has required export methods
- Review adapter logs for errors

### Wrong Adapter Selected

- Check priority values
- Verify `EnableStandaloneFallback` setting
- Use Admin UI to view active adapter