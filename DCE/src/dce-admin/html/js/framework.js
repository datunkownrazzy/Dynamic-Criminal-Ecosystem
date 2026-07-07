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
            try {
                var resp = await fetch('https://' + GetParentResourceName() + '/' + action, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(data)
                });
                
                if (!resp.ok) {
                    throw new Error('HTTP error: ' + resp.status + ' ' + resp.statusText);
                }
                
                var result = await resp.json();
                return result;
            } catch (err) {
                console.error('DCE.NUI.post error for ' + action + ':', err);
                if (DCE.Notifications) {
                    DCE.Notifications.error('NUI request failed: ' + action);
                }
                return null;
            }
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
    // UI State Manager (Centralized)
    // ============================================================================

    DCE.UI = {
        state: {
            isOpen: false,
            hasFocus: false,
            currentWorkspace: null,
            currentWindow: null,
            activeTab: null,
            selectedOrganization: null,
            selectedRegion: null,
        },

        // Set state and sync with DOM
        setState: function(key, value) {
            this.state[key] = value;
            if (key === 'isOpen') {
                if (value) {
                    document.body.classList.add('cc-open');
                } else {
                    document.body.classList.remove('cc-open');
                }
            }
        },

        // Get state value
        getState: function(key) {
            return this.state[key];
        },

        // Toggle open state
        toggle: function() {
            this.setState('isOpen', !this.state.isOpen);
            this.setState('hasFocus', this.state.isOpen);
            return this.state.isOpen;
        },

        open: function() {
            this.setState('isOpen', true);
            this.setState('hasFocus', true);
            DCE.Notifications.info('Control Center opened');
        },

        close: function() {
            this.setState('isOpen', false);
            this.setState('hasFocus', false);
            if (DCE.Windows) {
                DCE.Windows.closeAll();
            }
        }
    };

    // ============================================================================
    // Desktop Environment
    // ============================================================================

    DCE.Desktop = {
        isOpen: false,

        show: function() {
            DCE.UI.open();
            DCE.Desktop.isOpen = DCE.UI.getState('isOpen');
        },

        hide: function() {
            DCE.UI.close();
            DCE.Desktop.isOpen = DCE.UI.getState('isOpen');
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
    // Keyboard Event Handling
    // ============================================================================

    document.addEventListener('keydown', function(e) {
        // ESC key closes Control Center
        if (e.key === 'Escape' || e.key === 'Esc') {
            DCE.NUI.post('keydown', { key: e.key });
            e.preventDefault();
        }
    });

    // ============================================================================
    // Initialization
    // ============================================================================

    function onDOMContentLoaded() {
        DCE.MessageHandler.init();
        DCE.Notifications.init();

        // Handle open/close messages from Lua
        // IMPORTANT: Do NOT auto-open on ready - Control Center must be explicitly opened
        DCE.MessageHandler.on('open', function() {
            DCE.Desktop.show();
        });

        DCE.MessageHandler.on('close', function() {
            DCE.Desktop.hide();
            if (DCE.Windows) {
                DCE.Windows.closeAll();
            }
        });

        // Initialize modules namespace
        DCE.Modules = DCE.Modules || {};

        // Notify Lua that NUI is ready (but stay hidden)
        DCE.NUI.post('nuiReady', {});
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', onDOMContentLoaded);
    } else {
        onDOMContentLoaded();
    }

})();