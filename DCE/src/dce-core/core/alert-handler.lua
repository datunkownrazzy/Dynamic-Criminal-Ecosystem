-- DCE Performance Alert Handler
-- Automatic alerts when performance budgets are exceeded.
-- Spec: ADR-0015

local AlertHandler = {}
local alerts = {}
local logger
local cachedConfig = {}

--- Initialize the alert handler
function AlertHandler.Init(log)
    logger = log
    cachedConfig = _G.Config or {}
end

--- Log a message
local function log(level, module, message, ...)
    if logger then
        logger.Log(module, level, message, ...)
    end
end

--- Handle budget exceeded event
---@param payload table { serviceId, actualMs, budgetMs }
function AlertHandler.HandleBudgetExceeded(payload)
    if not payload or not payload.serviceId then return end

    local alert = {
        type = "budget_exceeded",
        serviceId = payload.serviceId,
        actualMs = payload.actualMs,
        budgetMs = payload.budgetMs,
        timestamp = os.time(),
        recommendation = AlertHandler.GetRecommendation(payload.serviceId, payload.actualMs, payload.budgetMs),
    }

    table.insert(alerts, alert)
    log("warn", "core", "[PERFORMANCE ALERT] Service '%s' exceeded budget: %.2fms > %.2fms. %s",
        payload.serviceId, payload.actualMs, payload.budgetMs, alert.recommendation)

    -- Emit alert event for UI
    if DCE and DCE.Emit then
        DCE.Emit("admin:performance:alert", {
            eventName = "admin:performance:alert",
            eventVersion = 1,
            timestamp = os.time(),
            source = "dce-core-alerts",
            payload = alert,
        })
    end
end

--- Get optimization recommendation
---@param serviceId string
---@param actualMs number
---@param budgetMs number
---@return string
function AlertHandler.GetRecommendation(serviceId, actualMs, budgetMs)
    local ratio = actualMs / budgetMs

    if ratio > 3 then
        return "CRITICAL: Consider disabling this service or reducing its workload dramatically."
    elseif ratio > 2 then
        return "HIGH: Review task intervals and consider deferring non-critical work."
    elseif ratio > 1.5 then
        return "MEDIUM: Consider time-slicing or increasing interval for this service."
    else
        return "LOW: Monitor closely, may need optimization soon."
    end
end

--- Get recent alerts
---@param limit number|nil
---@return table
function AlertHandler.GetRecentAlerts(limit)
    limit = limit or 50
    local result = {}

    for i = math.max(1, #alerts - limit + 1), #alerts do
        result[#result + 1] = alerts[i]
    end

    return result
end

--- Clear alerts
function AlertHandler.ClearAlerts()
    alerts = {}
end

--- Shutdown
function AlertHandler.Shutdown()
    alerts = {}
    log("info", "core", "Alert handler shutdown")
end

--- Setup event handler for performance alerts
function AlertHandler.Setup()
    if DCE and DCE.On then
        DCE.On("performance:budget:exceeded", function(payload)
            AlertHandler.HandleBudgetExceeded(payload)
        end)
    end
end

_G.DCEAlertHandler = AlertHandler
