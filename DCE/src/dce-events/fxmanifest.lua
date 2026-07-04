-- DCE Scenario Engine
-- Scenario lifecycle, stage progression, and escalation rules.

fx_version 'cerulean'
game 'gta5'

author 'DCE Team'
description 'Dynamic Criminal Ecosystem - Scenario Engine'
version '1.0.0'

dependencies {
    'dce-core',
    'dce-ai',
}

shared_scripts {
    'config.lua',
    'models/scenario.lua',
    'data/scenarios.lua',
}

server_scripts {
    'services/scenario-engine.lua',
    'simulation/state-machine.lua',
    'simulation/escalation.lua',
    'init.lua',
}