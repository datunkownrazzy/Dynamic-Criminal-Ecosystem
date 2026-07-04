-- DCE Dispatch Service
-- Dispatch call lifecycle, native fallback adapter.

fx_version 'cerulean'
game 'gta5'

author 'DCE Team'
description 'Dynamic Criminal Ecosystem - Dispatch Service'
version '1.0.0'

dependencies {
    'dce-core',
    'dce-events',
}

shared_scripts {
    'config.lua',
}

server_scripts {
    'models/call.lua',
    'services/dispatch.lua',
    'adapters/native.lua',
    'adapters/ers.lua',
    'init.lua',
}
