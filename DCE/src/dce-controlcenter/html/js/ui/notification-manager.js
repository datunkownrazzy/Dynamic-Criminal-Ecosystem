/**
 * DCE Control Center v2 - Notification Manager
 * 
 * Manages in-app notifications (toasts, alerts, banners).
 * Lazy loaded by ApplicationManager on Boot.
 * Never exists until /dce command.
 */

(function() {
    'use strict';
    
    window.DCE = window.DCE || {};
    
    var NOTIFICATION_TYPES = {
        INFO: 'info',
        SUCCESS: 'success',
        WARNING: 'warning',
        ERROR: 'error'
    };
    
    var NOTIFICATION_DURATIONS = {
        INFO: 4000,
        SUCCESS: 3000,
        WARNING: 5000,
        ERROR: 8000
    };
    
    DCE.Notifications = {
        _container: null,
        _counter: 0,
        
        /**
         * Initialize notification system.
         */
        init: function() {
            console.log('[DCE Notifications] Initializing...');
            
            var container = document.getElementById('notifications');
            if (!container) {
                // Create container if it doesn't exist
                container = document.createElement('div');
                container.id = 'notifications';
                container.className = 'notifications';
                document.body.appendChild(container);
            }
            
            DCE.Notifications._container = container;
            console.log('[DCE Notifications] Initialized');
            return true;
        },
        
        /**
         * Show a notification.
         */
        show: function(message, type, duration) {
            type = type || NOTIFICATION_TYPES.INFO;
            duration = duration || NOTIFICATION_DURATIONS[type] || 4000;
            
            DCE.Notifications._counter++;
            var id = 'notification-' + DCE.Notifications._counter;
            
            // Create notification element
            var notification = document.createElement('div');
            notification.id = id;
            notification.className = 'notification notification-' + type;
            notification.innerHTML = '<span class="notification-message">' + message + '</span>';
            
            // Add to container
            var container = DCE.Notifications._container;
            if (!container) {
                DCE.Notifications.init();
                container = DCE.Notifications._container;
            }
            container.appendChild(notification);
            
            // Animate in
            requestAnimationFrame(function() {
                notification.classList.add('notification-visible');
            });
            
            // Auto-remove after duration
            setTimeout(function() {
                DCE.Notifications.dismiss(id);
            }, duration);
            
            return id;
        },
        
        /**
         * Dismiss a notification.
         */
        dismiss: function(id) {
            var notification = document.getElementById(id);
            if (!notification) return;
            
            notification.classList.remove('notification-visible');
            notification.classList.add('notification-hiding');
            
            setTimeout(function() {
                if (notification.parentNode) {
                    notification.parentNode.removeChild(notification);
                }
            }, 300);
        },
        
        /**
         * Clear all notifications.
         */
        clearAll: function() {
            var container = DCE.Notifications._container;
            if (!container) return;
            
            while (container.firstChild) {
                container.removeChild(container.firstChild);
            }
        },
        
        /**
         * Show info notification.
         */
        info: function(message) {
            return DCE.Notifications.show(message, NOTIFICATION_TYPES.INFO);
        },
        
        /**
         * Show success notification.
         */
        success: function(message) {
            return DCE.Notifications.show(message, NOTIFICATION_TYPES.SUCCESS);
        },
        
        /**
         * Show warning notification.
         */
        warning: function(message) {
            return DCE.Notifications.show(message, NOTIFICATION_TYPES.WARNING);
        },
        
        /**
         * Show error notification.
         */
        error: function(message) {
            return DCE.Notifications.show(message, NOTIFICATION_TYPES.ERROR);
        }
    };
    
    console.log('[DCE Notifications] Loaded');
    
})();