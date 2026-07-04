-- DCE AI Director & Organizations
-- Organization state, AI decision-making, and activity selection.
-- Per ADR-0001: Organizations and AI Director share this resource.

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
    'models/organization.lua',
    'models/activity.lua',
    'data/organizations.lua',
    'data/activities.lua',
}

server_scripts {
    'services/organizations.lua',
    'services/ai-director.lua',
    'simulation/scoring.lua',
    'simulation/state-transitions.lua',
    'init.lua',
}