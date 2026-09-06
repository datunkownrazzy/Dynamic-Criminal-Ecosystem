-- DCE Scheduler — Sprint 1.11.3
--
-- Single canonical scheduler.
-- No duplicate implementations.
-- All tasks managed through the canonical runtime state.
---@diagnostic disable: undefined-global

local Scheduler = {}

-- ============================================================================
-- FiveM cross-resource callback normalization (Sprint 1.11.11 contract repair)
-- ============================================================================
-- FiveM marshals Lua functions passed across the export boundary (e.g. a
-- consumer calling DCE:Schedule(...) with a callback) as a callable FunctionRef
-- TABLE in the receiving VM. type() then reports "table" even though the value
-- is callable. This mirrors the EventBus normalizeHandler contract:
--   tasks[taskName].callback = <function>
-- A callable table is wrapped in a real in-VM closure so the Scheduler stores
-- exactly one canonical representation. Genuine Lua functions pass through.
local function normalizeCallback(fn)
    if type(fn) == "function" then
        return fn
    end
    if type(fn) == "table" then
        local mt = getmetatable(fn)
        if mt ~= nil and type(mt.__call) == "function" then
            return function()
                return fn()
            end
        end
    end
    return nil
end

function Scheduler:New(runtimeState, logger)
    local sched = {}
    local tasks = {}
    local taskCounter = 0

    -- ============================================================================
    -- Schedule — Register a recurring task
    -- ============================================================================

    function sched:Schedule(taskName, intervalMs, callback, options)
        if type(taskName) ~= "string" then
            if logger then logger:LogError("scheduler", "Schedule: taskName must be a string") end
            return false
        end

        -- Normalize FiveM cross-resource FunctionRef tables to real closures.
        -- Rejects non-function, non-callable values loudly (never suppresses).
        local normalized = normalizeCallback(callback)
        if normalized == nil then
            if logger then logger:LogError("scheduler", "Schedule: callback must be a function for '%s', got %s",
                tostring(taskName), type(callback)) end
            return false
        end
        callback = normalized

        if tasks[taskName] then
            if logger then logger:LogWarn("scheduler", "Task '%s' already scheduled — unscheduling first", taskName) end
            tasks[taskName].active = false
            tasks[taskName] = nil
        end

        taskCounter = taskCounter + 1
        local taskId = taskCounter
        local immediate = options and options.immediate or false

        local task = {
            id = taskId,
            name = taskName,
            interval = intervalMs or 5000,
            callback = callback,
            immediate = immediate,
            active = true,
            created = os.time(),
        }

        tasks[taskName] = task

        -- Update canonical runtime state
        if runtimeState then
            runtimeState.scheduledTasks[taskName] = task
        end

        if logger then logger:LogInfo("scheduler", "Task scheduled: %s (every %dms)", taskName, intervalMs or 5000) end

        -- Register FiveM timer
        Citizen.CreateThread(function()
            if immediate then
                Citizen.Wait(0)
                local ok, err = pcall(callback)
                if not ok and logger then
                    logger:LogError("scheduler", "Task '%s' immediate execution failed: %s", taskName, tostring(err))
                end
            end

            while tasks[taskName] and tasks[taskName].active do
                Citizen.Wait(intervalMs or 5000)
                if tasks[taskName] and tasks[taskName].active then
                    local ok, err = pcall(callback)
                    if not ok and logger then
                        logger:LogError("scheduler", "Task '%s' execution failed: %s", taskName, tostring(err))
                    end
                end
            end
        end)

        return true
    end

    -- ============================================================================
    -- Unschedule — Remove a task
    -- ============================================================================

    function sched:Unschedule(taskName)
        if tasks[taskName] then
            tasks[taskName].active = false
            tasks[taskName] = nil
            if runtimeState then
                runtimeState.scheduledTasks[taskName] = nil
            end
            if logger then logger:LogInfo("scheduler", "Task unscheduled: %s", taskName) end
            return true
        end
        return false
    end

    -- ============================================================================
    -- ExecuteNow — Run a task immediately
    -- ============================================================================

    function sched:ExecuteNow(taskName)
        local task = tasks[taskName]
        if task and task.callback then
            local ok, err = pcall(task.callback)
            if not ok then
                if logger then logger:LogError("scheduler", "Task '%s' executeNow failed: %s", taskName, tostring(err)) end
                return false
            end
            return true
        end
        if logger then logger:LogWarn("scheduler", "ExecuteNow: task '%s' not found", taskName) end
        return false
    end

    -- ============================================================================
    -- Query
    -- ============================================================================

    function sched:ListTasks()
        local names = {}
        for k, v in pairs(tasks) do
            if v.active then
                table.insert(names, k)
            end
        end
        table.sort(names)
        return names
    end

    function sched:HasTask(taskName)
        return tasks[taskName] ~= nil and tasks[taskName].active
    end

    function sched:GetTask(taskName)
        return tasks[taskName]
    end

    -- ============================================================================
    -- Clear
    -- ============================================================================

    function sched:Clear()
        for name in pairs(tasks) do
            tasks[name].active = false
            tasks[name] = nil
            if runtimeState then
                runtimeState.scheduledTasks[name] = nil
            end
        end
        if logger then logger:LogInfo("scheduler", "All tasks cleared") end
    end

    return sched
end

-- Registered on the server-only DCE_INTERNAL namespace.
DCE_INTERNAL = DCE_INTERNAL or {}
DCE_INTERNAL.Scheduler = Scheduler
