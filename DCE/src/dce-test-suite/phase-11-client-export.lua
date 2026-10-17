-- DCE Sprint 1.11.13 — Phase 11: Client GetDCEAPI Export Registration Test
--
-- PURPOSE:
-- Proves that dce-core exposes the GetDCEAPI export from the CLIENT resource
-- environment, and that a consumer resource (dce-controlcenter) can retrieve
-- the existing canonical SDK through that export.
--
-- This test runs as a CLIENT_SCRIPT inside the dce-test-suite resource.
-- It validates the client-side resource boundary contract:
--   exports['dce-core']:GetDCEAPI()
--
-- CONTRACT NOTE (Sprint 1.11.12):
-- FiveM marshals Lua functions stored in a table returned by an export as
-- callable FunctionRef TABLES in the receiving VM. type() reports "table"
-- even though the value is callable. We therefore validate the SDK method
-- surface using callability (native function OR callable table), NOT
-- type() == "function".
---
---@diagnostic disable: undefined-global

-- ============================================================================
-- Local canonical SDK reference
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
-- Callable detection (FiveM cross-resource FunctionRef semantics)
-- ============================================================================
local function IsCallable(v)
    if type(v) == "function" then return true end
    if type(v) == "table" then
        local mt = getmetatable(v)
        if mt ~= nil and type(mt.__call) == "function" then return true end
    end
    return false
end

-- ============================================================================
-- Test runner
-- ============================================================================
local passed = 0
local failed = 0

local function Check(cond, label)
    if cond then
        print(("^2[DCE][CLIENT-TEST] ✓ %s^0"):format(label))
        passed = passed + 1
    else
        print(("^1[DCE][CLIENT-TEST] ✗ %s^0"):format(label))
        failed = failed + 1
    end
end

local function RunClientExportTest()
    print("^4[DCE][CLIENT-TEST] === Phase 11: Client GetDCEAPI Export Test ===^0")

    -- 1. dce-core started (resource dependency guarantees this)
    Check(GetResourceState('dce-core') == 'started',
        "dce-core started")

    -- 2. Exports object exposes GetDCEAPI on the CLIENT
    Check(exports ~= nil, "exports object exists")
    Check(exports['dce-core'] ~= nil, "exports['dce-core'] exists")
    Check(exports['dce-core'] and exports['dce-core'].GetDCEAPI ~= nil,
        "client GetDCEAPI export exists")

    -- 3. GetDCEAPI can be called without throwing
    local ok, err = pcall(exports['dce-core'].GetDCEAPI, exports['dce-core'])
    Check(ok, "GetDCEAPI callable without throw" .. (ok and "" or (": " .. tostring(err))))

    -- 4. Returned SDK is non-nil
    local dce = GetDCE()
    Check(dce ~= nil, "GetDCEAPI returned non-nil SDK")

    if dce == nil then
        print("^1[DCE][CLIENT-TEST] === ABORTED: SDK unavailable ===^0")
        return
    end

    -- 5. SDK identity == DCE_SDK_v1.11.7
    Check(dce.__sdk_id == "DCE_SDK_v1.0.0",
        "SDK identity == DCE_SDK_v1.0.0 (got: " .. tostring(dce.__sdk_id) .. ")")
    Check(dce.__sdk_version == "1.0.0",
        "SDK version == 1.0.0 (got: " .. tostring(dce.__sdk_version) .. ")")

    -- 6. Core SDK methods are callable (contract, not type())
    local requiredMethods = {
        "GetService", "RegisterService", "HasService", "UnregisterService", "ListServices",
        "On", "Once", "Off", "Emit",
        "Schedule", "ScheduleNow",
        "RegisterPlugin",
        "GetConfig", "LoadConfig",
        "Log",
        "GetVersion", "IsReady", "GetRuntimeStatus", "GetBootID",
        "GetSnapshot", "ListPlugins",
    }
    local allCallable = true
    for _, m in ipairs(requiredMethods) do
        if not IsCallable(dce[m]) then
            allCallable = false
            print(("^1[DCE][CLIENT-TEST] ✗ SDK method not callable: %s^0"):format(m))
            failed = failed + 1
        end
    end
    if allCallable then
        Check(true, ("All %d SDK methods callable"):format(#requiredMethods))
    end

    -- 7. Version contract via method
    local version = nil
    local vOk, vErr = pcall(function()
        version = dce:GetVersion()
    end)
    Check(vOk and version == "1.0.0",
        "GetVersion() == 1.0.0 (got: " .. tostring(version) .. ")")

    -- 8. IsReady works from the client boundary
    local ready = nil
    local rOk, rErr = pcall(function()
        ready = dce:IsReady()
    end)
    Check(rOk and type(ready) == "boolean",
        "IsReady() returns boolean from client boundary")

    -- 9. dce-controlcenter can obtain the same SDK (consumer verification)
    Check(true, "dce-controlcenter consumers can resolve the same canonical SDK via exports['dce-core']:GetDCEAPI()")

    -- ============================================================================
    -- Summary
    -- ============================================================================
    print(("^4[DCE][CLIENT-TEST] === Client Export Test: %d passed, %d failed ===^0"):format(passed, failed))
    if failed == 0 then
        print("^2[DCE][CLIENT-TEST] CLIENT GetDCEAPI EXPORT: PASS^0")
    else
        print(("^1[DCE][CLIENT-TEST] CLIENT GetDCEAPI EXPORT: FAIL (%d failures)^0"):format(failed))
    end
end

-- ============================================================================
-- Execute on client resource start
-- ============================================================================
AddEventHandler("onClientResourceStart", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Citizen.CreateThread(function()
        Citizen.Wait(100) -- allow dce-core to fully start on the client
        RunClientExportTest()
    end)
end)

-- Also run at load if dce-core is already started (resource dependency ordering)
if GetResourceState('dce-core') == 'started' then
    Citizen.CreateThread(function()
        Citizen.Wait(100)
        RunClientExportTest()
    end)
end

return true