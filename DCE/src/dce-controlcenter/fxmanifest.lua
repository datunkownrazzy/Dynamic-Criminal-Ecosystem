-- DCE Control Center v2 - Authoritative Rebuild
-- True Lazy Initialization: Bootstrap exists -> Nothing happens -> /dce -> Everything initializes
-- Follows CC-v2-COMPLETE-ARCHITECTURE.md exactly
-- Per ADR-0026: Only bootstrap.js loads at resource start. All other JS is lazy loaded.
-- ZERO-TRUST BOUNDARY: Every file executes only in its architecturally designed runtime.

fx_version 'cerulean'
game 'gta5'

author 'DCE Team'
description 'Dynamic Criminal Ecosystem - Control Center v2'
version '2.0.0'

dependencies {
    'dce-core',
}

-- ============================================================================
-- Shared Configuration & Interfaces (PASSIVE - no runtime behavior)
-- ============================================================================

shared_scripts {
    'shared/config.lua',
    'shared/interfaces/IPlugin.lua',
    'shared/interfaces/ISession.lua',
    'shared/interfaces/IBrowserManager.lua',
}

-- ============================================================================
-- Server Scripts (load order defines dependency resolution)
-- ============================================================================
-- Server may ONLY own: Services, Registry, Adapters, Session creation, Workspace
-- Server may NEVER: RegisterCommand, SendNUIMessage, SetNuiFocus, RegisterNUICallback

server_scripts {
    -- 1. Services (register with DCE Core)
    'server/services/controlcenter.lua',
    'server/services/plugin-registry.lua',
    
    -- 2. Adapters (resolve subsystem API - NO business logic, NO UI)
    'server/adapters/world-adapter.lua',
    'server/adapters/organization-adapter.lua',
    'server/adapters/dispatch-adapter.lua',
    'server/adapters/evidence-adapter.lua',
    'server/adapters/ai-adapter.lua',
    'server/adapters/territory-adapter.lua',
    
    -- 3. Session Management (server-side ownership)
    'server/session-manager.lua',
    'server/workspace-manager.lua',
    
    -- 4. Main entry point (server-side only)
    'server/init.lua',
}

-- ============================================================================
-- Client Scripts
-- ============================================================================
-- Client may ONLY own: NUI, BrowserManager, FocusManager, Rendering, Commands
-- Client may NEVER: RegisterNetEvent for server events, access server services directly

client_scripts {
    -- Client entry point (/dce command registration)
    'client/init.lua',
    
    -- Bootstrap (minimal NUI communication only)
    'bootstrap/bootstrap.lua',
    
    -- Session & Focus Management (SOLE OWNERS - registered with DCE Core)
    'session/focus-manager.lua',
    'session/browser-manager.lua',
    'session/session-manager-client.lua',
    
    -- Client Controllers
    'client/controllers/session-controller.lua',
    
    -- NUI Layer
    'client/nui/event-forwarder.lua',
}

-- ============================================================================
-- NUI Files
-- ============================================================================
-- CRITICAL: Only bootstrap.js loads at resource start.
-- All other JS files are lazy loaded by DCE.Loader when /dce is processed.
-- This ensures NO application code executes before player opens CC.

files {
    -- Bootstrap HTML
    'html/bootstrap.html',
    
    -- Bootstrap JS ONLY (minimal communication shell)
    'html/js/bootstrap/bootstrap.js',
    
    -- Core (lazy loaded by ApplicationManager - lifecycle tracking)
    'html/js/core/lifecycle.js',
    'html/js/core/runtime.js',
    
    -- Application (lazy loaded by DCE.Loader)
    'html/js/application/application-manager.js',
    
    -- Plugin Manager (lazy loaded - owns plugin lifecycle)
    'html/js/plugins/plugin-manager.js',
    'html/js/plugins/plugin-host.js',
    
    -- UI Components (lazy loaded)
    'html/js/ui/desktop.js',
    'html/js/ui/dock.js',
    'html/js/ui/window-manager.js',
    'html/js/ui/notification-manager.js',
    'html/js/ui/command-palette.js',
    'html/js/ui/taskbar.js',
    'html/js/ui/panel.js',
    'html/js/ui/tab.js',
    'html/js/ui/context-menu.js',
    'html/js/ui/search.js',
    
    -- Plugins (lazy loaded, passive, event-driven)
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
    
    -- CSS
    'html/css/style.css',
    'html/css/themes/dark.css',
    'html/css/themes/light.css',
}

-- ui_page loads minimal bootstrap - nothing exists until /dce
ui_page 'html/bootstrap.html'

-- ============================================================================
-- Exports
-- ============================================================================
-- FocusManager is intentionally excluded from server_exports.
-- FocusManager is a client-side service registered via DCE Core on the client.
-- Server exports cannot resolve client-registered services.
-- Consumers must access FocusManager via client-side DCE:GetService("FocusManager").

server_exports {
    'GetPluginAPI',
    'GetSessionManager',
    'GetWorkspaceManager',
    'GetPluginRegistry',
}