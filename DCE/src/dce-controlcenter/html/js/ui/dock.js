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
            if (DCE.Dock._initialized) return;
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
                
                content.replaceChildren();
                const fragment = document.createDocumentFragment();
                var operationsLabel = document.createElement('div');
                operationsLabel.className = 'dock-section-label';
                operationsLabel.textContent = 'Operations';
                fragment.appendChild(operationsLabel);
                var homeButton = document.createElement('button');
                homeButton.className = 'dock-btn';
                homeButton.setAttribute('data-destination', 'home');
                homeButton.textContent = 'Home';
                fragment.appendChild(homeButton);

                plugins.forEach(function(plugin) {
                    var destination = DCE.Dock._navigationDestination(plugin.id);
                    if (!destination) return;
                    const btn = document.createElement('button');
                    btn.className = 'dock-btn';
                    btn.setAttribute('data-destination', plugin.id);
                    btn.title = plugin.displayName || plugin.name;
                    btn.textContent = destination;
                    fragment.appendChild(btn);
                });
                var administrationLabel = document.createElement('div');
                administrationLabel.className = 'dock-section-label';
                administrationLabel.textContent = 'Administration';
                fragment.appendChild(administrationLabel);
                [
                    ['configuration', 'Configuration'],
                    ['integrations', 'Integrations'],
                    ['runtime', 'Runtime'],
                    ['diagnostics', 'Diagnostics']
                ].forEach(function(item) {
                    var btn = document.createElement('button');
                    btn.className = 'dock-btn';
                    btn.setAttribute('data-destination', item[0]);
                    btn.textContent = item[1];
                    fragment.appendChild(btn);
                });
                content.appendChild(fragment);
                
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

        _navigationDestination: function(pluginId) {
            var destinations = {
                'world-manager': 'World',
                'organization-manager': 'Organizations',
                'scenario-manager': 'Scenarios',
                'dispatch-manager': 'Dispatch',
                'evidence-manager': 'Evidence',
                'economy-manager': 'Economy',
                'ai-manager': 'Intelligence'
            };
            return destinations[pluginId] || null;
        },
        
        // Handle click events (delegated)
        handleDockClick: function(e) {
            const btn = e.target.closest('.dock-btn');
            if (!btn) return;

            const destination = btn.getAttribute('data-destination');
            if (destination && DCE.Desktop && DCE.Desktop.navigate) {
                DCE.Desktop.navigate(destination);
            }
        },
        
        // Set active button
        setActive: function(pluginId) {
            document.querySelectorAll('.dock-btn').forEach(function(btn) {
                btn.classList.toggle('active', btn.getAttribute('data-destination') === pluginId);
            });
        }
    };
    
})();