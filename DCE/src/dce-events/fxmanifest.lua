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
}

server_scripts {
    'models/scenario.lua',
    'simulation/state-machine.lua',
    'simulation/escalation.lua',
    'data/scenarios.lua',
    'services/scenario-engine.lua',
    'init.lua',
}
