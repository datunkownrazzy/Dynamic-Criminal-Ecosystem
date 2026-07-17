/**
 * DCE Control Center v2 - Plugin Host (Authoritative)
 * 
 * Per CC-v2-COMPLETE-ARCHITECTURE.md:
 * - PluginHost owns: plugin mounting, isolation, runtime messaging
 * - PluginManager owns: plugin lifecycle (init, start, stop, destroy)
 * - Plugins NEVER initialize themselves
 * - Plugins NEVER manage focus
 * - Plugins NEVER open UI windows directly
 * 
 * Plugin Lifecycle:
 * discovery -> manifest validation -> dependency resolution ->
 * registration -> initialization -> activation -> (suspension/resume)* -> destruction
 * 
 * Hot Reload Support:
 * - Plugin can be deregistered, re-registered, and re-initialized at runtime
 * - All existing timers/subscriptions are cleaned up on deregistration
 * - EventBus subscriptions are resumed on reactivation
 */

(function() {
    'use strict';
    
    window.DCE = window.DCE || {};
    
    var PLUGIN_STATES = {
        DISCOVERED: 'discovered',
        REGISTERED: 'registered',
        INITIALIZED: 'initialized',
        ACTIVE: 'active',
        SUSPENDED: 'suspended',
        ERROR: 'error',
        DESTROYED: 'destroyed'
    };
    
    DCE.PluginHost = {
        _plugins: {},          // id -> plugin instance
        _manifests: {},        // id -> manifest
        _states: {},           // id -> state string
        _timers: {},           // id -> [timerIds]
        _subscriptions: {},    // id -> [{eventName, callback}]
        _dependencies: {},     // id -> [depId]
        _dependents: {},       // id -> [depId] (reverse lookup)
        _registry: []          // ordered list of registered plugin IDs
    };
    
    // ===========================================================================
    // Manifest Validation
    // ===========================================================================
    
    DCE.PluginHost.validateManifest = function(manifest) {
        if (!manifest) return { valid: false, error: 'Manifest is null' };
        if (!manifest.id) return { valid: false, error: 'Plugin id is required' };
        if (!manifest.name) return { valid: false, error: 'Plugin name is required' };
        if (!manifest.version) return { valid: false, error: 'Plugin version is required' };
        return { valid: true };
    };
    
    // ===========================================================================
    // Dependency Resolution
    // ===========================================================================
    
    DCE.PluginHost.resolveDependencies = function(pluginId) {
        var manifest = DCE.PluginHost._manifests[pluginId];
        if (!manifest || !manifest.dependencies) return { resolved: true };
        
        var deps = manifest.dependencies;
        var missing = [];
        
        deps.forEach(function(depId) {
            if (!DCE.PluginHost._plugins[depId]) {
                missing.push(depId);
            }
        });
        
        if (missing.length > 0) {
            return { resolved: false, missing: missing };
        }
        
        // Build dependency graph
        DCE.PluginHost._dependencies[pluginId] = deps;
        deps.forEach(function(depId) {
            if (!DCE.PluginHost._dependents[depId]) {
                DCE.PluginHost._dependents[depId] = [];
            }
            DCE.PluginHost._dependents[depId].push(pluginId);
        });
        
        return { resolved: true };
    };
    
    // ===========================================================================
    // Plugin Registration
    // ===========================================================================
    
    DCE.PluginHost.register = function(pluginId, pluginObject, manifest) {
        if (DCE.PluginHost._plugins[pluginId]) {
            // Hot reload - destroy existing first
            DCE.PluginHost.destroy(pluginId);
        }
        
        DCE.PluginHost._plugins[pluginId] = pluginObject;
        DCE.PluginHost._manifests[pluginId] = manifest || { id: pluginId, name: pluginId, version: '1.0.0' };
        DCE.PluginHost._states[pluginId] = PLUGIN_STATES.REGISTERED;
        DCE.PluginHost._timers[pluginId] = [];
        DCE.PluginHost._subscriptions[pluginId] = [];
        
        if (DCE.PluginHost._registry.indexOf(pluginId) === -1) {
            DCE.PluginHost._registry.push(pluginId);
        }
        
        console.log('[DCE PluginHost] Registered:', pluginId, 'v' + (manifest ? manifest.version : '1.0.0'));
        return true;
    };
    
    // ===========================================================================
    // Plugin Initialization
    // ===========================================================================
    
    DCE.PluginHost.initialize = function(pluginId) {
        var plugin = DCE.PluginHost._plugins[pluginId];
        if (!plugin) {
            console.error('[DCE PluginHost] Cannot initialize unknown plugin:', pluginId);
            return false;
        }
        
        // Resolve dependencies first
        var depResult = DCE.PluginHost.resolveDependencies(pluginId);
        if (!depResult.resolved) {
            console.error('[DCE PluginHost] Missing dependencies for', pluginId, ':', depResult.missing);
            DCE.PluginHost._states[pluginId] = PLUGIN_STATES.ERROR;
            return false;
        }
        
        // Initialize dependent plugins first (topological order)
        var deps = DCE.PluginHost._dependencies[pluginId] || [];
        deps.forEach(function(depId) {
            if (DCE.PluginHost._states[depId] === PLUGIN_STATES.REGISTERED) {
                DCE.PluginHost.initialize(depId);
            }
        });
        
        // Call plugin Initialize hook
        if (plugin.Initialize) {
            try {
                plugin.Initialize();
                console.log('[DCE PluginHost] Initialized:', pluginId);
            } catch (e) {
                console.error('[DCE PluginHost] Init error', pluginId, ':', e);
                DCE.PluginHost._states[pluginId] = PLUGIN_STATES.ERROR;
                return false;
            }
        }
        
        DCE.PluginHost._states[pluginId] = PLUGIN_STATES.INITIALIZED;
        return true;
    };
    
    // ===========================================================================
    // Plugin Activation
    // ===========================================================================
    
    DCE.PluginHost.activate = function(pluginId) {
        var plugin = DCE.PluginHost._plugins[pluginId];
        if (!plugin) return false;
        
        if (DCE.PluginHost._states[pluginId] !== PLUGIN_STATES.INITIALIZED) {
            // Try to initialize first
            if (!DCE.PluginHost.initialize(pluginId)) return false;
        }
        
        if (plugin.Start) {
            try {
                plugin.Start();
                console.log('[DCE PluginHost] Activated:', pluginId);
            } catch (e) {
                console.error('[DCE PluginHost] Start error', pluginId, ':', e);
                DCE.PluginHost._states[pluginId] = PLUGIN_STATES.ERROR;
                return false;
            }
        }
        
        DCE.PluginHost._states[pluginId] = PLUGIN_STATES.ACTIVE;
        
        // Subscribe to EventBus events if plugin has onEvent
        if (plugin.onEvent) {
            DCE.PluginHost._subscribeEvents(pluginId, plugin);
        }
        
        return true;
    };
    
    // ===========================================================================
    // Plugin Suspension
    // ===========================================================================
    
    DCE.PluginHost.suspend = function(pluginId) {
        var plugin = DCE.PluginHost._plugins[pluginId];
        if (!plugin) return false;
        
        if (plugin.Suspend) {
            try {
                plugin.Suspend();
                console.log('[DCE PluginHost] Suspended:', pluginId);
            } catch (e) {
                console.error('[DCE PluginHost] Suspend error', pluginId, ':', e);
            }
        }
        
        // Unsubscribe EventBus events
        DCE.PluginHost._unsubscribeEvents(pluginId);
        
        // Clean up timers
        DCE.PluginHost._clearTimers(pluginId);
        
        DCE.PluginHost._states[pluginId] = PLUGIN_STATES.SUSPENDED;
        return true;
    };
    
    // ===========================================================================
    // Plugin Destruction
    // ===========================================================================
    
    DCE.PluginHost.destroy = function(pluginId) {
        var plugin = DCE.PluginHost._plugins[pluginId];
        if (!plugin) return false;
        
        // Suspend dependents first
        var dependents = DCE.PluginHost._dependents[pluginId] || [];
        dependents.forEach(function(depId) {
            if (DCE.PluginHost._states[depId] !== PLUGIN_STATES.DESTROYED) {
                DCE.PluginHost.destroy(depId);
            }
        });
        
        // Suspend if active
        if (DCE.PluginHost._states[pluginId] === PLUGIN_STATES.ACTIVE) {
            DCE.PluginHost.suspend(pluginId);
        }
        
        // Call Destroy hook
        if (plugin.Destroy) {
            try {
                plugin.Destroy();
                console.log('[DCE PluginHost] Destroyed:', pluginId);
            } catch (e) {
                console.error('[DCE PluginHost] Destroy error', pluginId, ':', e);
            }
        }
        
        DCE.PluginHost._clearTimers(pluginId);
        DCE.PluginHost._unsubscribeEvents(pluginId);
        DCE.PluginHost._states[pluginId] = PLUGIN_STATES.DESTROYED;
        
        return true;
    };
    
    // ===========================================================================
    // Hot Reload
    // ===========================================================================
    
    DCE.PluginHost.hotReload = function(pluginId, newPluginObject, newManifest) {
        console.log('[DCE PluginHost] Hot reloading:', pluginId);
        DCE.PluginHost.destroy(pluginId);
        DCE.PluginHost.register(pluginId, newPluginObject, newManifest);
        return true;
    };
    
    // ===========================================================================
    // EventBus Subscription Management
    // ===========================================================================
    
    DCE.PluginHost._subscribeEvents = function(pluginId, plugin) {
        if (!plugin.onEvent) return;
        
        DCE.NUI.post('dcc-eventbus:subscribe', {
            pluginId: pluginId,
            eventName: plugin.eventFilter || '*'
        }).catch(function() {});
        
        // Store subscription info
        DCE.PluginHost._subscriptions[pluginId].push({
            type: 'eventbus',
            filter: plugin.eventFilter || '*'
        });
    };
    
    DCE.PluginHost._unsubscribeEvents = function(pluginId) {
        DCE.PluginHost._subscriptions[pluginId] = [];
    };
    
    // ===========================================================================
    // Message Broadcast (runtime messaging between plugins)
    // ===========================================================================
    
    DCE.PluginHost.broadcast = function(message) {
        var ids = Object.keys(DCE.PluginHost._plugins);
        ids.forEach(function(id) {
            var plugin = DCE.PluginHost._plugins[id];
            if (plugin && plugin.onMessage) {
                try {
                    plugin.onMessage(message);
                } catch (e) {
                    console.error('[DCE PluginHost] Message error', id, ':', e);
                }
            }
        });
    };
    
    DCE.PluginHost.sendTo = function(pluginId, message) {
        var plugin = DCE.PluginHost._plugins[pluginId];
        if (plugin && plugin.onMessage) {
            try {
                plugin.onMessage(message);
            } catch (e) {
                console.error('[DCE PluginHost] SendTo error', pluginId, ':', e);
            }
        }
    };
    
    // ===========================================================================
    // Timer Management
    // ===========================================================================
    
    DCE.PluginHost._clearTimers = function(pluginId) {
        var timers = DCE.PluginHost._timers[pluginId] || [];
        timers.forEach(function(timerId) {
            clearInterval(timerId);
            clearTimeout(timerId);
        });
        DCE.PluginHost._timers[pluginId] = [];
    };
    
    DCE.PluginHost.setInterval = function(pluginId, callback, interval) {
        var timerId = setInterval(callback, interval);
        if (!DCE.PluginHost._timers[pluginId]) {
            DCE.PluginHost._timers[pluginId] = [];
        }
        DCE.PluginHost._timers[pluginId].push(timerId);
        return timerId;
    };
    
    DCE.PluginHost.setTimeout = function(pluginId, callback, delay) {
        var timerId = setTimeout(callback, delay);
        if (!DCE.PluginHost._timers[pluginId]) {
            DCE.PluginHost._timers[pluginId] = [];
        }
        DCE.PluginHost._timers[pluginId].push(timerId);
        return timerId;
    };
    
    // ===========================================================================
    // Query Methods
    // ===========================================================================
    
    DCE.PluginHost.getPlugin = function(pluginId) {
        return DCE.PluginHost._plugins[pluginId] || null;
    };
    
    DCE.PluginHost.getManifest = function(pluginId) {
        return DCE.PluginHost._manifests[pluginId] || null;
    };
    
    DCE.PluginHost.getState = function(pluginId) {
        return DCE.PluginHost._states[pluginId] || PLUGIN_STATES.DESTROYED;
    };
    
    DCE.PluginHost.listPlugins = function() {
        var result = [];
        DCE.PluginHost._registry.forEach(function(id) {
            if (DCE.PluginHost._plugins[id]) {
                result.push({
                    id: id,
                    name: DCE.PluginHost._manifests[id] ? DCE.PluginHost._manifests[id].name : id,
                    version: DCE.PluginHost._manifests[id] ? DCE.PluginHost._manifests[id].version : 'unknown',
                    state: DCE.PluginHost._states[id] || 'unknown'
                });
            }
        });
        return result;
    };
    
    // ===========================================================================
    // Mass Lifecycle Operations
    // ===========================================================================
    
    DCE.PluginHost.activateAll = function() {
        DCE.PluginHost._registry.forEach(function(id) {
            if (DCE.PluginHost._states[id] === PLUGIN_STATES.REGISTERED || 
                DCE.PluginHost._states[id] === PLUGIN_STATES.INITIALIZED) {
                DCE.PluginHost.activate(id);
            }
        });
    };
    
    DCE.PluginHost.suspendAll = function() {
        DCE.PluginHost._registry.slice().reverse().forEach(function(id) {
            if (DCE.PluginHost._states[id] === PLUGIN_STATES.ACTIVE) {
                DCE.PluginHost.suspend(id);
            }
        });
    };
    
    DCE.PluginHost.destroyAll = function() {
        DCE.PluginHost._registry.slice().reverse().forEach(function(id) {
            DCE.PluginHost.destroy(id);
        });
        DCE.PluginHost._plugins = {};
        DCE.PluginHost._manifests = {};
        DCE.PluginHost._states = {};
        DCE.PluginHost._timers = {};
        DCE.PluginHost._subscriptions = {};
        DCE.PluginHost._dependencies = {};
        DCE.PluginHost._dependents = {};
        DCE.PluginHost._registry = [];
    };
    
    console.log('[DCE PluginHost] Loaded (v2.0.0)');
})();