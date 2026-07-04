-- DCE Dispatch Service
-- Dispatch call lifecycle, native fallback adapter.

fx_version 'cerulean'
game 'gta5'

author 'DCE Team'
description 'Dynamic Criminal Ecosystem - Dispatch Service'
version '1.0.0'

dependencies {
    'dce-core',
}

shared_scripts {
    'config.lua',
    'models/call.lua',
}

server_scripts {
    'services/dispatch.lua',
    'adapters/native.lua',
    'init.lua',
}