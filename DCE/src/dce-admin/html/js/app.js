/**
 * DCE Control Center - Main Application Entry Point
 * Initializes the Control Center framework
 */

(function() {
    'use strict';

    // Application initialization
    function init() {
        // Framework is initialized by framework.js
        // Window manager is initialized by window-manager.js
        // Modules are loaded on-demand via window creation

        // Handle event updates via EventBus forwarding
        DCE.MessageHandler.on('eventbus:emit', function(data) {
            DCE.EventHandler.handleEvent(data);
        });

        // Register module renderers
        DCE.Modules = DCE.Modules || {};
    }

    // Initialize when DOM ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

})();