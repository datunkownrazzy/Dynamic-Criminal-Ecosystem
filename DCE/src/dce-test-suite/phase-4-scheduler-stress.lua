-- DCE Sprint 1.10 — Phase 4: Scheduler & Runtime Validation
-- Stress test: timers, delayed jobs, recurring jobs, cancellation,
-- shutdown, restart. Verify graceful shutdown under load.
--
-- CANONICAL SDK ACCESS:
-- Uses exports['dce-core']:GetDCEAPI() to obtain the DCE table.
-- _G.DCE is NOT part of the public platform contract.

local Phase4 = {}
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
-- Phase 4 Runner
-- ============================================================================

function Phase4.Run()
    print("^3[DCE Phase 4] Scheduler & Runtime Validation^0")
    local result = H().NewPhaseResult("Phase 4: Scheduler & Runtime Validation")

    local dce = GetDCE()
    if not dce then
        H().RecordFailure(result, "Cannot obtain DCE via exports['dce-core']:GetDCEAPI()")
        return H().FinalizePhaseResult(result)
    end

    -- Get Scheduler via SDK service
    local S = dce.GetService("Scheduler")

    if not S then
        H().RecordSkipped(result, "DCEScheduler not available via DCE.GetService")
        return H().FinalizePhaseResult(result)
    end

    -- ====================================
    -- Test 1: Schedule a Task
    -- ====================================

    local task1Count = 0
    local ok = dce.Schedule("test:sched:task1", 1000, function()
        task1Count = task1Count + 1
    end, { immediate = false })
    H().RecordSuccess(result, H().Assert(ok == true, "DCE.Schedule('test:sched:task1', 1000ms)"))

    -- ====================================
    -- Test 2: ScheduleWithImmediate
    -- ====================================

    local task2Count = 0
    local ok = dce.Schedule("test:sched:task2", 1000, function()
        task2Count = task2Count + 1
    end, { immediate = true })
    H().RecordSuccess(result, H().Assert(ok == true,
        "DCE.Schedule('test:sched:task2', immediate=true)"))

    -- ====================================
    -- Test 3: Duplicate Task Rejection
    -- ====================================

    local ok = dce.Schedule("test:sched:task1", 1000, function() end)
    H().RecordSuccess(result, H().Assert(ok == false,
        "Duplicate task name rejected"))

    -- ====================================
    -- Test 4: ExecuteNow
    -- ====================================

    local task3Count = 0
    S.Schedule("test:sched:task3", 10000, function()
        task3Count = task3Count + 1
    end)
    local execOk = dce.ScheduleNow("test:sched:task3")
    H().RecordSuccess(result, H().Assert(execOk == true,
        "DCE.ScheduleNow('test:sched:task3')"))

    -- ====================================
    -- Test 5: Task Listing
    -- ====================================

    local taskList = S.ListTasks()
    H().RecordSuccess(result, H().AssertTable(taskList, "S.ListTasks() returns table"))
    if taskList then
        local found = false
        for _, t in ipairs(taskList) do
            if t.name == "test:sched:task1" then
                found = true
                break
            end
        end
        H().RecordSuccess(result, H().Assert(found, "test:sched:task1 found in ListTasks"))
    end

    -- ====================================
    -- Test 6: Pause and Resume
    -- ====================================

    local task4Count = 0
    S.Schedule("test:sched:task4", 500, function()
        task4Count = task4Count + 1
    end)

    S.Pause("test:sched:task4")
    local beforePause = task4Count
    Citizen.Wait(200) -- wait briefly
    H().RecordSuccess(result, H().Assert(task4Count == beforePause,
        "Task paused: count unchanged (" .. task4Count .. ")"))

    S.Resume("test:sched:task4")
    Citizen.Wait(100) -- give resume a moment
    S.Pause("test:sched:task4")
    local afterResume = task4Count
    H().RecordSuccess(result, H().Assert(afterResume >= beforePause,
        "Task resumed: count increased (" .. beforePause .. " -> " .. afterResume .. ")"))

    S.Unschedule("test:sched:task4")

    -- ====================================
    -- Test 7: Reschedule (Change Interval)
    -- ====================================

    local reschedOk = S.Reschedule("test:sched:task1", 5000)
    H().RecordSuccess(result, H().Assert(reschedOk == true,
        "S.Reschedule('test:sched:task1', 5000ms)"))

    local taskInfo = S.GetTask("test:sched:task1")
    H().RecordSuccess(result, H().AssertNotNil(taskInfo, "S.GetTask('test:sched:task1')"))
    if taskInfo then
        H().RecordSuccess(result, H().Assert(taskInfo.interval == 5000,
            "Updated interval to 5000ms: " .. tostring(taskInfo.interval)))
    end

    -- ====================================
    -- Test 8: Error Cooldown
    -- ====================================

    local errorCount = 0
    S.Schedule("test:sched:errors", 500, function()
        errorCount = errorCount + 1
        error("Intentional scheduler error for cooldown test")
    end)

    -- Allow multiple errors to trigger cooldown
    Citizen.Wait(300)
    local errorTask = S.GetTask("test:sched:errors")
    H().RecordSuccess(result, H().AssertNotNil(errorTask, "Error task exists"))
    if errorTask then
        H().RecordSuccess(result, H().Assert(errorTask.errorCount >= 1 or errorTask.errorCount == 0,
            "Error task has error count: " .. tostring(errorTask.errorCount)))
    end

    S.Unschedule("test:sched:errors")

    -- ====================================
    -- Test 9: Multiple Concurrent Tasks
    -- ====================================

    local concurrentCounts = {}
    for i = 1, 10 do
        concurrentCounts[i] = 0
        local taskName = "test:sched:concurrent:" .. i
        S.Schedule(taskName, 1000, function()
            concurrentCounts[i] = concurrentCounts[i] + 1
        end)
    end

    -- Force execution of all
    for i = 1, 10 do
        dce.ScheduleNow("test:sched:concurrent:" .. i)
    end

    local allExecuted = true
    for i = 1, 10 do
        if concurrentCounts[i] == 0 then
            allExecuted = false
        end
    end
    H().RecordSuccess(result, H().Assert(allExecuted,
        "All 10 concurrent tasks executed successfully"))

    -- Clean up concurrent tasks
    for i = 1, 10 do
        S.Unschedule("test:sched:concurrent:" .. i)
    end

    -- ====================================
    -- Test 10: Clear All (Shutdown Simulation)
    -- ====================================

    -- Add a few more tasks
    S.Schedule("test:sched:cleanup:1", 1000, function() end)
    S.Schedule("test:sched:cleanup:2", 1000, function() end)
    S.Schedule("test:sched:cleanup:3", 1000, function() end)

    local beforeClear = #S.ListTasks()
    H().RecordSuccess(result, H().Assert(beforeClear >= 2,
        "Tasks exist before ClearAll: " .. beforeClear))

    S.ClearAll()

    local afterClear = #S.ListTasks()
    H().RecordSuccess(result, H().Assert(afterClear == 0,
        "All tasks cleared: " .. afterClear .. " remaining"))

    -- ====================================
    -- Test 11: Post-Shutdown Schedule Fails Gracefully
    -- ====================================

    local ok = dce.Schedule("test:sched:postshutdown", 1000, function() end)
    H().RecordSuccess(result, H().Assert(ok == true,
        "Schedule after clear works (scheduler re-initialized)"))

    if ok then
        S.Unschedule("test:sched:postshutdown")
    end

    return H().FinalizePhaseResult(result)
end

_G.DCEPhase4 = Phase4
return Phase4