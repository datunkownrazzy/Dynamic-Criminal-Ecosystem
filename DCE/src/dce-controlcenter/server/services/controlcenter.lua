-- DCE Control Center v2 - ControlCenter Service (Authoritative)
-- SOLE OWNER: Orchestration, permission validation, session coordination
-- Self-registers with DCE Core via Registry (never globals)
-- Per ADR-0026: True Lazy Initialization
--
-- Sprint 1.11.6 FiveM Loader Compliance:
--   fxmanifest.lua declares dependencies { 'dce-core' }, which per the FiveM
--   resource manifest reference REQUIRES dce-core to load and fully start
--   BEFORE this resource executes any script. Therefore exports['dce-core']
--   is guaranteed to exist here. No polling, no Wait(), no retries.

local ControlCenterService = {}
local dceCoreReady = false
local Logger = nil
local EventBus = nil
local DCE = nil
local configurationListenerId = nil

local function ConnectToCore()
    if dceCoreReady then return true end

    -- Deterministic: dce-core is guaranteed started by the dependency directive.
    DCE = exports['dce-core']:GetDCEAPI()
    if not DCE then return false end

    EventBus = DCE.GetService and DCE:GetService("EventBus")
    Logger = DCE.GetService and DCE:GetService("Logger")
    dceCoreReady = true
    return true
end

local function log(level, message, ...)
    if Logger and Logger.Log then
        Logger:Log("controlcenter", level, message, ...)
    else
        print(("[DCE CC] %s: %s"):format(level, message:format(...)))
    end
end

local function GetService(serviceName)
    if not DCE then return nil end
    return DCE.GetService and DCE:GetService(serviceName)
end

-- ============================================================================
-- Permission Validation
-- ============================================================================

function ControlCenterService.HasPermission(source)
    if not source then return false end
    if IsPlayerAceAllowed then
            local configuredRoles = Config and Config.CC and Config.CC.Permissions and Config.CC.Permissions.Roles
            local adminPermissions = configuredRoles and configuredRoles.admin or {
                "command.dce",
                "group.admin",
                "group.superadmin",
            }
            for _, permission in ipairs(adminPermissions) do
                if IsPlayerAceAllowed(source, permission) then
                    return true
                end
            end
    end
    return false
end

local function GetPermissionTrace(source)
    local permissions = (Config and Config.CC and Config.CC.Permissions and Config.CC.Permissions.Roles and Config.CC.Permissions.Roles.admin) or {
        "command.dce",
        "group.admin",
        "group.superadmin",
    }
    local results = {}
    for _, permission in ipairs(permissions) do
        results[permission] = IsPlayerAceAllowed and IsPlayerAceAllowed(source, permission) or false
    end
    return results
end

-- ============================================================================
-- Session Integration
-- ============================================================================

function ControlCenterService.RequestOpen(source)
    ConnectToCore()
    if not source or source == 0 then return false end
    log("info", "Authorization trace source=%s permissions=%s", tostring(source), json.encode(GetPermissionTrace(source)))
    if not ControlCenterService.HasPermission(source) then
        log("warn", "Player %d denied access", source)
        return false
    end
    
    local SM = GetService("SessionManager")
    if not SM then
        log("error", "SessionManager not available")
        return false
    end
    
    local existing = SM.GetSessionByPlayer(source)
    if existing then
        SM.ReuseSession(source)
        return true
    end
    
    local sessionId = SM.CreateSession(source)
    if not sessionId then
        log("error", "Failed to create session for player %d", source)
        return false
    end
    
    SM.StartSession(sessionId)
    return true
end

function ControlCenterService.RequestClose(source)
    local SM = GetService("SessionManager")
    if not SM then return false end
    
    local session = SM.GetSessionByPlayer(source)
    if not session then return true end
    
    SM.CloseSession(session.sessionId)
    SM.EndSession(session.sessionId)
    return true
end

-- ============================================================================
-- Administrative Read Contract
-- ============================================================================

local function withRevision(records, locationManager)
    local response = {}
    for _, record in ipairs(records or {}) do
        local copy = {}
        for key, value in pairs(record) do
            copy[key] = value
        end
        copy.revision = locationManager.GetLocationRevision(record.id)
        table.insert(response, copy)
    end
    return response
