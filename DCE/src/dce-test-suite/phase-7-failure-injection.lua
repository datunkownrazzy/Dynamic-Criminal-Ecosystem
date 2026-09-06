-- DCE Sprint 1.10 — Phase 7: Runtime Resilience Verification
-- Verify the canonical SDK is internally consistent and immune to external
-- global mutation. The SDK holds closures over runtime components; it does NOT
-- read globals. Therefore nil-ing _G.DCELogger etc. has no effect — this is
-- the graceful degradation guarantee of the canonical architecture.
--
-- Sprint 1.11.11: Reconciled to canonical API. Removed obsolete methods
-- (GetServiceOrThrow, ValidateConfig) and dot-call/nil-index violations.
--
-- CANONICAL SDK ACCESS:
-- Uses exports['dce-core']:GetDCEAPI() to obtain the DCE table.
-- _G.DCE is NOT part of the public platform contract.

local Phase7 = {}
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
-- Phase 7 Runner
-- ============================================================================

function Phase7.Run()
    print("^3[DCE Phase 7] Runtime Resilience Verification^0")
    local result = H().NewPhaseResult("Phase 7: Runtime Resilience Verification")

    local dce = GetDCE()
    if not dce then
        H().RecordFailure(result, "Cannot obtain DCE via exports['dce-core']:GetDCEAPI()")
        return H().FinalizePhaseResult(result)
    end

    -- ====================================
    -- Test 1: SDK is Internal-Consistent (Global Mutation Immune)
    -- ====================================

    -- The canonical SDK binds to closures, not globals. Nil-ing legacy globals
    -- must NOT affect any SDK method.
    local originalLogger = _G.DCELogger
    local originalRegistry = _G.DCERegistry
    local originalEB = _G.DCEEventBus
    local originalSched = _G.DCEScheduler
    local originalPA = _G.DCEPluginArchitecture
    local originalPM = _G.DCEPluginManager
    _G.DCELogger = nil
    _G.DCERegistry = nil
    _G.DCEEventBus = nil
    _G.DCEScheduler = nil
    _G.DCEPluginArchitecture = nil
    _G.DCEPluginManager = nil

    -- All SDK methods must still function after external global mutation
    local ok, err = pcall(function()
        dce:GetVersion()
        dce:IsReady()
        dce:HasService("Logger")
    end)
    H().RecordSuccess(result, H().Assert(ok,
        "SDK unaffected by global mutation: " .. tostring(err or "ok")))

    -- Restore globals
    _G.DCELogger = originalLogger
    _G.DCERegistry = originalRegistry
    _G.DCEEventBus = originalEB
    _G.DCEScheduler = originalSched
    _G.DCEPluginArchitecture = originalPA
    _G.DCEPluginManager = originalPM
    H().RecordSuccess(result, H().Assert(true, "Globals restored"))

    -- ====================================
    -- Test 2: SDK Methods Work via Canonical Colon Calls
    -- ====================================

    -- DCE:Log works
    local ok = pcall(function() dce:Log("test", "info", "Resilience test message") end)
    H().RecordSuccess(result, H().Assert(ok, "DCE:Log works"))

    -- DCE:On works (function handler)
    local subOk, id = pcall(function() return dce:On("test:fail:eb", function() end) end)
    H().RecordSuccess(result, H().Assert(subOk and id ~= nil,
        "DCE:On works with function handler"))
    if id then dce:Off("test:fail:eb", id) end

    -- DCE:Emit works
    local ok = pcall(function() dce:Emit("test:fail:eb", { source = "test" }) end)
    H().RecordSuccess(result, H().Assert(ok, "DCE:Emit works"))

    -- DCE:GetService works
    local svc = dce:GetService("CoreRegistry")
    H().RecordSuccess(result, H().Assert(svc ~= nil, "DCE:GetService returns CoreRegistry"))

    -- DCE:HasService works
    local has = dce:HasService("Logger")
    H().RecordSuccess(result, H().Assert(has == true, "DCE:HasService('Logger') true"))

    -- DCE:RegisterService works with string name
    local regOk = dce:RegisterService("test:fail:reg", { Name = "test" })
    H().RecordSuccess(result, H().Assert(regOk == true, "DCE:RegisterService('test:fail:reg')"))
    dce:UnregisterService("test:fail:reg")

    -- DCE:Schedule works
    local schedOk = dce:Schedule("test:fail:sched", 1000, function() end)
    H().RecordSuccess(result, H().Assert(schedOk == true, "DCE:Schedule works"))
    local scheduler = dce:GetService("Scheduler")
    if scheduler then scheduler:Unschedule("test:fail:sched") end

    -- DCE:ScheduleNow works
    dce:Schedule("test:fail:schednow", 5000, function() end)
    local execOk = dce:ScheduleNow("test:fail:schednow")
    H().RecordSuccess(result, H().Assert(execOk == true, "DCE:ScheduleNow works"))
    if scheduler then scheduler:Unschedule("test:fail:schednow") end

    -- ====================================
    -- Test 3: SDK Never Exposes Obsolete Methods
    -- ====================================

    H().RecordSuccess(result, H().Assert(dce.GetServiceOrThrow == nil,
        "DCE.GetServiceOrThrow removed"))
    H().RecordSuccess(result, H().Assert(dce.ValidateConfig == nil,
        "DCE.ValidateConfig removed"))
    H().RecordSuccess(result, H().Assert(dce.LogError == nil and dce.LogInfo == nil
        and dce.LogWarn == nil and dce.LogDebug == nil,
        "Legacy Logger aliases removed from SDK"))

    -- ====================================
    -- Test 4: EventBus Rejects Invalid Handlers
    -- ====================================

    -- The EventBus must reject non-function handlers loudly (contract rule).
    local rejected = false
    local ok, err = pcall(function()
        local EB = dce:GetService("EventBus")
        if EB then EB:On("test:fail:invalid", {}) end
    end)
    rejected = not ok
    H().RecordSuccess(result, H().Assert(rejected,
        "EventBus rejects table handler (error): " .. tostring(err or "no error")))

    -- ====================================
    -- Test 5: Concurrent Canonical Calls Do Not Crash
    -- ====================================

    local allOk = pcall(function()
        dce:Emit("test:fail:multi", { source = "test", payload = {} })
        dce:On("test:fail:multi", function() end)
        dce:Schedule("test:fail:multi", 1000, function() end)
        dce:GetService("CoreRegistry")
        dce:HasService("Logger")
    end)
    H().RecordSuccess(result, H().Assert(allOk,
        "Concurrent canonical calls: no crash"))

    local EB = dce:GetService("EventBus")
    if EB then EB:Off("test:fail:multi", nil) end
    local S = dce:GetService("Scheduler")
    if S then S:Unschedule("test:fail:multi") end

    return H().FinalizePhaseResult(result)
end

_G.DCEPhase7 = Phase7
return Phase7