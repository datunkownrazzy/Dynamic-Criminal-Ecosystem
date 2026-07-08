-- DCE Control Center v2
-- Professional desktop-style admin interface for DCE ecosystem management
-- Complete rebuild - does NOT reuse dce-admin implementation

fx_version 'cerulean'
game 'gta5'

author 'DCE Team'
description 'Dynamic Criminal Ecosystem - Control Center v2 (Operating System for DCE)'
version '2.0.0'

dependencies {
    'dce-core',
    'dce-world',
}

shared_scripts {
    'shared/config.lua',
}

server_scripts {
    'server/services/controlcenter.lua',
    'server/services/location-editor.lua',
    'server/services/organization-editor.lua',
    'server/services/plugin-registry.lua',
    'server/controllers/permission-controller.lua',
    'server/controllers/window-controller.lua',
    'server/adapters/native-provider.lua',
    'server/adapters/mlo-provider.lua',
    'server/adapters/instanced-provider.lua',
    'init.lua',
}

client_scripts {
    'client/nui/lifecycle-manager.lua',
    'client/nui/event-forwarder.lua',
    'client/controllers/plugin-controller.lua',
    'client/controllers/runtime-controller.lua',
}

-- NUI Files
file {
    'html/index.html',
    'html/css/style.css',
    'html/css/themes/dark.css',
    'html/css/themes/light.css',
    'html/js/app.js',
    'html/js/core/lifecycle.js',
    'html/js/core/viewmodel.js',
    'html/js/core/inspector.js',
    'html/js/core/command-palette.js',
    'html/js/core/notifications.js',
    'html/js/core/activity-log.js',
    'html/js/core/breadcrumb.js',
    'html/js/ui/desktop.js',
    'html/js/ui/window-manager.js',
    'html/js/ui/dock.js',
    'html/js/ui/panel.js',
    'html/js/ui/tab.js',
    'html/js/ui/context-menu.js',
    'html/js/ui/search.js',
    'html/js/plugins/world-manager/world-manager.js',
    'html/js/plugins/organization-manager/organization-manager.js',
    'html/js/plugins/scenario-manager/scenario-manager.js',
    'html/js/plugins/evidence-manager/evidence-manager.js',
    'html/js/plugins/dispatch-manager/dispatch-manager.js',
    'html/js/plugins/ai-manager/ai-manager.js',
    'html/js/plugins/economy-manager/economy-manager.js',
    'html/js/plugins/analytics/analytics.js',
    'html/js/plugins/server-monitor/server-monitor.js',
    'html/js/plugins/dev-tools/dev-tools.js',
}

ui_page 'html/index.html'