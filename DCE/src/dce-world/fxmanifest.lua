-- DCE World Engine
-- World state, statistical simulation (Layer 0), Ambient simulation (Layer 1)

fx_version 'cerulean'
game 'gta5'

author 'DCE Team'
description 'Dynamic Criminal Ecosystem - World Engine'
version '1.0.0'

dependencies {
    'dce-core',
}

shared_scripts {
    'config.lua',
}

server_scripts {
    'models/region.lua',
    'models/world-state.lua',
    'simulation/layer0.lua',
    'simulation/layer1.lua',
    'simulation/time.lua',
    'simulation/weather.lua',
    'data/regions.lua',
    'services/world.lua',
    'init.lua',
}
