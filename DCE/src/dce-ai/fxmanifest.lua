-- DCE AI Director & Organizations
-- Activity scoring, organization state machine, AI Director decision loop.

fx_version 'cerulean'
game 'gta5'

author 'DCE Team'
description 'Dynamic Criminal Ecosystem - AI Director & Organizations'
version '1.0.0'

dependencies {
    'dce-core',
    'dce-world',
}

shared_scripts {
    'config.lua',
}

server_scripts {
    'models/organization.lua',
    'models/activity.lua',
    'data/organizations.lua',
    'data/activities.lua',
    'simulation/scoring.lua',
    'simulation/state-transitions.lua',
    'services/organizations.lua',
    'services/ai-director.lua',
    'init.lua',
}
