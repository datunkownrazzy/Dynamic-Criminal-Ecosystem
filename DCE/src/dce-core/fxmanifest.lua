-- DCE Core
-- Service Registry, Event Bus, Scheduler, Logger, Config Loader
-- This is the only hard dependency for all other DCE resources.

fx_version 'cerulean'
game 'gta5'

author 'DCE Team'
description 'Dynamic Criminal Ecosystem - Core Framework'
version '1.0.0'

shared_scripts {
    'config.lua',
}

server_scripts {
    'shared/globals.lua',
    'core/logger.lua',
    'core/registry.lua',
    'core/eventbus.lua',
    'core/scheduler.lua',
    'core/config.lua',
    'core/plugin-manager.lua',
    'init.lua',
}

-- DCE core must start before any other DCE resource
-- Other resources should declare 'dce-core' in their dependencies

server_exports {
    'GetDCEAPI',
}