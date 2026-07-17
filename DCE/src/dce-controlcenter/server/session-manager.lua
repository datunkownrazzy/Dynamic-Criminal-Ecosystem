-- DCE Control Center v2 - Session Manager Server (Authoritative)
-- SOLE OWNER of session lifecycle on the server side.
-- Per ADR-0026: Sessions are created/destroyed only here.
-- Registers with DCE Core via DCE:RegisterService() - never globals.

local SessionManagerServer = {}
local dceCoreReady = false
local EventBus = nil
local Logger = nil
local DCE = nil
local sessionIdCounter = 0

local SESSION_STATES = { CREATED = "created", ACTIVE = "active", CLOSED = "closed" }
local sessions = {}

local function ConnectToCore()
    if dceCoreReady then return true end
    if GetResourceState('dce-core') ~= 'started' then return false end
    DCE = exports['dce-core']:GetDCEAPI()
    if not DCE then return false end
    EventBus = DCE.GetService and DCE.GetService("EventBus")
    Logger = DCE.GetService and DCE.GetService("Logger")
    dceCoreReady = true
    return true
end

local function log(level, message, ...)
    if Logger and Logger.Log then
        Logger.Log("session-server", level, message, ...)
    else
        print(("[DCE Session] %s: %s"):format(level, message:format(...)))
    end
end

local function GenerateSessionId()
    sessionIdCounter = sessionIdCounter + 1
    return ("dce-session-%d-%d"):format(os.time(), sessionIdCounter)
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Create a new session for a player.
function SessionManagerServer.CreateSession(playerSource)
    ConnectToCore()
    if not playerSource or playerSource <= 0 then return nil end
    
    for _, s in pairs(sessions) do
        if s.playerSource == playerSource and s.state == SESSION_STATES.ACTIVE then
            log("debug", "Player %d has active session, reusing", playerSource)
            return s.sessionId
        end
    end
    
    local sessionId = GenerateSessionId()
    sessions[sessionId] = {
        sessionId = sessionId,
        playerSource = playerSource,
        state = SESSION_STATES.CREATED,
        createdAt = os.time(),
        lastActivity = os.time()
    }
    
    log("info", "Session created: %s for player %d", sessionId, playerSource)
    
    if EventBus then
        EventBus.Emit("session:created", {
            eventVersion = 1, timestamp = os.time(), source = "session-manager",
            payload = { sessionId = sessionId, playerSource = playerSource }
        })
    end
    
    return sessionId
end

function SessionManagerServer.StartSession(sessionId)
    ConnectToCore()
    local session = sessions[sessionId]
    if not session then log("error", "Session not found: %s", tostring(sessionId)); return false end
    
    session.state = SESSION_STATES.ACTIVE
    session.lastActivity = os.time()
    log("info", "Session starting: %s", sessionId)
    
    TriggerClientEvent('dce-cc:client:session:start', session.playerSource, {
        sessionId = sessionId,
        playerSource = session.playerSource
    })
    
    if EventBus then
        EventBus.Emit("session:started", {
            eventVersion = 1, timestamp = os.time(), source = "session-manager",
            payload = { sessionId = sessionId, playerSource = session.playerSource }
        })
    end
    
    return true
end

function SessionManagerServer.ReuseSession(playerSource)
    ConnectToCore()
    for _, session in pairs(sessions) do
        if session.playerSource == playerSource then
            session.lastActivity = os.time()
            TriggerClientEvent('dce-cc:client:session:reuse', playerSource, {
                sessionId = session.sessionId
            })
            return true
        end
    end
    return false
end

function SessionManagerServer.CloseSession(sessionId)
    ConnectToCore()
    local session = sessions[sessionId]
    if not session then return true end
    
    session.state = SESSION_STATES.CLOSED
    session.lastActivity = os.time()
    log("info", "Session closing: %s", sessionId)
    
    TriggerClientEvent('dce-cc:client:session:end', session.playerSource, { sessionId = sessionId })
    
    if EventBus then
        EventBus.Emit("session:closed", {
            eventVersion = 1, timestamp = os.time(), source = "session-manager",
            payload = { sessionId = sessionId, playerSource = session.playerSource }
        })
    end
    
    return true
end

function SessionManagerServer.EndSession(sessionId)
    local session = sessions[sessionId]
    if not session then return false end
    
    local playerSource = session.playerSource
    sessions[sessionId] = nil
    log("info", "Session ended: %s", sessionId)
    
    if EventBus then
        EventBus.Emit("session:ended", {
            eventVersion = 1, timestamp = os.time(), source = "session-manager",
            payload = { sessionId = sessionId, playerSource = playerSource }
        })
    end
    
    return true
end

function SessionManagerServer.GetSession(sessionId)
    return sessions[sessionId]
end

function SessionManagerServer.GetSessionByPlayer(playerSource)
    for _, session in pairs(sessions) do
        if session.playerSource == playerSource and session.state ~= SESSION_STATES.CLOSED then
            return session
        end
    end
    return nil
end

function SessionManagerServer.ListSessions()
    local result = {}
    for _, session in pairs(sessions) do
        if session.state == SESSION_STATES.ACTIVE then
            table.insert(result, session)
        end
    end
    return result
end

function SessionManagerServer.GetSessionCount()
    local count = 0
    for _, session in pairs(sessions) do
        if session.state == SESSION_STATES.ACTIVE then
            count = count + 1
        end
    end
    return count
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

RegisterNetEvent('dce-cc:session:close')
AddEventHandler('dce-cc:session:close', function()
    local ps = source
    local session = SessionManagerServer.GetSessionByPlayer(ps)
    if session then
        SessionManagerServer.CloseSession(session.sessionId)
        SessionManagerServer.EndSession(session.sessionId)
    end
end)

RegisterNetEvent('dce-cc:session:ended')
AddEventHandler('dce-cc:session:ended', function(data)
    if data and data.sessionId then
        SessionManagerServer.EndSession(data.sessionId)
    end
end)

-- Resource stop cleanup
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    local attempts = 0
    while not ConnectToCore() and attempts < 50 do
        Wait(100); attempts = attempts + 1
    end
    if DCE and DCE.RegisterService then
        DCE.RegisterService("SessionManager", SessionManagerServer)
        log("info", "SessionManager registered with DCE Core")
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for sid, _ in pairs(sessions) do
        SessionManagerServer.CloseSession(sid)
    end
    sessions = {}
end)

-- ============================================================================
-- Administrative Interface
-- ============================================================================

function SessionManagerServer.GetStatus()
    return {
        state = "running",
        uptime = os.time() - (SessionManagerServer._startUptime or os.time()),
        activeSessions = SessionManagerServer.GetSessionCount()
    }
end

function SessionManagerServer.GetHealth()
    return { healthy = true, errorCount = 0 }
end

function SessionManagerServer.GetMetrics()
    return { activeSessions = SessionManagerServer.GetSessionCount() }
end

function SessionManagerServer.GetCapabilities()
    return {
        admin = true,
        readOnly = false,
        actions = { "create", "start", "close", "end", "list" }
    }
end

SessionManagerServer._startUptime = os.time()
return SessionManagerServer