end

function ControlCenterService.RequestData(source, requestId, dataType)
    if not source or not requestId or not dataType then return false end
    log("info", "Data request source=%s type=%s permission=%s", tostring(source), tostring(dataType), tostring(ControlCenterService.HasPermission(source)))
    if not ControlCenterService.HasPermission(source) then
        TriggerClientEvent('dce-cc:client:data-response', source, {
            requestId = requestId,
            status = "error",
            message = "Permission denied"
        })
        return false
    end

    local response = {
        requestId = requestId,
        status = "unavailable",
        message = "This Control Center data source is not available in V1."
    }

    local locationManager = GetService("LocationManager")
    if dataType == "world-locations" and locationManager and locationManager.GetAllLocations then
        response.status = "ok"
        response.locations = locationManager.GetAllLocations() or {}
        if locationManager.GetLocationRevision then
            response.locations = withRevision(response.locations, locationManager)
        end
        response.message = nil
    elseif dataType == "world-territories" and locationManager and locationManager.GetAllTerritories then
        response.status = "ok"
        response.territories = locationManager.GetAllTerritories() or {}
        if locationManager.GetLocationRevision then
            response.territories = withRevision(response.territories, locationManager)
        end
        response.message = nil
    elseif dataType == "organizations" then
        response.message = "Organization administration is not backed by an available V1 adapter."
    elseif dataType == "configuration" then
        local configurationService = GetService("ConfigurationService")
        if configurationService and configurationService.ListTargets then
            response.status = "ok"
            response.targets = configurationService:ListTargets()
            log("info", "Capability response source=%s targets=%s", tostring(source), json.encode(response.targets))
            response.message = nil
        else
            response.message = "Runtime configuration editing has no V1 server contract yet."
        end
    end

    TriggerClientEvent('dce-cc:client:data-response', source, response)
    return response.status == "ok"
end

function ControlCenterService.RequestConfigurationChange(source, requestId, request)
    if not source or not requestId then return false end

    local response
    -- Evaluate once: reusing this result for Apply's authorize callback avoids a second
    -- ACE re-check disagreeing with the permission already logged/gated above.
    local authorized = ControlCenterService.HasPermission(source)
    log("info", "Configuration request source=%s target=%s operation=%s permission=%s", tostring(source), tostring(request and request.target), tostring(request and request.operation), tostring(authorized))
    if not authorized then
        response = {
            code = "PERMISSION_DENIED",
                message = request and request.target == "world.location"
                    and "You do not have permission to modify world locations."
                    or "You do not have permission to modify this configuration.",
                target = request and request.target or nil,
            runtimeApplied = false,
            persisted = false,
            restartRequired = false,
        }
    else
        local configurationService = GetService("ConfigurationService")
        if not configurationService or not configurationService.Apply then
            response = {
                code = "UNAVAILABLE",
                message = "Hot configuration is not available in V1.",
                runtimeApplied = false,
                persisted = false,
                restartRequired = false,
            }
        else
            log("info", "[CC-TRACE] APPLY_CALL source=%s target=%s operation=%s authorized=%s",
                tostring(source), tostring(request and request.target),
                tostring(request and request.operation), tostring(authorized))
            local ok, result = pcall(function()
                return configurationService:Apply(source, request, function()
                    return authorized
                end)
            end)
            log("info", "[CC-TRACE] APPLY_OK=%s", tostring(ok))
            if ok then
                log("info", "[CC-TRACE] APPLY_RESULT code=%s message=%s targetId=%s runtimeApplied=%s persisted=%s",
                    tostring(result and result.code), tostring(result and result.message),
                    tostring(result and result.targetId), tostring(result and result.runtimeApplied),
                    tostring(result and result.persisted))
            else
                log("error", "[CC-TRACE] APPLY_ERROR %s", tostring(result))
            end
            response = ok and result or {
                code = "RUNTIME_APPLY_ERROR",
                message = "The configuration operation could not be applied.",
                runtimeApplied = false,
                persisted = false,
                restartRequired = false,
            }
        end
    end

    response = response or { code = "RUNTIME_APPLY_ERROR", message = "No result returned" }
        if response.code == "PERMISSION_DENIED" and request and request.target == "world.location" then
            response.message = "You do not have permission to modify world locations."
        end
    response.requestId = requestId
    log("info", "[CC-TRACE] RESPONSE source=%s requestId=%s code=%s message=%s",
        tostring(source), tostring(requestId), tostring(response.code), tostring(response.message))
    TriggerClientEvent('dce-cc:client:data-response', source, response)
    return response.code == "SUCCESS"
