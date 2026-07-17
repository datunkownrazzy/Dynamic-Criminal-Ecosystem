/**
 * DCE Control Center v2 - Runtime Controller
 * 
 * Manages runtime event subscriptions, heartbeats, and periodic tasks.
 * Started by ApplicationManager.Activate(), stopped by Shutdown().
 * Lazy loaded - never exists until /dce command.
 */

(function() {
    'use strict';
    
    window.DCE = window.DCE || {};
    
    DCE.Runtime = {
        _active: false,
        _heartbeatInterval: null,
        _subscribers: new Map(),
        _heartbeatRate: 5000,
        
        start: function() {
            if (DCE.Runtime._active) return;
            DCE.Runtime._active = true;
            
            console.log('[DCE Runtime] Starting runtime event subscriptions...');
            
            DCE.Runtime._heartbeatInterval = setInterval(function() {
                DCE.Runtime._tick();
            }, DCE.Runtime._heartbeatRate);
            
            window.addEventListener('message', DCE.Runtime._handleMessage);
            
            console.log('[DCE Runtime] Runtime started');
        },
        
        stop: function() {
            if (!DCE.Runtime._active) return;
            DCE.Runtime._active = false;
            
            console.log('[DCE Runtime] Stopping runtime event subscriptions...');
            
            if (DCE.Runtime._heartbeatInterval) {
                clearInterval(DCE.Runtime._heartbeatInterval);
                DCE.Runtime._heartbeatInterval = null;
            }
            
            window.removeEventListener('message', DCE.Runtime._handleMessage);
            DCE.Runtime._subscribers.clear();
            
            console.log('[DCE Runtime] Runtime stopped');
        },
        
        on: function(eventType, callback) {
            if (!DCE.Runtime._subscribers.has(eventType)) {
                DCE.Runtime._subscribers.set(eventType, []);
            }
            DCE.Runtime._subscribers.get(eventType).push(callback);
        },
        
        off: function(eventType, callback) {
            var handlers = DCE.Runtime._subscribers.get(eventType);
            if (!handlers) return;
            var index = handlers.indexOf(callback);
            if (index !== -1) {
                handlers.splice(index, 1);
            }
        },
        
        _handleMessage: function(event) {
            var data = event.data;
            if (!data || !data.action) return;
            var handlers = DCE.Runtime._subscribers.get(data.action);
            if (handlers) {
                handlers.forEach(function(handler) {
                    try {
                        handler(data.data || {});
                    } catch (err) {
                        console.error('[DCE Runtime] Subscriber error:', err);
                    }
                });
            }
        },
        
        _tick: function() {
            DCE.NUI.post('runtime:heartbeat', {
                state: DCE.Application ? DCE.Application.state : 'unknown',
                sessionId: DCE.Application ? DCE.Application.sessionId : null,
                timestamp: Date.now()
            }).catch(function() {});
        },
        
        isActive: function() {
            return DCE.Runtime._active;
        }
    };
    
    console.log('[DCE Runtime] Loaded');
    
})();