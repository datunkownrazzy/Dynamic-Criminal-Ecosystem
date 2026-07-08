/**
 * DCE Control Center v2 - Application Entry Point
 * Initializes all subsystems and plugins
 */

(function() {
    'use strict';

    window.DCE = window.DCE || {};

    // Plugin registry - plugins register themselves here
    DCE.Plugins = DCE.Plugins || {};

    // ===========================================================================
    // Application Initialization
    // ===========================================================================

    DCE.App = {
        init: function() {
            console.log('[DCE CC] Initializing Control Center v2...');

            // Initialize UI components
            if (DCE.Dock) DCE.Dock.init();
            if (DCE.Notifications) DCE.Notifications.init();
            if (DCE.Breadcrumb) DCE.Breadcrumb.init();

            // Load Config from server (if available)
            this.loadConfig();

            // Register built-in plugins
            this.registerPlugins();

            console.log('[DCE CC] Control Center v2 ready');
        },

        loadConfig: async function() {
            try {
                const config = await DCE.NUI.post('dcc-config:get');
                if (config && config.CC) {
                    window.Config = window.Config || {};
                    window.Config.CC = config.CC;
                }
            } catch (e) {
                console.error('[DCE CC] Failed to load config:', e);
            }
        },

        registerPlugins: function() {
            // Plugins are self-registering via the IIFE pattern
            // This space reserved for future plugin discovery
        }
    };

    // ===========================================================================
    // Timestamp Updater
    // ===========================================================================

    function updateTimestamp() {
        const el = document.getElementById('status-timestamp');
        if (el) {
            const now = new Date();
            el.textContent = now.toLocaleTimeString();
        }
    }

    setInterval(updateTimestamp, 1000);
    updateTimestamp();

    // DOM ready check
    if (document.readyState !== 'loading') {
        DCE.App.init();
    } else {
        document.addEventListener('DOMContentLoaded', function() {
            DCE.App.init();
        });
    }

    // ===========================================================================
    // Keyboard Shortcuts
    // ===========================================================================

    // ESC to close - handled by parent document when focus is active
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape' && DCE.Desktop && DCE.Desktop.isOpen) {
            DCE.Desktop.close();
        }
    });

})();