/**
 * DCE Control Center v2 - Dock Manager
 * Dynamically builds dock from plugin manifests
 * Per ADR-0024: No hardcoded UI - all from manifests
 */

(function() {
    'use strict';
    
    window.DCE = window.DCE || {};
    
    DCE.Dock = {
        // Dock button registry
        _buttons: new Map(),
        _initialized: false,
        
        // Initialize dock with plugins (called on application boot)
        init: function() {
            const dock = document.getElementById('dock');
            if (!dock) return;
            
            // Add click delegation for dock buttons
            dock.addEventListener('click', DCE.Dock.handleDockClick);
            DCE.Dock._initialized = true;
        },
        
        // Refresh dock buttons from plugin registry
        _refreshDock: function() {
            const dock = document.getElementById('dock');
            if (!dock) return;
            
            try {
                // Get local plugins from DCE.Plugins
                const plugins = DCE.Dock._getLocalPlugins();
                
                // Clear existing buttons (keep structure, just buttons)
                const content = dock.querySelector('.dock-content');
                if (!content) return;
                
                // Add separator if not exists
                let separator = content.querySelector('.dock-separator');
                if (!separator) {
                    separator = document.createElement('div');
                    separator.className = 'dock-separator';
                    content.appendChild(separator);
                }
                
                // Remove all existing plugin buttons
                const existingButtons = content.querySelectorAll('[data-plugin]');
                existingButtons.forEach(function(btn) {
                    btn.remove();
                });
                
                // Add buttons for each plugin (before separator)
                const fragment = document.createDocumentFragment();
                plugins.forEach(function(plugin) {
                    const btn = document.createElement('button');
                    btn.className = 'dock-btn';
                    btn.setAttribute('data-plugin', plugin.id);
                    btn.title = plugin.displayName || plugin.name;
                    btn.textContent = plugin.icon || '🔧';
                    fragment.appendChild(btn);
                });
                
                // Insert buttons before separator
                if (separator.parentNode) {
                    separator.parentNode.insertBefore(fragment, separator);
                }
                
            } catch (err) {
                console.error('[DCE Dock] Failed to load plugins:', err);
            }
        },
        
        // Get local plugins from DCE.Plugins (no server callback needed)
        _getLocalPlugins: function() {
            var plugins = [];
            var pluginIds = Object.keys(DCE.Plugins || {});
            pluginIds.forEach(function(pluginId) {
                // Skip internal properties (Manager, etc.)
                if (pluginId.startsWith('_')) return;
                
                var plugin = DCE.Plugins[pluginId];
                if (plugin) {
                    plugins.push({
                        id: pluginId,
                        displayName: plugin.displayName || plugin.name || pluginId,
                        icon: plugin.icon || '🔧'
                    });
                }
            });
            return plugins;
        },
        
        // Handle click events (delegated)
        handleDockClick: function(e) {
            const btn = e.target.closest('.dock-btn');
            if (!btn) return;
            
            const pluginId = btn.getAttribute('data-plugin');
            if (pluginId) {
                // Open window - DCE.Application will manage state
                if (DCE.Windows && DCE.Windows.openWindow) {
                    DCE.Windows.openWindow(pluginId);
                } else {
                    console.warn('[DCE Dock] Windows not initialized');
                }
            }
        },
        
        // Set active button
        setActive: function(pluginId) {
            document.querySelectorAll('.dock-btn').forEach(function(btn) {
                btn.classList.toggle('active', btn.getAttribute('data-plugin') === pluginId);
            });
        }
    };
    
})();