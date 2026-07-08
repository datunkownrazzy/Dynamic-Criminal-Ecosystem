/**
 * DCE Control Center v2 - Notifications System
 * Toast-style notifications that appear in the top-right corner
 */

(function() {
    'use strict';

    window.DCE = window.DCE || {};

    DCE.Notifications = {
        container: null,

        init: function() {
            this.container = document.getElementById('notifications');
        },

        show: function(message, type, duration) {
            if (!this.container) this.init();
            if (!this.container) return;

            type = type || 'info';
            duration = duration || 5000;

            const el = document.createElement('div');
            el.className = 'notification ' + type;
            el.textContent = message;

            this.container.appendChild(el);

            setTimeout(function() {
                el.classList.add('fade-out');
                setTimeout(function() {
                    if (el.parentNode) {
                        el.remove();
                    }
                }, 300);
            }, duration);
        },

        success: function(msg) { this.show(msg, 'success'); },
        error: function(msg) { this.show(msg, 'error'); },
        warning: function(msg) { this.show(msg, 'warning'); },
        info: function(msg) { this.show(msg, 'info'); }
    };

    // Add fade-out style
    const style = document.createElement('style');
    style.textContent = '.fade-out { opacity: 0; transition: opacity 0.3s ease; }';
    document.head.appendChild(style);

})();