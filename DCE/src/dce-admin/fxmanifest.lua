-- DCE Admin UI
-- Admin dashboard, monitoring, and debug console

fx_version 'cerulean'
game 'gta5'

author 'DCE Team'
description 'Dynamic Criminal Ecosystem - Admin UI'
version '1.0.0'

dependencies {
    'dce-core',
}

shared_scripts {
    'config.lua',
}

server_scripts {
    'services/admin.lua',
    'init.lua',
}