end

-- ============================================================================
-- Init & Shutdown
-- ============================================================================

function ControlCenterService.Init()
    ConnectToCore()
    if not dceCoreReady then
        log("error", "Cannot init - dce-core not ready")
        return false
    end
    
    if DCE and DCE.RegisterService then
        DCE:RegisterService("ControlCenter", ControlCenterService)
        log("info", "Registered with DCE Core")
    end

    if EventBus and EventBus.On and not configurationListenerId then
        configurationListenerId = EventBus:On("configuration:changed", function(change)
            local sessionManager = GetService("SessionManager")
            if not sessionManager or not sessionManager.ListSessions then return end
            for _, session in ipairs(sessionManager.ListSessions()) do
                if ControlCenterService.HasPermission(session.playerSource) then
                    TriggerClientEvent('dce-cc:client:configuration-changed', session.playerSource, change)
                end
            end
        end)
    end
    
    log("info", "Control Center Service ready")
    return true
end

function ControlCenterService.Shutdown()
    if EventBus and EventBus.Off and configurationListenerId then
        EventBus:Off("configuration:changed", configurationListenerId)
        configurationListenerId = nil
    end
    local SM = GetService("SessionManager")
    if SM then
        for _, session in pairs(SM.ListSessions()) do
            SM.CloseSession(session.sessionId)
            SM.EndSession(session.sessionId)
        end
    end
    log("info", "Control Center Service shut down")
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

RegisterNetEvent('dce-cc:server:open')
AddEventHandler('dce-cc:server:open', function()
    local src = source
    if src then ControlCenterService.RequestOpen(src) end
end)

RegisterNetEvent('dce-cc:server:close')
AddEventHandler('dce-cc:server:close', function()
    local src = source
    if src then ControlCenterService.RequestClose(src) end
end)

RegisterNetEvent('dce-cc:server:data-request')
AddEventHandler('dce-cc:server:data-request', function(data)
    local src = source
    ControlCenterService.RequestData(src, data and data.requestId, data and data.dataType)
end)

RegisterNetEvent('dce-cc:server:configuration-request')
AddEventHandler('dce-cc:server:configuration-request', function(data)
    local src = source
    ControlCenterService.RequestConfigurationChange(src, data and data.requestId, data and data.request)
end)

RegisterNetEvent('dce-cc:server:eventbus:subscribe')
AddEventHandler('dce-cc:server:eventbus:subscribe', function(data)
    local src = source
    ConnectToCore()
    if EventBus and EventBus.On and data and data.eventName then
        EventBus:On(data.eventName, function(payload)
            TriggerClientEvent('dce-cc:client:eventbus', src, {
                eventName = data.eventName,
                payload = payload
            })
        end)
    end
end)

-- ============================================================================
-- Resource Lifecycle
-- ============================================================================

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    -- Deterministic single-pass init. No polling, no Wait(), no retries.
    -- dce-core is guaranteed started (dependency directive), so ConnectToCore
    -- succeeds on the first call.
    ConnectToCore()
    ControlCenterService.Init()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    ControlCenterService.Shutdown()
end)

-- ============================================================================
-- Administrative Contract
-- ============================================================================

ControlCenterService._startUptime = os.time()
function ControlCenterService.GetStatus()
    return { state = "running", uptime = os.time() - ControlCenterService._startUptime }
end
function ControlCenterService.GetHealth()
    return { healthy = true, errorCount = 0 }
end
function ControlCenterService.GetMetrics()
    local SM = GetService("SessionManager")
    return { activeSessions = SM and #SM.ListSessions() or 0 }
end
function ControlCenterService.GetCapabilities()
    return { admin = true, readOnly = false, actions = { "open", "close", "status" } }
end

return ControlCenterService