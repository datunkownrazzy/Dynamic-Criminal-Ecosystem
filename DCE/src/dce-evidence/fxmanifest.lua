-- DCE Evidence Service
-- Evidence registry, lifecycle, chain of custody.

fx_version 'cerulean'
game 'gta5'

author 'DCE Team'
description 'Dynamic Criminal Ecosystem - Evidence Service'
version '1.0.0'

dependencies {
    'dce-core',
    'dce-events',
}

shared_scripts {
    'config.lua',
}

server_scripts {
    'models/evidence.lua',
    'models/custody.lua',
    'services/evidence.lua',
    'services/evidence-factory.lua',
    'adapters/ers.lua',
    'init.lua',
}
