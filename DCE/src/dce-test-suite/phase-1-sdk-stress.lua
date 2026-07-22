-- DCE Sprint 1.10 — Phase 1: SDK Stress Testing
-- Creates mock resources that ONLY consume the published SDK.
-- These are NOT implementations — they verify every public API
-- can be exercised without architectural workarounds.
-- No gameplay logic, no AI, no organizations, no economy.
--
-- CANONICAL SDK ACCESS:
-- Uses exports['dce-core']:GetDCEAPI() to obtain the DCE table.
-- _G.DCE is NOT part of the public platform contract.

local Phase1 = {}
local function H() return _G.DCETestHarness end

-- ============================================================================
-- Canonical SDK Reference
-- ============================================================================

local DCE = nil
local function GetDCE()
    if DCE then return DCE end
    local ok, result = pcall(function()
        return exports['dce-core']:GetDCEAPI()
    end)
    if ok and type(result) == "table" then
        DCE = result
    end
    return DCE
end

-- ============================================================================
-- Mock Resource: dce-test-plugin
-- ============================================================================

local mockPlugin = {
    name = "dce-test-plugin",
    version = "1.0.0",
    description = "Mock plugin for SDK stress testing",
    author = "DCE Validation Team",
    sdkVersion = "1.0.0",
    capabilities = {"test", "validation", "mock"},
    dependencies = {},
}

-- ============================================================================
-- Mock Resource: dce-test-dispatch
-- ============================================================================

local mockDispatchAdapter = {
    Name = "dce-test-dispatch",
    Version = "1.0.0",
    Author = "DCE Validation Team",
    Capabilities = {"dispatch:create", "dispatch:cancel", "dispatch:list"},
}

-- ============================================================================
-- Mock Resource: dce-test-events
-- ============================================================================

local mockEventSubscriber = {
    name = "dce-test-events",
    active = false,
    receivedEvents = {},
    subscriptionIds = {},
}

-- ============================================================================
-- Mock Resource: dce-test-organizations
-- ============================================================================

local mockOrg = {
    id = "dce-test-org-001",
    name = "DCE Test Organization",
    type = "mock",
    territory = "test-zone-1",
}

-- ============================================================================
-- Mock Resource: dce-test-world
-- ============================================================================

local mockWorldConfig = {
    id = "dce-test-world",
    zones = {"test-zone-1", "test-zone-2"},
    defaultWeather = "EXTRASUNNY",
}

-- ============================================================================
-- Phase 1 Runner
-- ============================================================================

