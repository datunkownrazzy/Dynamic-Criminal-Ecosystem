-- DCE Core — Sprint 1.11.7 FiveM Loader Compliance
--
-- This manifest is the EXECUTABLE DEPENDENCY GRAPH.
-- FiveM executes each listed script in order, in its OWN runtime VM:
--   * shared_scripts  → executed on BOTH server and client VMs
--   * server_scripts  → executed on the SERVER VM only
--   * client_scripts  → executed on the CLIENT VM only
--
-- Loader contract (per FiveM script reference):
--   * shared_scripts are loaded on both sides. Therefore NO server
--     runtime module may be listed here. Only pure configuration data.
--   * server_scripts execute in listing order. This IS the dependency
--     graph. No require() is used anywhere in this resource.
--   * Each runtime/*.lua registers its constructor on the internal
--     DCE_INTERNAL namespace (server-only, never published to _G).
--   * runtime/bootstrap.lua is the SINGLE composition root.
--   * init.lua runs the composition root and defines exports.
--
-- Graph:
--   server_scripts (server VM only)
--     runtime/state → logger → registry → eventbus → scheduler
--     → plugin-manager → config-manager → sdk      (constructors)
--     → runtime/bootstrap.lua                      (composition root)
--     → init.lua                                   (exports)
--   client_scripts (client VM only)
--     client/bootstrap.lua                         (minimal client facade)
--     client/init.lua                              (client exports)
--   shared_scripts (both VMs)
--     config.lua                                   (pure data only)
--
-- Exports are defined as static functions in init.lua / client/init.lua
-- and therefore ALWAYS exist once this resource has started.
-- Downstream resources declare dependencies {'dce-core'} so FiveM
-- guarantees dce-core reaches fully-started BEFORE any consumer executes.
---@diagnostic disable: undefined-global

fx_version 'cerulean'
game 'gta5'

author 'DCE Team'
description 'Dynamic Criminal Ecosystem - Core Platform Runtime'
version '1.11.7'

-- Pure configuration data only. Shared per manifest semantics (both VMs).
-- No runtime behavior, no globals beyond the Config table.
shared_scripts {
    'config.lua',
}

-- Server-only runtime. Order IS the dependency graph.
-- Constructors first (leaf-first), composition root next, entry last.
server_scripts {
    'runtime/state.lua',
    'runtime/logger.lua',
    'runtime/registry.lua',
    'runtime/eventbus.lua',
    'runtime/scheduler.lua',
    'runtime/plugin-manager.lua',
    'runtime/config-manager.lua',
    'runtime/configuration-service.lua',
    'runtime/sdk.lua',
    'runtime/bootstrap.lua',
    'init.lua',
}

-- Client-only runtime (separate Lua VM per FiveM).
-- The PURE leaf modules are shared with the client VM: state, logger,
-- registry, eventbus, and the SDK BUILDER (required by client/bootstrap.lua
-- to compose the client SDK facade). Server-ops modules (scheduler,
-- plugin-manager, config-manager) are NEVER loaded on the client.
-- client/bootstrap.lua composes the client-only SDK facade.
client_scripts {
    'runtime/state.lua',
    'runtime/logger.lua',
    'runtime/registry.lua',
    'runtime/eventbus.lua',
    'runtime/sdk.lua',
    'client/bootstrap.lua',
    'client/init.lua',
}

-- Server exports
server_exports {
    'GetDCEAPI',
    'DCE_Subscribe',
    'IsReady',
}

-- Client exports
client_exports {
    'GetDCEAPI',
    'DCE_Subscribe',
    'IsReady',
}