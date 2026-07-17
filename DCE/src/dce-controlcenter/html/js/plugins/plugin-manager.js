/**
 * DCE Control Center v2 - Plugin Manager (Authoritative)
 * Manages plugin lifecycle: Initialize/Start/Stop/Destroy
 * Plugins are passive - they respond to events, never manage focus
 */

(function() {
    'use strict';
    
    window.DCE = window.DCE || {};
    
    const pluginStates = {};
    
    DCE.Plugins = DCE.Plugins || {};
    DCE.Plugins.Manager = DCE.Plugins.Manager || {
        create: function() {
            console.log('[DCE Plugins] Manager created');
            return true;
        },
        
        loadPlugins: function() {
            console.log('[DCE Plugins] Loading plugins...');
            const ids = Object.keys(DCE.Plugins).filter(function(k) { return !k.startsWith('_') && k !== 'Manager'; });
            
            // Initialize phase
            ids.forEach(function(id) {
                const p = DCE.Plugins[id];
                if (p && p.Initialize) {
                    try {
                        p.Initialize();
                        pluginStates[id] = 'initialized';
                        console.log('[DCE Plugins] Initialized:', id);
                    } catch(e) {
                        console.error('[DCE Plugins] Init error', id, ':', e);
                        pluginStates[id] = 'error';
                    }
                } else {
                    pluginStates[id] = 'ready';
                }
            });
            
            // Start phase
            ids.forEach(function(id) {
                const p = DCE.Plugins[id];
                if (p && p.Start && pluginStates[id] === 'initialized') {
                    try {
                        p.Start();
                        pluginStates[id] = 'started';
                        console.log('[DCE Plugins] Started:', id);
                    } catch(e) {
                        console.error('[DCE Plugins] Start error', id, ':', e);
                    }
                }
            });
        },
        
        unloadPlugins: function() {
            const ids = Object.keys(DCE.Plugins).filter(function(k) { return !k.startsWith('_') && k !== 'Manager'; });
            ids.forEach(function(id) {
                const p = DCE.Plugins[id];
                if (p && p.Stop && pluginStates[id] === 'started') {
                    try { p.Stop(); } catch(e) {}
                }
                if (p && p.Destroy) {
                    try { p.Destroy(); } catch(e) {}
                }
                pluginStates[id] = null;
            });
        },
        
        discoverPlugins: function() {
            const ids = Object.keys(DCE.Plugins).filter(function(k) { return !k.startsWith('_') && k !== 'Manager'; });
            console.log('[DCE Plugins] Discovered plugins:', ids);
            return ids;
        },
        
        getState: function(id) { return pluginStates[id] || 'unknown'; },
        
        listPlugins: function() {
            return Object.keys(DCE.Plugins).filter(function(k) { return !k.startsWith('_') && k !== 'Manager'; }).map(function(id) {
                const p = DCE.Plugins[id];
                return {
                    id: id,
                    name: (p && p.displayName) || p.name || id,
                    icon: (p && p.icon) || '🔧',
                    state: pluginStates[id] || 'registered'
                };
            });
        }
    };
    
    console.log('[DCE Plugins] Manager loaded');
})();