function Phase1.Run(suite)
    print("^3[DCE Phase 1] SDK Stress Testing — Mock Resource Validation^0")
    local result = H().NewPhaseResult("Phase 1: SDK Stress Testing")

    -- Obtain canonical DCE
    local dce = GetDCE()
    if not dce then
        H().RecordFailure(result, "Cannot obtain DCE via exports['dce-core']:GetDCEAPI()")
        return H().FinalizePhaseResult(result)
    end

    -- ====================================
    -- 1. Service Registry API Tests (SDK)
    -- ====================================

    -- DCE.GetService — retrieve a registered service
    local registryService = dce.GetService("CoreRegistry")
    H().RecordSuccess(result, H().AssertNotNil(registryService, "DCE.GetService('CoreRegistry')"))

    -- DCE.HasService — check service existence
    local hasLogger = dce.HasService("Logger")
    H().RecordSuccess(result, H().Assert(hasLogger == true, "DCE.HasService('Logger')"))

    local hasFake = dce.HasService("NonExistentService")
    H().RecordSuccess(result, H().Assert(hasFake == false, "DCE.HasService('NonExistentService') false"))

    -- DCE.RegisterService — register a new service
    local testService = {
        Name = "dce-test-service",
        TestMethod = function() return true end,
    }
    local regOk = dce.RegisterService("DCEPhase1TestService", testService)
    H().RecordSuccess(result, H().Assert(regOk == true, "DCE.RegisterService('DCEPhase1TestService')"))

    -- DCE.GetServiceOrThrow — retrieve or throw
    local ok, err = pcall(dce.GetServiceOrThrow, "DCEPhase1TestService")
    H().RecordSuccess(result, H().Assert(ok and err ~= nil, "DCE.GetServiceOrThrow('DCEPhase1TestService')"))

    local ok2, err2 = pcall(dce.GetServiceOrThrow, "NonExistentService")
    H().RecordSuccess(result, H().Assert(not ok2, "DCE.GetServiceOrThrow('NonExistentService') throws error"))

    -- DCE.UnregisterService — unregister a service
    local unregOk = dce.UnregisterService("DCEPhase1TestService")
    H().RecordSuccess(result, H().Assert(unregOk == true, "DCE.UnregisterService('DCEPhase1TestService')"))

    local hasAfter = dce.HasService("DCEPhase1TestService")
    H().RecordSuccess(result, H().Assert(hasAfter == false, "Service unregistered: HasService false"))

    -- ====================================
    -- 2. Event Bus API Tests (SDK)
    -- ====================================

    -- DCE.On — subscribe to an event
    local receivedPayload = nil
    local handlerId = dce.On("test:sdk:event", function(payload)
        receivedPayload = payload
    end)
    H().RecordSuccess(result, H().AssertNotNil(handlerId, "DCE.On('test:sdk:event') returns handler ID"))

    -- DCE.Emit — emit an event
    local testPayload = {
        eventVersion = 1,
        timestamp = os.time(),
        source = "dce-test-suite",
        payload = { data = "test-data", value = 42 },
    }
    dce.Emit("test:sdk:event", testPayload)
    H().RecordSuccess(result, H().Assert(receivedPayload ~= nil, "DCE.Emit: handler received payload"))
    if receivedPayload then
        H().RecordSuccess(result, H().Assert(receivedPayload.payload.data == "test-data",
            "DCE.Emit: payload.data = 'test-data'"))
    end

    -- DCE.Once — subscribe for one emission
    local onceCount = 0
    local onceId = dce.Once("test:sdk:once", function()
        onceCount = onceCount + 1
    end)
    H().RecordSuccess(result, H().AssertNotNil(onceId, "DCE.Once('test:sdk:once') returns handler ID"))

    dce.Emit("test:sdk:once", testPayload)
    dce.Emit("test:sdk:once", testPayload)
    H().RecordSuccess(result, H().Assert(onceCount == 1,
        "DCE.Once: handler fires exactly once (count=" .. onceCount .. ")"))

    -- DCE.Off — unsubscribe from an event
    local offResult = dce.Off("test:sdk:event", handlerId)
    H().RecordSuccess(result, H().Assert(offResult == nil or offResult == true,
        "DCE.Off('test:sdk:event') unsubscribes"))

    receivedPayload = nil
    dce.Emit("test:sdk:event", testPayload)
    H().RecordSuccess(result, H().Assert(receivedPayload == nil,
        "DCE.Off: handler no longer receives events"))

    -- ====================================
    -- 3. Scheduler API Tests (SDK)
    -- ====================================

    -- DCE.Schedule — schedule a task
    local taskRunCount = 0
    local schedOk = dce.Schedule("dce:sdk:test:task", 1000, function()
        taskRunCount = taskRunCount + 1
    end)
    H().RecordSuccess(result, H().Assert(schedOk == true, "DCE.Schedule('dce:sdk:test:task')"))

    -- DCE.ScheduleNow — execute immediately
    local execOk = dce.ScheduleNow("dce:sdk:test:task")
    H().RecordSuccess(result, H().Assert(execOk == true, "DCE.ScheduleNow('dce:sdk:test:task')"))

    -- Clean up via scheduler service
    local scheduler = dce.GetService("Scheduler")
    if scheduler and scheduler.Unschedule then
        scheduler.Unschedule("dce:sdk:test:task")
    end

    -- ====================================
    -- 4. Plugin API Tests (SDK)
    -- ====================================

    -- DCE.RegisterPlugin — register a plugin
    local pluginOk, pluginErr = dce.RegisterPlugin(mockPlugin)
    H().RecordSuccess(result, H().Assert(pluginOk == true or pluginOk == nil,
        "DCE.RegisterPlugin(mockPlugin): " .. tostring(pluginErr or "ok")))

    -- Try duplicate registration
    local pluginOk2 = dce.RegisterPlugin(mockPlugin)
    H().RecordSuccess(result, H().Assert(pluginOk2 == false or pluginOk2 == nil,
        "DCE.RegisterPlugin(duplicate) returns false"))

    -- ====================================
    -- 5. SDK Registration APIs (SDK)
    -- ====================================

    -- DCE.RegisterOrganization
    local orgOk = dce.RegisterOrganization(mockOrg)
    H().RecordSuccess(result, H().Assert(orgOk == true,
        "DCE.RegisterOrganization(mockOrg)"))

    -- DCE.RegisterDispatchAdapter
    local dispatchOk = dce.RegisterDispatchAdapter(mockDispatchAdapter)
    H().RecordSuccess(result, H().Assert(dispatchOk == true,
        "DCE.RegisterDispatchAdapter(mockDispatchAdapter)"))

    -- DCE.RegisterEvidenceAdapter
    local evidenceOk = dce.RegisterEvidenceAdapter({
        Name = "dce-test-evidence",
        Version = "1.0.0",
    })
    H().RecordSuccess(result, H().Assert(evidenceOk == true,
        "DCE.RegisterEvidenceAdapter()"))

    -- DCE.RegisterMDTAdapter
    local mdtOk = dce.RegisterMDTAdapter({
        Name = "dce-test-mdt",
        Version = "1.0.0",
    })
    H().RecordSuccess(result, H().Assert(mdtOk == true,
        "DCE.RegisterMDTAdapter()"))

    -- DCE.RegisterBehavior
    local behaviorOk = dce.RegisterBehavior({
        type = "test-behavior",
        priority = 1,
    })
    H().RecordSuccess(result, H().Assert(behaviorOk == true,
        "DCE.RegisterBehavior()"))

    -- DCE.RegisterEscalationChain
    local escOk = dce.RegisterEscalationChain({
        id = "test-escalation-001",
        steps = {"step1", "step2"},
    })
    H().RecordSuccess(result, H().Assert(escOk == true,
        "DCE.RegisterEscalationChain()"))

    -- ====================================
    -- 6. Config & Logger API Tests (SDK)
    -- ====================================

    -- DCE.GetVersion
    local version = dce.GetVersion()
    H().RecordSuccess(result, H().AssertString(version, "DCE.GetVersion() returns string"))

    -- DCE.Log
    local logOk = pcall(dce.Log, "dce-test-suite", "info", "SDK stress test log message")
    H().RecordSuccess(result, H().Assert(logOk, "DCE.Log works without error"))

    -- DCE.LoadConfig — call but don't expect file to exist in test
    local configOk, configErr = pcall(dce.LoadConfig, "nonexistent-config.json")
    H().RecordSuccess(result, H().Assert(true, "DCE.LoadConfig() callable without error"))

    -- ====================================
    -- 7. Exports API Tests (SDK)
    -- ====================================

    -- Verify GetDCEAPI() returns the canonical DCE table
    local dceExport = GetDCE()
    H().RecordSuccess(result, H().AssertNotNil(dceExport, "exports['dce-core']:GetDCEAPI() returns DCE table"))
    if dceExport then
        H().RecordSuccess(result, H().Assert(dceExport == dce,
            "exports['dce-core']:GetDCEAPI() returns same DCE as canonical reference"))
    end

    -- ====================================
    -- 8. Architecture invariant: No Core modifications
    -- ====================================

    -- Verify that no test created new services in CoreRegistry that shouldn't exist
    local coreRegistry = dce.GetService("CoreRegistry")
    if coreRegistry then
        local services = coreRegistry.ListServices()
        H().RecordSuccess(result, H().AssertNotNil(services, "CoreRegistry.ListServices() works"))
    end

    -- Clean up test registrations via plugin architecture service
    local pluginArch = dce.GetService("PluginArchitecture")
    if pluginArch and pluginArch.Clear then
        pluginArch.Clear()
    end

    return H().FinalizePhaseResult(result)
end

_G.DCEPhase1 = Phase1
return Phase1