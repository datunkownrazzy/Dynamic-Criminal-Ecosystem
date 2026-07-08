/**
 * DCE Control Center v2 - Breadcrumb Navigation
 */

(function() {
    'use strict';

    window.DCE = window.DCE || {};

    DCE.Breadcrumb = {
        init: function() {
            // Breadcrumb is rendered in status bar
        },

        setPath: function(parts) {
            const el = document.getElementById('breadcrumb');
            if (!el) return;

            el.innerHTML = parts.map(function(part, i) {
                if (i === parts.length - 1) {
                    return '<span class="breadcrumb-current">' + part + '</span>';
                }
                return '<span class="breadcrumb-item">' + part + '</span>';
            }).join(' / ');
        },

        clear: function() {
            const el = document.getElementById('breadcrumb');
            if (el) el.innerHTML = '';
        }
    };

})();