-- DCE Control Center
-- Professional admin interface for DCE ecosystem management

fx_version 'cerulean'
game 'gta5'

author 'DCE Team'
description 'Dynamic Criminal Ecosystem - Control Center (Admin UI)'
version '1.0.3'

dependencies {
    'dce-core',
}

shared_scripts {
    'config.lua',
}

server_scripts {
    'services/admin.lua',
    'benchmarks/benchmark-suite.lua',
    'debug/mode-manager.lua',
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
    'html/js/framework.js',
    'html/js/window-manager.js',
    'html/js/api.js',
    'html/js/modules/overview.js',
    'html/js/modules/organizations.js',
    'html/js/modules/dispatch.js',
    'html/js/modules/analytics.js',
    'html/js/modules/performance.js',
    'html/js/modules/services.js',
    'html/js/modules/plugins.js',
    'html/js/modules/adapters.js',
    'html/js/modules/settings.js',
    'html/js/modules/locations.js',
    'html/js/modules/territories.js',
    'html/js/modules/world-editor.js',
}

ui_page 'html/index.html'