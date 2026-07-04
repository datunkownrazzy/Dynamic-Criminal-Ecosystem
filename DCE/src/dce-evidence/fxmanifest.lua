-- DCE Evidence Service
-- Evidence registry, lifecycle, chain of custody.

fx_version 'cerulean'
game 'gta5'

author 'DCE Team'
description 'Dynamic Criminal Ecosystem - Evidence Service'
version '1.0.0'

dependencies {
    'dce-core',
}

shared_scripts {
    'config.lua',
    'models/evidence.lua',
    'models/custody.lua',
}

server_scripts {
    'services/evidence.lua',
    'services/evidence-factory.lua',
    'init.lua',
}