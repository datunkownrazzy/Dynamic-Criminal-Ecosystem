-- DCE Bootstrap Pipeline — Sprint 1.11.6 FiveM Loader Compliance
--
-- SINGLE COMPOSITION ROOT.
-- This file is executed by FiveM as the LAST server_script before init.lua.
-- FiveM's manifest ordering IS the dependency graph; there are NO require()
-- calls anywhere in dce-core. Every runtime constructor below was already
-- executed and registered on the server-only DCE_INTERNAL namespace by the
-- scripts listed before this one.
--
-- Deterministic initialization sequence (single pass, no Wait, no polling):
--   Constructors (manifest) → Compose Runtime → Create SDK → Freeze SDK
--   → Register Core Services → Mark Ready → Emit Sticky Lifecycle
--
-- Lifecycle Rule: Uses sticky lifecycle events for guaranteed delivery.
-- Consumers that subscribe after READY still receive the lifecycle event.
---@diagnostic disable: undefined-global

local Bootstrap = {}

function Bootstrap:Run()
    print("^2[DCE] === Bootstrap Pipeline Starting ===^0")

    -- ============================================================================
    -- Resolve constructors from the server-only internal namespace.
    -- Guaranteed present: server_scripts ordering in fxmanifest.lua executes
    -- every runtime/*.lua constructor BEFORE this composition root.
    -- ============================================================================
    local RuntimeState = DCE_INTERNAL.RuntimeState
    local Logger = DCE_INTERNAL.Logger
    local Registry = DCE_INTERNAL.Registry
    local EventBus = DCE_INTERNAL.EventBus
    local Scheduler = DCE_INTERNAL.Scheduler
    local PluginManager = DCE_INTERNAL.PluginManager
    local ConfigManager = DCE_INTERNAL.ConfigManager
    local ConfigurationService = DCE_INTERNAL.ConfigurationService
    local SDKBuilder = DCE_INTERNAL.SDKBuilder

    -- ============================================================================
    -- PHASE 1: Create Runtime State
    -- ============================================================================
    print("^2[DCE] Phase 1/8: Creating Runtime State^0")
    local state = RuntimeState:New()
    if not state then
        print("^1[DCE] FATAL: Failed to create Runtime State^0")
        return nil
    end
    print(string.format("^2[DCE] Runtime State created: %s^0", state.id))

    -- ============================================================================
    -- PHASE 2: Create Logger
    -- ============================================================================
    print("^2[DCE] Phase 2/8: Creating Logger^0")
    local logger = Logger:New(state)
    if not logger then
        print("^1[DCE] FATAL: Failed to create Logger^0")
        RuntimeState:SetFailed(state, "Logger creation failed")
        return nil
    end
    logger:LogInfo("bootstrap", "Logger initialized")

    -- ============================================================================
    -- PHASE 3: Create Registry
    -- ============================================================================
    RuntimeState:SetPhase(state, "REGISTRATION")
    logger:LogInfo("bootstrap", "Phase 3/8: Creating Registry")
    local registry = Registry:New(state, logger)
    if not registry then
        logger:LogError("bootstrap", "FATAL: Failed to create Registry")
        RuntimeState:SetFailed(state, "Registry creation failed")
        return nil
    end
    logger:LogInfo("bootstrap", "Registry initialized")

    -- ============================================================================
    -- PHASE 4: Create EventBus
    -- ============================================================================
    logger:LogInfo("bootstrap", "Phase 4/8: Creating EventBus")
    local eventBus = EventBus:New(state, logger)
    if not eventBus then
        logger:LogError("bootstrap", "FATAL: Failed to create EventBus")
        RuntimeState:SetFailed(state, "EventBus creation failed")
        return nil
    end
    logger:LogInfo("bootstrap", "EventBus initialized")

    -- ============================================================================
    -- PHASE 5: Create Scheduler
    -- ============================================================================
    logger:LogInfo("bootstrap", "Phase 5/8: Creating Scheduler")
    local scheduler = Scheduler:New(state, logger)
    if not scheduler then
        logger:LogError("bootstrap", "FATAL: Failed to create Scheduler")
        RuntimeState:SetFailed(state, "Scheduler creation failed")
        return nil
    end
    logger:LogInfo("bootstrap", "Scheduler initialized")

    -- ============================================================================
    -- PHASE 6: Create PluginManager & ConfigManager
    -- ============================================================================
    logger:LogInfo("bootstrap", "Phase 6/8: Creating PluginManager & ConfigManager")
    local pluginManager = PluginManager:New(state, logger)
    if not pluginManager then
        logger:LogError("bootstrap", "FATAL: Failed to create PluginManager")
        RuntimeState:SetFailed(state, "PluginManager creation failed")
        return nil
    end

    local configManager = ConfigManager:New(state, logger)
    if not configManager then
        logger:LogError("bootstrap", "FATAL: Failed to create ConfigManager")
        RuntimeState:SetFailed(state, "ConfigManager creation failed")
        return nil
    end
    local configurationService = ConfigurationService:New(eventBus, logger)
    logger:LogInfo("bootstrap", "PluginManager, ConfigManager & ConfigurationService initialized")

    -- ============================================================================
    -- PHASE 7: Create and Freeze SDK
    -- ============================================================================
    RuntimeState:SetPhase(state, "SDK")
    logger:LogInfo("bootstrap", "Phase 7/8: Creating SDK")
    local sdk = SDKBuilder:Build(state, registry, eventBus, scheduler, pluginManager, configManager, logger)
    if not sdk then
        logger:LogError("bootstrap", "FATAL: Failed to create SDK")
        RuntimeState:SetFailed(state, "SDK creation failed")
        return nil
    end

    -- Freeze the SDK (metatable is set inside SDKBuilder:Build)
    RuntimeState:SetPhase(state, "FREEZE")
    logger:LogInfo("bootstrap", "SDK created and frozen (id=%s)", sdk.__sdk_id)

    -- ============================================================================
    -- Register Core Services
    -- ============================================================================
    RuntimeState:SetPhase(state, "SERVICES")
    logger:LogInfo("bootstrap", "Registering core services")

    sdk:RegisterService("CoreRegistry", {
        ListServices = function() return registry:List() end,
        ListPlugins = function() return pluginManager:List() end,
        ListTasks = function() return scheduler:ListTasks() end,
        GetDCEVersion = function() return "1.0.0" end,
    })
    sdk:RegisterService("Logger", logger)
    sdk:RegisterService("EventBus", eventBus)
    sdk:RegisterService("Scheduler", scheduler)
    sdk:RegisterService("Registry", registry)
    sdk:RegisterService("PluginManager", pluginManager)
    sdk:RegisterService("ConfigManager", configManager)
    sdk:RegisterService("ConfigurationService", configurationService)

    logger:LogInfo("bootstrap", "Core services registered: %s", table.concat(registry:List(), ", "))

    -- ============================================================================
    -- Register Exports
    -- ============================================================================
    RuntimeState:SetPhase(state, "EXPORTS")

    -- Exports are registered by the caller (init.lua) immediately after this
    -- composition root returns. They are static functions and therefore always
    -- exist before any consumer resource can execute (FiveM dependency ordering).
    -- The EXPORTS phase records the contract state for observability.

    -- ============================================================================
    -- Mark Ready
    -- ============================================================================
    RuntimeState:SetPhase(state, "READY")
    logger:LogInfo("bootstrap", "Runtime READY")

    -- Emit lifecycle:ready as a sticky event for guaranteed delivery
    eventBus:Sticky("lifecycle:ready")
    eventBus:EmitSticky("lifecycle:ready", {
        timestamp = GetGameTimer and GetGameTimer() or 0,
        source = "dce-core",
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
    logger:LogInfo("bootstrap", "=== DCE v1.0.0 Platform Running ===")

    -- Emit lifecycle:running as a sticky event
    eventBus:Sticky("lifecycle:running")
    eventBus:EmitSticky("lifecycle:running", {
        timestamp = GetGameTimer and GetGameTimer() or 0,
        source = "dce-core",
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
        scheduler = scheduler,
        pluginManager = pluginManager,
        configManager = configManager,
        configurationService = configurationService,
        sdk = sdk,
    }
end

-- Registered on the server-only DCE_INTERNAL namespace.
-- init.lua (the final server_script) invokes this composition root directly
-- via DCE_INTERNAL.Bootstrap — no require(), no hidden module tree.
DCE_INTERNAL = DCE_INTERNAL or {}
DCE_INTERNAL.Bootstrap = Bootstrap
