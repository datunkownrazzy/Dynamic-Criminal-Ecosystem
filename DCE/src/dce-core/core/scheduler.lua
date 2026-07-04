-- DCE Scheduler
-- Named tasks with configurable intervals.
-- All simulation timing goes through this scheduler.

local Scheduler = {}
local tasks = {}         -- taskName -> task definition
local activeTimers = {}  -- taskName -> timer reference
local logger

--- Initialize the scheduler with a reference to the logger.
function Scheduler.Init(log)
    logger = log
end

--- Schedule a named task that runs on a configurable interval.
---@param taskName string Unique name for the task (e.g., "world:layer0:tick")
---@param intervalMs number Interval in milliseconds between executions
---@param callback function The function to execute
---@param options table|nil { immediate = boolean } -- start immediately if true
---@return boolean success
function Scheduler.Schedule(taskName, intervalMs, callback, options)
    if not taskName or type(taskName) ~= "string" then
        log("error", "core", "Scheduler.Schedule: taskName must be a string")
        return false
    end

    if tasks[taskName] then
        log("warn", "core", "Scheduler.Schedule: task '%s' is already registered. Use Scheduler.Reschedule to change.", taskName)
        return false
    end

    if type(intervalMs) ~= "number" or intervalMs < 50 then
        log("warn", "core", "Scheduler.Schedule: interval %s for '%s' is too fast, clamping to 50ms", tostring(intervalMs), taskName)
        intervalMs = 50
    end

    if not callback or type(callback) ~= "function" then
        log("error", "core", "Scheduler.Schedule: callback must be a function for task '%s'", taskName)
        return false
    end

    options = options or {}

    tasks[taskName] = {
        name = taskName,
        interval = intervalMs,
        callback = callback,
        running = false,
        errorCount = 0,
        lastRunAt = 0,
        runCount = 0,
    }

    if options.immediate then
        Scheduler.ExecuteNow(taskName)
    end

    -- Create the repeating timer
    local timerId = SetInterval(function()
        Scheduler.ExecuteNow(taskName)
    end, intervalMs)

    activeTimers[taskName] = timerId

    log("info", "core", "Scheduler: task '%s' scheduled every %dms", taskName, intervalMs)
    return true
end

--- Execute a named task immediately, regardless of its interval.
---@param taskName string
---@return boolean success
function Scheduler.ExecuteNow(taskName)
    local task = tasks[taskName]
    if not task then
        log("warn", "core", "Scheduler.ExecuteNow: unknown task '%s'", taskName)
        return false
    end

    if task.running then
        log("warn", "core", "Scheduler.ExecuteNow: task '%s' is already running, skipping", taskName)
        return false
    end

    task.running = true
    task.lastRunAt = os.time()

    local success, err = pcall(task.callback)
    if not success then
        task.errorCount = task.errorCount + 1
        log("error", "core", "Scheduler: task '%s' errored (count: %s): %s", taskName, tostring(task.errorCount), tostring(err))

        -- Apply error cooldown: if task errors repeatedly, give it a break
        if task.errorCount >= 3 then
            local cooldown = Config.Scheduler.ErrorCooldown
            log("warn", "core", "Scheduler: task '%s' has %d errors, applying %dms cooldown", taskName, task.errorCount, cooldown)
            Scheduler.Pause(taskName)
            SetTimeout(cooldown, function()
                Scheduler.Resume(taskName)
            end)
        end
    else
        task.errorCount = 0
    end

    task.running = false
    task.runCount = task.runCount + 1

    return success
end

--- Get information about a scheduled task.
---@param taskName string
---@return table|nil Task info or nil if not found
function Scheduler.GetTask(taskName)
    return tasks[taskName]
end

--- List all registered tasks.
---@return table Array of task info tables
function Scheduler.ListTasks()
    local result = {}
    for name, task in pairs(tasks) do
        table.insert(result, {
            name = name,
            interval = task.interval,
            running = task.running,
            errorCount = task.errorCount,
            runCount = task.runCount,
            lastRunAt = task.lastRunAt,
        })
    end
    return result
end

--- Change the interval of a running task.
---@param taskName string
---@param newIntervalMs number New interval in milliseconds
---@return boolean success
function Scheduler.Reschedule(taskName, newIntervalMs)
    local task = tasks[taskName]
    if not task then
        log("warn", "core", "Scheduler.Reschedule: unknown task '%s'", taskName)
        return false
    end

    -- Clear the old timer
    local oldTimer = activeTimers[taskName]
    if oldTimer then
        ClearInterval(oldTimer)
    end

    task.interval = newIntervalMs

    -- Create a new timer with the updated interval
    local timerId = SetInterval(function()
        Scheduler.ExecuteNow(taskName)
    end, newIntervalMs)

    activeTimers[taskName] = timerId

    log("info", "core", "Scheduler: task '%s' rescheduled to %dms", taskName, newIntervalMs)
    return true
end

--- Pause a scheduled task. It will stop firing until resumed.
---@param taskName string
function Scheduler.Pause(taskName)
    local timer = activeTimers[taskName]
    if timer then
        ClearInterval(timer)
        activeTimers[taskName] = nil
        log("info", "core", "Scheduler: task '%s' paused", taskName)
    end
end

--- Resume a paused task.
---@param taskName string
function Scheduler.Resume(taskName)
    local task = tasks[taskName]
    if not task then
        log("warn", "core", "Scheduler.Resume: unknown task '%s'", taskName)
        return
    end

    if activeTimers[taskName] then
        log("warn", "core", "Scheduler.Resume: task '%s' is already running", taskName)
        return
    end

    local timerId = SetInterval(function()
        Scheduler.ExecuteNow(taskName)
    end, task.interval)

    activeTimers[taskName] = timerId
    log("info", "core", "Scheduler: task '%s' resumed", taskName)
end

--- Unschedule a task completely. Removes it from the scheduler.
---@param taskName string
function Scheduler.Unschedule(taskName)
    local timer = activeTimers[taskName]
    if timer then
        ClearInterval(timer)
        activeTimers[taskName] = nil
    end

    tasks[taskName] = nil
    log("info", "core", "Scheduler: task '%s' unscheduled", taskName)
end

--- Unschedule all tasks. Called during shutdown.
function Scheduler.ClearAll()
    for taskName, _ in pairs(activeTimers) do
        local timer = activeTimers[taskName]
        if timer then
            ClearInterval(timer)
        end
    end

    for taskName, _ in pairs(tasks) do
        tasks[taskName] = nil
    end

    for taskName, _ in pairs(activeTimers) do
        activeTimers[taskName] = nil
    end

    log("info", "core", "Scheduler: all tasks cleared")
end

local function log(level, module, message, ...)
    if logger then
        logger.Log(module, level, message, ...)
    end
end

return Scheduler