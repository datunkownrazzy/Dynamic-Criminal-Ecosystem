/**
 * DCE Control Center v2 - Application Manager (Authoritative)
 * 
 * TRUE LAZY INITIALIZATION - Per ADR-0026 and CC-v2-COMPLETE-ARCHITECTURE.md
 * This module is loaded dynamically by DCE.Loader when /dce is processed.
 * NOTHING exists before /dce command.
 * 
 * Ownership:
 * - Owns: Desktop, Dock, Plugin Manager, Window Manager
 * - Does NOT own: Focus (FocusManager.lua), Browser (FiveM), Session (SessionManager.lua)
 * 
 * Boot Sequence:
 * 1. application-manager.js loaded by DCE.Loader (triggered by 'application:boot' message)
 * 2. Boot() called with sessionId -> loads UI -> loads plugins -> signals ready
 * 3. Lua FocusManager.RequestFocus() called after boot complete
 * 4. Activate() called -> desktop becomes visible
 */

(function() {
    'use strict';
    
    window.DCE = window.DCE || {};
    
    // ===========================================================================
    // Application State Machine
    // ===========================================================================
    
    var APP_STATE = {
        UNLOADED: 'unloaded',
        BOOTING: 'booting',
        READY: 'ready',
        ACTIVE: 'active',
        SHUTTING_DOWN: 'shutting-down'
    };
    
    // ===========================================================================
    // Application Object
    // ===========================================================================
    
    DCE.Application = {
        state: APP_STATE.UNLOADED,
        sessionId: null,
        _components: {},
        _timers: new Set()
    };
    
    // ===========================================================================
    // State Management
    // ===========================================================================
    
    DCE.Application.setState = function(newState) {
        var oldState = DCE.Application.state;
        DCE.Application.state = newState;
        document.body.className = 'cc-' + newState;
        console.log('[DCE Application] State:', oldState, '\u2192', newState, '| session:', DCE.Application.sessionId);
        return true;
    };
    
    // ===========================================================================
    // Lazy Scripts - Loaded on /dce only
    // ===========================================================================
    
    var UI_SCRIPTS = [
        'js/core/lifecycle.js',
        'js/core/runtime.js',
        'js/ui/desktop.js',
        'js/ui/dock.js',
        'js/ui/window-manager.js',
        'js/ui/notification-manager.js',
        'js/ui/command-palette.js',
        'js/ui/taskbar.js'
    ];
    
    var PLUGIN_MANAGER_SCRIPT = 'js/plugins/plugin-manager.js';
    var PLUGIN_HOST_SCRIPT = 'js/plugins/plugin-host.js';
    
    var PLUGIN_SCRIPTS = [
        'js/plugins/world-manager/world-manager.js',
        'js/plugins/organization-manager/organization-manager.js',
        'js/plugins/scenario-manager/scenario-manager.js',
        'js/plugins/evidence-manager/evidence-manager.js',
        'js/plugins/dispatch-manager/dispatch-manager.js',
        'js/plugins/ai-manager/ai-manager.js',
        'js/plugins/economy-manager/economy-manager.js',
        'js/plugins/analytics/analytics.js',
        'js/plugins/server-monitor/server-monitor.js',
        'js/plugins/dev-tools/dev-tools.js'
    ];
    
    // ===========================================================================
    // Boot - Called when /dce is processed (TRUE LAZY INIT)
    // ===========================================================================
    
    DCE.Application.Boot = function(sessionId) {
        console.log('[DCE Application] Booting for session:', sessionId);
        DCE.Application.setState(APP_STATE.BOOTING);
        DCE.Application.sessionId = sessionId;
        
        // Load UI components in order
        return DCE.Loader.loadScripts(UI_SCRIPTS)
            .then(function() {
                if (DCE.Desktop && DCE.Desktop.create) DCE.Desktop.create();
                DCE.Application._components.desktop = DCE.Desktop;
                
                return DCE.Loader.loadScript(PLUGIN_MANAGER_SCRIPT);
            })
            .then(function() {
                if (DCE.Plugins && DCE.Plugins.Manager && DCE.Plugins.Manager.create) {
                    DCE.Plugins.Manager.create();
                    DCE.Application._components.pluginManager = DCE.Plugins.Manager;
                }
                
                if (DCE.Windows && DCE.Windows.create) {
                    DCE.Windows.create();
                    DCE.Application._components.windowManager = DCE.Windows;
                }
                
                if (DCE.Dock && DCE.Dock.init) DCE.Dock.init();
                DCE.Application._components.dock = DCE.Dock;
                
                return DCE.Loader.loadScripts(PLUGIN_SCRIPTS);
            })
            .then(function() {
                if (DCE.Plugins && DCE.Plugins.Manager && DCE.Plugins.Manager.discoverPlugins) {
                    DCE.Plugins.Manager.discoverPlugins();
                }
                
                DCE.Application.setState(APP_STATE.READY);
                console.log('[DCE Application] Boot complete, awaiting focus activation');
                
                DCE.NUI.post('dce-cc:application:booted', {
                    sessionId: sessionId,
                    state: APP_STATE.READY
                }).catch(function() {});
                
                return true;
            })
            .catch(function(err) {
                console.error('[DCE Application] Boot error:', err);
                DCE.Application.setState(APP_STATE.UNLOADED);
                return false;
            });
    };
    
    // ===========================================================================
    // Activate - Called after Lua FocusManager grants focus
    // ===========================================================================
    
    DCE.Application.Activate = function() {
        console.log('[DCE Application] Activating...');
        
        if (DCE.Application._components.pluginManager && DCE.Application._components.pluginManager.loadPlugins) {
            DCE.Application._components.pluginManager.loadPlugins();
        }
        
        if (DCE.Application._components.desktop && DCE.Application._components.desktop.open) {
            DCE.Application._components.desktop.open();
        }
        
        DCE.Application.setState(APP_STATE.ACTIVE);
        
        if (DCE.Dock && DCE.Dock._refreshDock) DCE.Dock._refreshDock();
        
        DCE.NUI.post('dce-cc:session:started', {
            sessionId: DCE.Application.sessionId,
            state: APP_STATE.ACTIVE
        }).catch(function() {});
    };
    
    // ===========================================================================
    // Shutdown - Cleanup on CC close
    // ===========================================================================
    
    DCE.Application.Shutdown = function() {
        console.log('[DCE Application] Shutting down...');
        DCE.Application.setState(APP_STATE.SHUTTING_DOWN);
        
        if (DCE.Application._components.windowManager && DCE.Application._components.windowManager.closeAll) {
            DCE.Application._components.windowManager.closeAll();
        }
        
        if (DCE.Application._components.pluginManager && DCE.Application._components.pluginManager.unloadPlugins) {
            DCE.Application._components.pluginManager.unloadPlugins();
        }
        
        if (DCE.Application._components.desktop && DCE.Application._components.desktop.close) {
            DCE.Application._components.desktop.close();
        }
        
        DCE.Application.Cleanup();
        DCE.Application._components = {};
        DCE.Application.setState(APP_STATE.UNLOADED);
        DCE.Application.sessionId = null;
    };
    
    // ===========================================================================
    // Resource Cleanup
    // ===========================================================================
    
    DCE.Application.Cleanup = function() {
        DCE.Application._timers.forEach(function(timerId) {
            clearInterval(timerId);
            clearTimeout(timerId);
        });
        DCE.Application._timers.clear();
    };
    
    DCE.Application.setInterval = function(callback, interval) {
        var timerId = setInterval(callback, interval);
        DCE.Application._timers.add(timerId);
        return timerId;
    };
    
    DCE.Application.setTimeout = function(callback, delay) {
        var timerId = setTimeout(callback, delay);
        DCE.Application._timers.add(timerId);
        return timerId;
    };
    
    // ===========================================================================
    // Message Handler - Responds to Lua NUI messages
    // ===========================================================================
    
    window.addEventListener('message', function(event) {
        var data = event.data;
        if (!data || !data.action) return;
        
        switch (data.action) {
            case 'application:boot':
                DCE.Application.Boot(data.sessionId);
                break;
            case 'application:activate':
                DCE.Application.Activate();
                break;
            case 'application:shutdown':
                DCE.Application.Shutdown();
                break;
            case 'lifecycle:cleanup':
                DCE.Application.Cleanup();
                DCE.Application.setState(APP_STATE.UNLOADED);
                break;
        }
    });
    
    console.log('[DCE Application] Loaded (v2.0.0)');
})();