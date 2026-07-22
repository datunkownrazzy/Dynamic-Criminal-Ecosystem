-- DCE Core
-- Service Registry, Event Bus, Scheduler, Logger, Config Loader
-- This is the only hard dependency for all other DCE resources.
-- NOTE: "undefined-global" diagnostics for client_exports, server_exports, etc.
-- are false positives from LuaLS. These are FiveM fxmanifest directives, not Lua globals.
---@diagnostic disable: undefined-global

fx_version 'cerulean'
game 'gta5'

author 'DCE Team'
description 'Dynamic Criminal Ecosystem - Core Framework'
version '1.0.0'

shared_scripts {
    'config.lua',
}

-- Server scripts: Core service implementations
server_scripts {
    'shared/globals.lua',
    -- Sprint 1.10.2: Frozen SDK must load before all services
    'sdk/sdk-wrapper.lua',
    'core/logger.lua',
    'core/registry.lua',
    'core/eventbus.lua',
    'core/scheduler.lua',
    'core/profiler.lua',
    'core/cache.lua',
    'core/pool.lua',
    'core/alert-handler.lua',
    'core/config.lua',
    'core/plugin-manager.lua',
    'core/diagnostics.lua',
    -- Sprint 1.9 Consolidated Architecture Framework
    'runtime/core/state.lua',
    'runtime/core/graceful-degradation.lua',
    'runtime/core/self-validation.lua',
    'runtime/core/failure-injection.lua',
    'runtime/diagnostics.lua',
    'runtime/boot-timeline.lua',
    'runtime/service-validator.lua',
    'runtime/cc-diagnostics.lua',
    'runtime/report.lua',
    'runtime/commands.lua',
    'runtime/init.lua',
    -- Sprint 1.9 New Architecture Components
    'verifier/init.lua',
    'lifecycle/service-lifecycle.lua',
    'lifecycle/resource-lifecycle.lua',
    'event/event-bus.lua',
    'plugin/plugin-manager.lua',
    'config/config-framework.lua',
    'init.lua',
}

-- Client scripts: Core services MUST also be initialized client-side
-- because other resources (dce-controlcenter, dce-events, dce-ai, etc.)
-- call exports['dce-core']:GetDCEAPI() from client scripts.
-- Without this section, those calls fail with "No such export".
client_scripts {
    'shared/globals.lua',
    -- Sprint 1.10.2: Frozen SDK must load before all services
    'sdk/sdk-wrapper.lua',
    'core/logger.lua',
    'core/registry.lua',
    'core/eventbus.lua',
    'core/scheduler.lua',
    'core/profiler.lua',
    'core/cache.lua',
    'core/pool.lua',
    'core/alert-handler.lua',
    'core/config.lua',
    'core/plugin-manager.lua',
    'core/diagnostics.lua',
    -- Sprint 1.9 Architecture Components (client-side symmetry)
    'runtime/core/state.lua',
    'runtime/core/graceful-degradation.lua',
    'runtime/core/self-validation.lua',
    'runtime/core/failure-injection.lua',
    'runtime/diagnostics.lua',
    'runtime/boot-timeline.lua',
    'runtime/service-validator.lua',
    'runtime/cc-diagnostics.lua',
    'runtime/report.lua',
    'runtime/commands.lua',
    'runtime/init.lua',
    -- Sprint 1.9 New Architecture Components (client-side)
    'verifier/init.lua',
    'lifecycle/service-lifecycle.lua',
    'lifecycle/resource-lifecycle.lua',
    'event/event-bus.lua',
    'plugin/plugin-manager.lua',
    'config/config-framework.lua',
    'client/init.lua',
}

-- DCE core must start before any other DCE resource
-- Other resources should declare 'dce-core' in their dependencies

-- Server exports
server_exports {
    'GetDCEAPI',
    'DCE_Subscribe',
    'IsReady',
}

-- Client exports - REQUIRED for client-side exports['dce-core']:GetDCEAPI() to work
client_exports {
    'GetDCEAPI',
    'DCE_Subscribe',
    'IsReady',
}