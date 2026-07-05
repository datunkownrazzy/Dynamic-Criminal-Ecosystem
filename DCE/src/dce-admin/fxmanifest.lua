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
    'commands.lua',
    'init.lua',
}

-- DCE core must start before any other DCE resource
-- Other resources should declare 'dce-core' in their dependencies

server_exports {
    'GetConfig',
}

client_scripts {
    'client/*.lua',
}

-- NUI Files
file {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
}

ui_page 'html/index.html'