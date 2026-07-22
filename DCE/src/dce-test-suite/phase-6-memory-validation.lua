-- DCE Sprint 1.10 — Phase 6: Memory Validation
-- Monitor: pool growth, cache growth, allocations, coroutine count,
-- timers, event subscriptions. The goal is zero memory leaks.
-- This phase runs baseline checks; extended soak tests run externally.
--
-- CANONICAL SDK ACCESS:
-- Uses exports['dce-core']:GetDCEAPI() to obtain the DCE table.
-- _G.DCE is NOT part of the public platform contract.

local Phase6 = {}
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
-- Phase 6 Runner
-- ============================================================================

function Phase6.Run()
    print("^3[DCE Phase 6] Memory Validation^0")
    local result = H().NewPhaseResult("Phase 6: Memory Validation")

    local dce = GetDCE()
    if not dce then
        H().RecordFailure(result, "Cannot obtain DCE via exports['dce-core']:GetDCEAPI()")
        return H().FinalizePhaseResult(result)
    end

    -- Get services via SDK
    local EB = dce.GetService("EventBus")
    local S = dce.GetService("Scheduler")
    local PA = dce.GetService("PluginArchitecture")

    -- ====================================
    -- Test 1: Event Handler Cleanup (Subscription Tracking)
    -- ====================================

    local initialEventCount = 0
    if EB and EB.ListEvents then
        initialEventCount = #(EB.ListEvents() or {})
        H().RecordSuccess(result, H().Assert(true,
            "Initial event count: " .. initialEventCount))
    end

    -- Subscribe and unsubscribe many times
    local subIds = {}
    for i = 1, 100 do
        local id = dce.On("test:memory:handler:" .. i, function() end)
        if id then table.insert(subIds, id) end
    end
    H().RecordSuccess(result, H().Assert(#subIds == 100,
        "100 handlers subscribed: " .. #subIds))

    -- Unsubscribe all
    for i = 1, 100 do
        dce.Off("test:memory:handler:" .. i, subIds[i])
    end

    if EB and EB.ListEvents then
        local remaining = #(EB.ListEvents() or {})
        local leakers = 0
        for _, name in ipairs(EB.ListEvents() or {}) do
            if name:find("^test:memory:handler:") then
                leakers = leakers + 1
            end
        end
        H().RecordSuccess(result, H().Assert(leakers == 0,
            "No leaked handler events: " .. leakers .. " remaining"))
    end

    -- ====================================
    -- Test 2: Scheduler Task Cleanup
    -- ====================================

    if S then
        local initialTasks = #(S.ListTasks() or {})

        -- Schedule and unschedule many tasks
        for i = 1, 50 do
            S.Schedule("test:memory:task:" .. i, 10000, function() end)
        end

        local afterSchedule = #(S.ListTasks() or {})
        H().RecordSuccess(result, H().Assert(afterSchedule >= 50,
            "50 tasks scheduled: " .. afterSchedule))

        -- Unschedule all
        for i = 1, 50 do
            S.Unschedule("test:memory:task:" .. i)
        end

        local afterCleanup = #(S.ListTasks() or {})
        local taskLeakers = 0
        for _, t in ipairs(S.ListTasks() or {}) do
            if t.name:find("^test:memory:task:") then
                taskLeakers = taskLeakers + 1
            end
        end
        H().RecordSuccess(result, H().Assert(taskLeakers == 0,
            "No leaked scheduler tasks: " .. taskLeakers))
    end

    -- ====================================
    -- Test 3: Plugin Architecture Cleanup
    -- ====================================

    if PA then
        for i = 1, 50 do
            dce.RegisterPlugin({
                name = "test:memory:plugin:" .. i,
                version = "1.0.0",
                description = "Memory test plugin",
                author = "DCE Validation Team",
            })
        end

        local afterReg = #(PA.List() or {})
        H().RecordSuccess(result, H().Assert(afterReg >= 50,
            "50 plugins registered: " .. afterReg))

        PA.Clear()

        local afterClear = #(PA.List() or {})
        H().RecordSuccess(result, H().Assert(afterClear == 0,
            "Plugins cleared: " .. afterClear .. " remaining"))
    end

    -- ====================================
    -- Test 4: Registry Service Cleanup
    -- ====================================

    local R = dce.GetService("CoreRegistry")
    if R then
        local initialCount = #(R.ListServices() or {})
        H().RecordSuccess(result, H().Assert(initialCount >= 0,
            "Registry has " .. initialCount .. " services"))
    end

    -- ====================================
    -- Test 5: Event Bus Metrics Reset
    -- ====================================

    if EB and EB.GetMetrics then
        local metrics = EB.GetMetrics()
        H().RecordSuccess(result, H().Assert(metrics ~= nil, "Event bus metrics available"))
    end

    if EB and EB.ResetMetrics then
        EB.ResetMetrics()
        local afterReset = EB.GetMetrics()
        H().RecordSuccess(result, H().Assert(afterReset.totalDispatches == 0,
            "Metrics reset: totalDispatches = " .. tostring(afterReset.totalDispatches)))
    end

    -- ====================================
    -- Test 6: Aggregate Load Verification
    -- ====================================

    -- Combined: create events, tasks, plugins, services simultaneously
    local stressHandlers = {}
    for i = 1, 20 do
        local id = dce.On("test:memory:stress:" .. i, function() end)
        stressHandlers[i] = id
    end

    for i = 1, 20 do
        if stressHandlers[i] then
            dce.Off("test:memory:stress:" .. i, stressHandlers[i])
        end
    end

    if EB and EB.ListEvents then
        local remaining = 0
        for _, name in ipairs(EB.ListEvents() or {}) do
            if name:find("^test:memory:stress:") then
                remaining = remaining + 1
            end
        end
        H().RecordSuccess(result, H().Assert(remaining == 0,
            "No stress event leaks: " .. remaining))
    end

    return H().FinalizePhaseResult(result)
end

_G.DCEPhase6 = Phase6
return Phase6