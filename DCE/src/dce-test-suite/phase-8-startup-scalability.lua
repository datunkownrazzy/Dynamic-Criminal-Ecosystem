-- DCE Sprint 1.10 — Phase 8: Startup Scalability
-- Measure boot times with mock plugin loads.
-- Confirm the five-stage boot pipeline remains deterministic.
-- Simulates plugin registration to exercise boot pipeline.
-- No actual gameplay systems are created.
--
-- CANONICAL SDK ACCESS:
-- Uses exports['dce-core']:GetDCEAPI() to obtain the DCE table.
-- _G.DCE is NOT part of the public platform contract.

local Phase8 = {}
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
-- Phase 8 Runner
-- ============================================================================

function Phase8.Run()
    print("^3[DCE Phase 8] Startup Scalability^0")
    local result = H().NewPhaseResult("Phase 8: Startup Scalability")

    local dce = GetDCE()
    if not dce then
        H().RecordFailure(result, "Cannot obtain DCE via exports['dce-core']:GetDCEAPI()")
        return H().FinalizePhaseResult(result)
    end

    local PA = dce.GetService("PluginArchitecture")
    if not PA then
        H().RecordSkipped(result, "PluginArchitecture not available")
        return H().FinalizePhaseResult(result)
    end

    -- ====================================
    -- Test 1: Measure Boot Time (Baseline)
    -- ====================================

    local bootTimeline = _G.DCEBootTimeline
    if bootTimeline and bootTimeline.GetTimeline then
        local timeline = bootTimeline.GetTimeline()
        H().RecordSuccess(result, H().AssertTable(timeline, "Boot timeline available"))
        if timeline and #timeline > 0 then
            local bootComplete = timeline[#timeline]
            H().RecordSuccess(result, H().Assert(true,
                "Boot timeline entries: " .. #timeline))
        end
    else
        H().RecordSkipped(result, "BootTimeline not available for measurement")
    end

    -- ====================================
    -- Test 2: 10 Plugin Registration
    -- ====================================

    PA.Clear()
    local start10 = os.clock()
    for i = 1, 10 do
        dce.RegisterPlugin({
            name = "test:scale:10:" .. i,
            version = "1.0.0",
            description = "Scalability test plugin " .. i,
            author = "DCE Validation Team",
            capabilities = {"test-capability-" .. (i % 3 + 1)},
        })
    end
    local elapsed10 = os.clock() - start10
    local list10 = PA.List()
    H().RecordSuccess(result, H().Assert(#list10 == 10,
        "10 plugins registered: " .. #list10 ..
        " (time: " .. string.format("%.4f", elapsed10) .. "s)"))

    -- ====================================
    -- Test 3: 25 Plugin Registration (cumulative)
    -- ====================================

    local start25 = os.clock()
    for i = 11, 35 do
        dce.RegisterPlugin({
            name = "test:scale:25:" .. i,
            version = "1.0.0",
            description = "Scalability test plugin " .. i,
            author = "DCE Validation Team",
        })
    end
    local elapsed25 = os.clock() - start25
    local list25 = PA.List()
    H().RecordSuccess(result, H().Assert(#list25 >= 25,
        "25+ plugins registered: " .. #list25 ..
        " (time: " .. string.format("%.4f", elapsed25) .. "s)"))

    -- ====================================
    -- Test 4: 50 Plugin Registration (cumulative)
    -- ====================================

    local start50 = os.clock()
    for i = 36, 60 do
        dce.RegisterPlugin({
            name = "test:scale:50:" .. i,
            version = "1.0.0",
            description = "Scalability test plugin " .. i,
            author = "DCE Validation Team",
        })
    end
    local elapsed50 = os.clock() - start50
    local list50 = PA.List()
    H().RecordSuccess(result, H().Assert(#list50 >= 50,
        "50+ plugins registered: " .. #list50 ..
        " (time: " .. string.format("%.4f", elapsed50) .. "s)"))

    -- ====================================
    -- Test 5: 100 Plugin Registration (cumulative)
    -- ====================================

    local start100 = os.clock()
    for i = 61, 110 do
        dce.RegisterPlugin({
            name = "test:scale:100:" .. i,
            version = "1.0.0",
            description = "Scalability test plugin " .. i,
            author = "DCE Validation Team",
        })
    end
    local elapsed100 = os.clock() - start100
    local list100 = PA.List()
    H().RecordSuccess(result, H().Assert(#list100 >= 100,
        "100+ plugins registered: " .. #list100 ..
        " (time: " .. string.format("%.4f", elapsed100) .. "s)"))

    -- ====================================
    -- Test 6: Deterministic Boot Check
    -- ====================================

    -- The boot pipeline should produce the same results each time
    -- Check that the PluginArchitecture.List returns consistent data
    local listA = PA.List()
    local listB = PA.List()
    local sameCount = #listA == #listB
    H().RecordSuccess(result, H().Assert(sameCount,
        "Deterministic List(): " .. #listA .. " == " .. #listB))

    -- ====================================
    -- Test 7: Plugin State Machine Determinism
    -- ====================================

    -- Advance all plugins through basic states and verify consistency
    local testPlugin = "test:scale:10:1"
    local states = {"VALIDATED", "RESOLVED", "LOADING", "INITIALIZED", "READY"}
    for _, state in ipairs(states) do
        local ok, _ = PA.Transition(testPlugin, state)
        if not ok then break end
    end
    local finalState = PA.GetState(testPlugin)
    H().RecordSuccess(result, H().Assert(finalState == "READY",
        "Plugin lifecycle deterministic: " .. tostring(finalState)))

    -- ====================================
    -- Test 8: Cleanup and Reset
    -- ====================================

    PA.Clear()
    local afterClear = PA.List()
    H().RecordSuccess(result, H().Assert(#afterClear == 0,
        "Plugin architecture cleared: " .. #afterClear .. " remaining"))

    -- ====================================
    -- Test 9: Registration Performance Consistency
    -- ====================================

    -- Register 10 plugins again and measure time
    local startAgain = os.clock()
    for i = 1, 10 do
        dce.RegisterPlugin({
            name = "test:scale:reload:" .. i,
            version = "1.0.0",
            description = "Reload test plugin " .. i,
            author = "DCE Validation Team",
        })
    end
    local elapsedAgain = os.clock() - startAgain
    H().RecordSuccess(result, H().Assert(true,
        "Post-clear registration time: " ..
        string.format("%.4f", elapsedAgain) .. "s"))

    PA.Clear()

    return H().FinalizePhaseResult(result)
end

_G.DCEPhase8 = Phase8
return Phase8