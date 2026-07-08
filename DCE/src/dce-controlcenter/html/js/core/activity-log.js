/**
 * DCE Control Center v2 - Activity Log
 * Recent actions and system events log
 */

(function() {
    'use strict';

    window.DCE = window.DCE || {};

    DCE.ActivityLog = {
        entries: [],

        log: function(action, details) {
            this.entries.push({
                timestamp: Date.now(),
                action: action,
                details: details
            });
        },

        getEntries: function(limit) {
            limit = limit || 50;
            return this.entries.slice(-limit);
        },

        clear: function() {
            this.entries = [];
        }
    };

})();