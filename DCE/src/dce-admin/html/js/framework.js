/**
 * DCE Control Center - JavaScript Framework
 * Base framework for message handling, notifications, and initialization
 */

(function() {
    'use strict';

    // DCE Namespace
    window.DCE = window.DCE || {};

    // ============================================================================
    // Message Handler - Receives messages from Lua
    // ============================================================================

    DCE.MessageHandler = {
        listeners: {},

        init: function() {
            window.addEventListener('message', function(event) {
                var data = event.data;
                if (!data || !data.action) return;

                var listeners = DCE.MessageHandler.listeners[data.action] || [];
                listeners.forEach(function(callback) {
                    callback(data);
                });
            });
        },

        on: function(action, callback) {
            if (!DCE.MessageHandler.listeners[action]) {
                DCE.MessageHandler.listeners[action] = [];
            }
            DCE.MessageHandler.listeners[action].push(callback);
        },

        off: function(action, callback) {
            if (!DCE.MessageHandler.listeners[action]) return;
            DCE.MessageHandler.listeners[action] = DCE.MessageHandler.listeners[action].filter(function(cb) {
                return cb !== callback;
            });
        }
    };

    // ============================================================================
    // NUI API - Sends requests to Lua
    // ============================================================================

    DCE.NUI = {
        post: async function(action, data) {
            data = data || {};
            var resp = await fetch('https://' + GetParentResourceName() + '/' + action, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            });
            return resp.json();
        }
    };

    // ============================================================================
    // Notifications System
    // ============================================================================

    DCE.Notifications = {
        container: null,

        init: function() {
            DCE.Notifications.container = document.getElementById('notifications');
        },

        show: function(message, type, duration) {
            type = type || 'info';
            duration = duration || 5000;
            if (!DCE.Notifications.container) return;

            var el = document.createElement('div');
            el.className = 'notification ' + type;
            el.textContent = message;

            DCE.Notifications.container.appendChild(el);

            setTimeout(function() {
                el.remove();
            }, duration);
        },

        success: function(msg) { DCE.Notifications.show(msg, 'success'); },
        error: function(msg) { DCE.Notifications.show(msg, 'error'); },
        warning: function(msg) { DCE.Notifications.show(msg, 'warning'); },
        info: function(msg) { DCE.Notifications.show(msg, 'info'); }
    };

    // ============================================================================
    // Desktop Environment
    // ============================================================================

    DCE.Desktop = {
        isOpen: false,

        show: function() {
            document.body.classList.add('cc-open');
            DCE.Desktop.isOpen = true;
        },

        hide: function() {
            document.body.classList.remove('cc-open');
            DCE.Desktop.isOpen = false;
        }
    };

    // ============================================================================
    // Event Bus Client
    // ============================================================================

    DCE.EventHandler = {
        subscriptions: {},

        subscribe: function(eventName, callback) {
            if (!DCE.EventHandler.subscriptions[eventName]) {
                DCE.EventHandler.subscriptions[eventName] = [];
            }
            DCE.EventHandler.subscriptions[eventName].push(callback);
            DCE.NUI.post('subscribe', { eventName: eventName });
        },

        handleEvent: function(data) {
            var listeners = DCE.EventHandler.subscriptions[data.eventName] || [];
            listeners.forEach(function(callback) {
                callback(data.payload);
            });
        }
    };

    // ============================================================================
    // Initialization
    // ============================================================================

    function onDOMContentLoaded() {
        DCE.MessageHandler.init();
        DCE.Notifications.init();

        // Wait for explicit open message - do NOT auto-initialize
        DCE.MessageHandler.on('open', function() {
            DCE.Desktop.show();
            DCE.Notifications.info('Control Center opened');
        });

        DCE.MessageHandler.on('close', function() {
            DCE.Desktop.hide();
            if (DCE.Windows) {
                DCE.Windows.closeAll();
            }
        });

        // Ready state - hidden by default
        document.body.classList.add('cc-ready');
        
        // Notify Lua that NUI is ready
        DCE.NUI.post('nuiReady', {});
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', onDOMContentLoaded);
    } else {
        onDOMContentLoaded();
    }

})();