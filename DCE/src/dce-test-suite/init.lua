-- DCE Test Suite — Sprint 1.11.6 FiveM Loader Compliance
--
-- The Test Suite verifies behavior.
-- It does NOT define behavior.
-- It does NOT maintain duplicate API inventories.
-- Everything derives from the canonical SDK.
-- Uses sticky lifecycle events for guaranteed delivery.
---
---@diagnostic disable: undefined-global

-- ============================================================================
-- SDK Acquisition — Direct, single call, no polling, no retries
-- ============================================================================
local DCE = exports['dce-core']:GetDCEAPI()

if not DCE then
    error("dce-test-suite: exports['dce-core']:GetDCEAPI() returned nil. Add 'dce-core' to dependencies and ensure it starts first.")
end

local loaded = false

-- ============================================================================
-- FiveM cross-resource callable detection (Sprint 1.11.12)
-- ============================================================================
-- FiveM marshals Lua functions across the resource export boundary as callable
-- FunctionRef TABLES (not native Lua closures). type() reports "table" even
-- though the value is callable. This is the same documented FiveM semantics
-- that runtime/eventbus.lua normalizeHandler and runtime/scheduler.lua
-- normalizeCallback handle.
--
-- A value is CALLABLE (satisfying the SDK contract) if it is either:
--   * a native Lua function, or
--   * a FiveM callable FunctionRef table (table with a __call metamethod)
local function IsCallable(v)
    if type(v) == "function" then
        return true
    end
    if type(v) == "table" then
        local mt = getmetatable(v)
        if mt ~= nil and type(mt.__call) == "function" then
            return true
        end
    end
    return false
end

-- ============================================================================
-- Runtime Snapshot Verification
-- ============================================================================

local function VerifySnapshot()
    print("^4[DCE][TEST] === Runtime Snapshot Verification ===^0")

    if not DCE then
        print("^1[DCE][TEST] FATAL: No SDK available^0")
        return
    end

    local snapshot = DCE:GetSnapshot()
    if not snapshot then
        print("^1[DCE][TEST] FATAL: RuntimeSnapshot not available^0")
        return
    end

    local checks = {
        { "Boot ID present", snapshot.bootID ~= nil },
        { "Runtime phase set", snapshot.phase ~= nil },
        { "Phase timestamps recorded", snapshot.phaseTimestamps ~= nil },
        { "Services registered", snapshot.serviceCount ~= nil },
        { "Runtime created", snapshot.creationTime ~= nil },
        { "Runtime is ready", snapshot.isReady == true },
    }

    local passed = 0
    local failed = 0
    for _, check in ipairs(checks) do
        if check[2] then
            print(string.format("^2[DCE][TEST] ✓ %s^0", check[1]))
            passed = passed + 1
        else
            print(string.format("^1[DCE][TEST] ✗ %s^0", check[1]))
            failed = failed + 1
        end
    end

    -- Verify SDK API count
    -- CONTRACT (Sprint 1.11.12): methods are CALLABLE across the FiveM
    -- boundary (native function OR callable FunctionRef table). We do NOT
    -- require type() == "function", which FiveM does not preserve.
    local apiList = DCE.__sdk_api_list
    if apiList then
        local actualCount = 0
        for _, apiName in ipairs(apiList) do
            if IsCallable(DCE[apiName]) then
                actualCount = actualCount + 1
            end
        end
        local match = actualCount == #apiList
        if match then
            print(string.format("^2[DCE][TEST] ✓ SDK API count: %d/%d callable^0", actualCount, #apiList))
            passed = passed + 1
        else
            print(string.format("^1[DCE][TEST] ✗ SDK API count mismatch: %d/%d callable^0", actualCount, #apiList))
            failed = failed + 1
        end
    end

    if DCE.__sdk_id then
        print(string.format("^2[DCE][TEST] ✓ SDK identity: %s^0", DCE.__sdk_id))
        passed = passed + 1
    else
        print("^1[DCE][TEST] ✗ SDK identity missing^0")
        failed = failed + 1
    end

    print(string.format("^4[DCE][TEST] === Snapshot Verification: %d passed, %d failed ===^0", passed, failed))
end

-- ============================================================================
-- SDK Verification Tests
-- ============================================================================

local function RunSDKTests()
    print("^4[DCE][TEST] === SDK Verification Tests ===^0")

    if not DCE then return end

    -- CONTRACT TESTS (Sprint 1.11.12):
    -- Each SDK method must be CALLABLE across the FiveM boundary. FiveM
    -- marshals Lua functions as callable FunctionRef tables, so we validate
    -- callability (native function OR callable table) — NOT type() == "function".
    local testResults = {
        { "SDK.GetService is callable", IsCallable(DCE.GetService) },
        { "SDK.RegisterService is callable", IsCallable(DCE.RegisterService) },
        { "SDK.On is callable", IsCallable(DCE.On) },
        { "SDK.Emit is callable", IsCallable(DCE.Emit) },
        { "SDK.Schedule is callable", IsCallable(DCE.Schedule) },
        { "SDK.IsReady is callable", IsCallable(DCE.IsReady) },
        { "SDK.GetVersion is callable", IsCallable(DCE.GetVersion) },
        { "SDK.GetSnapshot is callable", IsCallable(DCE.GetSnapshot) },
        { "SDK.ListServices is callable", IsCallable(DCE.ListServices) },
        { "SDK.Log is callable", IsCallable(DCE.Log) },
        { "SDK.GetConfig is callable", IsCallable(DCE.GetConfig) },
        { "SDK.RegisterPlugin is callable", IsCallable(DCE.RegisterPlugin) },
    }

    local passed = 0
    local failed = 0
    for _, test in ipairs(testResults) do
        if test[2] then
            print(string.format("^2[DCE][TEST] ✓ %s^0", test[1]))
            passed = passed + 1
        else
            print(string.format("^1[DCE][TEST] ✗ %s^0", test[1]))
            failed = failed + 1
        end
    end

    print(string.format("^4[DCE][TEST] === SDK Tests: %d passed, %d failed ===^0", passed, failed))
end

-- ============================================================================
-- Lifecycle — Unconditional sticky subscription
-- ============================================================================
-- The EventBus replays sticky events to new subscribers, guaranteeing delivery
-- even if lifecycle:running was already emitted before this resource loaded.
DCE:On("lifecycle:running", function(payload)
    if not loaded then
        loaded = true
        VerifySnapshot()
        RunSDKTests()
    end
end)
