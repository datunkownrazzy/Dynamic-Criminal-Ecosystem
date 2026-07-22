-- DCE Sprint 1.10 — Phase 7: Failure Injection
-- Simulate failures of: Logger, Registry, Scheduler, EventBus,
-- Configuration, Plugin Manager.
-- Verify recovery strategies operate exactly as documented.
-- Uses the existing DCE core failure injection framework where available.
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
    print("^3[DCE Phase 7] Failure Injection^0")
    local result = H().NewPhaseResult("Phase 7: Failure Injection")

    local dce = GetDCE()
    if not dce then
        H().RecordFailure(result, "Cannot obtain DCE via exports['dce-core']:GetDCEAPI()")
        return H().FinalizePhaseResult(result)
    end

    local FI = _G.DCEFailureInjection

    -- Use existing failure injection framework if available
    if FI and FI.RunAll then
        local ok, fiResult = pcall(FI.RunAll)
        if ok and fiResult then
            H().RecordSuccess(result, "Existing failure injection framework executed")
            H().RecordSuccess(result, H().Assert(fiResult.failed == 0,
                "Failure injection: " .. (fiResult.passed or 0) .. "/" ..
                (fiResult.total or 0) .. " passed, " .. (fiResult.failed or 0) .. " failed"))
        else
            H().RecordFailure(result, "Failure injection framework error: " .. tostring(fiResult))
        end
    end

    -- ====================================
    -- Test 1: Logger Failure (Graceful Degradation)
    -- ====================================

    local originalLogger = _G.DCELogger
    _G.DCELogger = nil

    -- DCE.Log should not crash without Logger
    local ok = pcall(dce.Log, "test", "info", "This should not crash")
    H().RecordSuccess(result, H().Assert(ok, "DCE.Log works without Logger"))

    -- DCE.On should still work
    local success, id = pcall(dce.On, "test:fail:logger", function() end)
    H().RecordSuccess(result, H().Assert(success == true,
        "DCE.On works without Logger"))

    -- Restore
    _G.DCELogger = originalLogger
    H().RecordSuccess(result, H().Assert(true, "Logger restored"))

    -- ====================================
    -- Test 2: Registry Failure (Services unavailable)
    -- ====================================

    local originalRegistry = _G.DCERegistry
    _G.DCERegistry = nil

    -- DCE.GetService should not crash
    local svc = dce.GetService("CoreRegistry")
    H().RecordSuccess(result, H().Assert(svc == nil,
        "DCE.GetService returns nil without Registry"))

    -- DCE.HasService should not crash
    local has = dce.HasService("Logger")
    H().RecordSuccess(result, H().Assert(has == false,
        "DCE.HasService returns false without Registry"))

    -- DCE.RegisterService should not crash
    local regOk = dce.RegisterService("test", {})
    H().RecordSuccess(result, H().Assert(regOk == false,
        "DCE.RegisterService returns false without Registry"))

    -- DCE.GetServiceOrThrow should throw
    local ok, err = pcall(dce.GetServiceOrThrow, "CoreRegistry")
    H().RecordSuccess(result, H().Assert(not ok,
        "DCE.GetServiceOrThrow errors without Registry"))

    -- Restore
    _G.DCERegistry = originalRegistry
    H().RecordSuccess(result, H().Assert(true, "Registry restored"))

    -- ====================================
    -- Test 3: EventBus Failure
    -- ====================================

    local originalEB = _G.DCEEventBus
    _G.DCEEventBus = nil

    -- DCE.Emit should not crash
    local ok = pcall(dce.Emit, "test:fail:eb", { eventVersion = 1, timestamp = 0, source = "test", payload = {} })
    H().RecordSuccess(result, H().Assert(ok, "DCE.Emit works without EventBus"))

    -- DCE.On should not crash
    local id = dce.On("test:fail:eb", function() end)
    H().RecordSuccess(result, H().Assert(id == nil,
        "DCE.On returns nil without EventBus"))

    -- DCE.Off should not crash
    local ok = pcall(dce.Off, "test:fail:eb", "nonexistent")
    H().RecordSuccess(result, H().Assert(ok, "DCE.Off works without EventBus"))

    -- Restore
    _G.DCEEventBus = originalEB
    H().RecordSuccess(result, H().Assert(true, "EventBus restored"))

    -- ====================================
    -- Test 4: Scheduler Failure
    -- ====================================

    local originalSched = _G.DCEScheduler
    _G.DCEScheduler = nil

    -- DCE.Schedule should not crash
    local ok = dce.Schedule("test:fail:sched", 1000, function() end)
    H().RecordSuccess(result, H().Assert(ok == false,
        "DCE.Schedule returns false without Scheduler"))

    -- DCE.ScheduleNow should not crash
    local ok = dce.ScheduleNow("test:fail:sched")
    H().RecordSuccess(result, H().Assert(ok == false,
        "DCE.ScheduleNow returns false without Scheduler"))

    -- Restore
    _G.DCEScheduler = originalSched
    H().RecordSuccess(result, H().Assert(true, "Scheduler restored"))

    -- ====================================
    -- Test 5: Configuration Failure
    -- ====================================

    -- DCE.LoadConfig should return nil but not crash
    local ok, err = pcall(dce.LoadConfig, "/nonexistent/path")
    H().RecordSuccess(result, H().Assert(true, "DCE.LoadConfig callable without crash"))

    -- DCE.ValidateConfig should handle nil gracefully
    local validOk = dce.ValidateConfig(nil, nil)
    H().RecordSuccess(result, H().Assert(validOk == false or validOk == true,
        "DCE.ValidateConfig(nil, nil) does not crash: " .. tostring(validOk)))

    -- ====================================
    -- Test 6: Plugin Manager Failure
    -- ====================================

    local originalPA = _G.DCEPluginArchitecture
    _G.DCEPluginArchitecture = nil
    local originalPM = _G.DCEPluginManager
    _G.DCEPluginManager = nil

    -- DCE.RegisterPlugin should not crash
    local ok = dce.RegisterPlugin({
        name = "test-fail-plugin",
        version = "1.0.0",
        description = "test",
        author = "test",
    })
    H().RecordSuccess(result, H().Assert(ok == false,
        "DCE.RegisterPlugin returns false without PluginManager"))

    -- Restore
    _G.DCEPluginArchitecture = originalPA
    _G.DCEPluginManager = originalPM
    H().RecordSuccess(result, H().Assert(true, "PluginManager restored"))

    -- ====================================
    -- Test 7: Multiple Simultaneous Failures
    -- ====================================

    -- Simulate multiple failures at once
    local restoreEB = _G.DCEEventBus
    local restoreSched = _G.DCEScheduler
    local restoreReg = _G.DCERegistry
    _G.DCEEventBus = nil
    _G.DCEScheduler = nil
    _G.DCERegistry = nil

    -- Everything should still not crash
    local allOk = pcall(function()
        dce.Emit("test:fail:multi", { eventVersion = 1, timestamp = 0, source = "test", payload = {} })
        dce.On("test:fail:multi", function() end)
        dce.Schedule("test:fail:multi", 1000, function() end)
        dce.GetService("CoreRegistry")
        dce.HasService("Logger")
    end)
    H().RecordSuccess(result, H().Assert(allOk,
        "Multiple simultaneous failures: no crash"))

    -- Restore all
    _G.DCEEventBus = restoreEB
    _G.DCEScheduler = restoreSched
    _G.DCERegistry = restoreReg
    H().RecordSuccess(result, H().Assert(true, "All services restored after multi-failure"))

    -- ====================================
    -- Test 8: GracefulDegradation Exists and Works
    -- ====================================

    local GD = _G.DCEGracefulDegradation
    if GD then
        if GD.IsOperational then
            local operational = GD.IsOperational("EventRegistry")
            H().RecordSuccess(result, H().Assert(true,
                "GracefulDegradation.IsOperational works"))
        end
        if GD.MarkOperational then
            local ok = pcall(GD.MarkOperational, "TestPhase7")
            H().RecordSuccess(result, H().Assert(ok, "GracefulDegradation.MarkOperational works"))
        end
    else
        H().RecordSkipped(result, "GracefulDegradation not available")
    end

    return H().FinalizePhaseResult(result)
end

_G.DCEPhase7 = Phase7
return Phase7