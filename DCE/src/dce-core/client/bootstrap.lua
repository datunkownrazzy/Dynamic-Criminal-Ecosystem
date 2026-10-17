-- DCE Client Bootstrap Pipeline — Sprint 1.11.7 FiveM Loader Compliance
--
-- SINGLE CLIENT COMPOSITION ROOT.
-- This file is executed by FiveM as the LAST client_script before client/init.lua.
-- FiveM's manifest ordering IS the dependency graph; there are NO require()
-- calls anywhere in dce-core. Every runtime constructor below was already
-- executed and registered on the client-only DCE_INTERNAL namespace by the
-- scripts listed before this one (runtime/state, runtime/logger,
-- runtime/registry, runtime/eventbus).
--
-- Client-side runtime: a MINIMAL SDK facade (State, Logger, Registry,
-- EventBus). No Scheduler, no PluginManager, no ConfigManager — those are
-- server-ops components and are NEVER loaded into the client Lua VM.
--
-- Deterministic initialization sequence (single pass, no Wait, no polling):
--   Constructors (manifest) → Compose Runtime → Create SDK → Freeze SDK
--   → Register Core Services → Mark Ready → Emit Sticky Lifecycle
--
-- Lifecycle Rule: Uses sticky lifecycle events for guaranteed delivery.
-- Consumers that subscribe after READY still receive the lifecycle event.
---@diagnostic disable: undefined-global

local ClientBootstrap = {}

function ClientBootstrap:Run()
    print("^2[DCE Client] === Client Bootstrap Pipeline Starting ===^0")

    -- ============================================================================
    -- Resolve constructors from the client-only internal namespace.
    -- Guaranteed present: client_scripts ordering in fxmanifest.lua executes
    -- every runtime/*.lua constructor BEFORE this composition root.
    -- ============================================================================
    local RuntimeState = DCE_INTERNAL.RuntimeState
    local Logger = DCE_INTERNAL.Logger
    local Registry = DCE_INTERNAL.Registry
    local EventBus = DCE_INTERNAL.EventBus
    local SDKBuilder = DCE_INTERNAL.SDKBuilder

    -- ============================================================================
    -- PHASE 1: Create Runtime State
    -- ============================================================================
    print("^2[DCE Client] Phase 1/5: Creating Runtime State^0")
    local state = RuntimeState:New()
    if not state then
        print("^1[DCE Client] FATAL: Failed to create Runtime State^0")
        return nil
    end
    print(string.format("^2[DCE Client] Runtime State created: %s^0", state.id))

    -- ============================================================================
    -- PHASE 2: Create Logger
    -- ============================================================================
    print("^2[DCE Client] Phase 2/5: Creating Logger^0")
    local logger = Logger:New(state)
    if not logger then
        print("^1[DCE Client] FATAL: Failed to create Logger^0")
        RuntimeState:SetFailed(state, "Logger creation failed")
        return nil
    end
    logger:LogInfo("bootstrap", "Client Logger initialized")

    -- ============================================================================
    -- PHASE 3: Create Registry
    -- ============================================================================
    RuntimeState:SetPhase(state, "REGISTRATION")
    logger:LogInfo("bootstrap", "Phase 3/5: Creating Registry")
    local registry = Registry:New(state, logger)
    if not registry then
        logger:LogError("bootstrap", "FATAL: Failed to create Registry")
        RuntimeState:SetFailed(state, "Registry creation failed")
        return nil
    end
    logger:LogInfo("bootstrap", "Client Registry initialized")

    -- ============================================================================
    -- PHASE 4: Create EventBus
    -- ============================================================================
    logger:LogInfo("bootstrap", "Phase 4/5: Creating EventBus")
    local eventBus = EventBus:New(state, logger)
    if not eventBus then
        logger:LogError("bootstrap", "FATAL: Failed to create EventBus")
        RuntimeState:SetFailed(state, "EventBus creation failed")
        return nil
    end
    logger:LogInfo("bootstrap", "Client EventBus initialized")

    -- ============================================================================
    -- PHASE 5: Create and Freeze SDK
    -- ============================================================================
    RuntimeState:SetPhase(state, "SDK")
    logger:LogInfo("bootstrap", "Phase 5/5: Creating SDK")
    local sdk = SDKBuilder:Build(state, registry, eventBus, nil, nil, nil, logger)
    if not sdk then
        logger:LogError("bootstrap", "FATAL: Failed to create SDK")
        RuntimeState:SetFailed(state, "SDK creation failed")
        return nil
    end

    -- Freeze the SDK (metatable is set inside SDKBuilder:Build)
    RuntimeState:SetPhase(state, "FREEZE")
    logger:LogInfo("bootstrap", "Client SDK created and frozen (id=%s)", sdk.__sdk_id)

    -- ============================================================================
    -- Register Core Services
    -- ============================================================================
    RuntimeState:SetPhase(state, "SERVICES")
    logger:LogInfo("bootstrap", "Registering client core services")

    sdk:RegisterService("CoreRegistry", {
        ListServices = function() return registry:List() end,
        ListPlugins = function() return {} end,
        ListTasks = function() return {} end,
        GetDCEVersion = function() return "1.0.0" end,
    })
    sdk:RegisterService("Logger", logger)
    sdk:RegisterService("EventBus", eventBus)
    sdk:RegisterService("Registry", registry)

    logger:LogInfo("bootstrap", "Client core services registered: %s", table.concat(registry:List(), ", "))

    -- ============================================================================
    -- Mark Ready
    -- ============================================================================
    RuntimeState:SetPhase(state, "READY")
    logger:LogInfo("bootstrap", "Client Runtime READY")

    -- Emit lifecycle:ready as a sticky event for guaranteed delivery
    eventBus:Sticky("lifecycle:ready")
    eventBus:EmitSticky("lifecycle:ready", {
        timestamp = GetGameTimer and GetGameTimer() or 0,
        source = "dce-core-client",
        payload = {
            version = "1.0.0",
            bootID = state.bootID,
            runtimeID = state.id,
        },
    })

    -- ============================================================================
    -- Mark Running
    -- ============================================================================
    RuntimeState:SetPhase(state, "RUNNING")
    logger:LogInfo("bootstrap", "=== DCE Client v1.0.0 Platform Running ===")

    -- Emit lifecycle:running as a sticky event
    eventBus:Sticky("lifecycle:running")
    eventBus:EmitSticky("lifecycle:running", {
        timestamp = GetGameTimer and GetGameTimer() or 0,
        source = "dce-core-client",
        payload = {
            version = "1.0.0",
            bootID = state.bootID,
        },
    })

    -- ============================================================================
    -- Return runtime components
    -- ============================================================================

    return {
        state = state,
        logger = logger,
        registry = registry,
        eventBus = eventBus,
        scheduler = nil,
        pluginManager = nil,
        configManager = nil,
        sdk = sdk,
    }
end

-- Registered on the client-only DCE_INTERNAL namespace.
-- client/init.lua (the final client_script) invokes this composition root
-- directly via DCE_INTERNAL.ClientBootstrap — no require(), no hidden module tree.
DCE_INTERNAL = DCE_INTERNAL or {}
DCE_INTERNAL.ClientBootstrap = ClientBootstrap