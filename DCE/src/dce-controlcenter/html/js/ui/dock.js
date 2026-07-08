/**
 * DCE Control Center v2 - Dock Manager
 * Handles dock button interactions and plugin launching
 */

(function() {
    'use strict';

    window.DCE = window.DCE || {};

    DCE.Dock = {
        init: function() {
            const dock = document.getElementById('dock');
            if (!dock) return;

            dock.addEventListener('click', function(e) {
                const btn = e.target.closest('.dock-btn');
                if (!btn) return;

                const pluginId = btn.getAttribute('data-plugin');
                if (pluginId) {
                    DCE.Desktop.open();
                    DCE.Windows.open(pluginId);
                }
            });
        },

        setActive: function(pluginId) {
            document.querySelectorAll('.dock-btn').forEach(function(btn) {
                btn.classList.toggle('active', btn.getAttribute('data-plugin') === pluginId);
            });
        }
    };

    // Initialize when DOM ready
    if (document.readyState !== 'loading') {
        DCE.Dock.init();
    } else {
        document.addEventListener('DOMContentLoaded', function() {
            DCE.Dock.init();
        });
    }

})();