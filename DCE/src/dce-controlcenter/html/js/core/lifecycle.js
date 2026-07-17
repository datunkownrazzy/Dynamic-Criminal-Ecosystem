/**
 * DCE Control Center v2 - Lifecycle (JavaScript)
 * 
 * Provides DCE.Lifecycle namespace for state management and resource tracking.
 * Application lifecycle (Boot/Activate/Shutdown) is handled by application-manager.js
 * 
 * States match the Lua side:
 * - unloaded: Initial state after browser loads
 * - ready: Application initialized, waiting for session
 * - active: UI visible, focus granted
 * 
 * CRITICAL: Focus is managed ONLY by Lua FocusManager.
 * JS never calls SetNuiFocus directly.
 */

(function() {
    'use strict';

    // DCE Namespace
    window.DCE = window.DCE || {};

    // Lifecycle states (sync with Lua)
    const STATES = {
        UNLOADED: 'unloaded',
        READY: 'ready',
        ACTIVE: 'active'
    };

    // Internal state
    DCE.Lifecycle = {
        state: STATES.UNLOADED,
        isOpen: false,
        
        // Track all runtime resources for cleanup
        _timers: new Set(),
        _eventListeners: new Map(),
        _animationFrames: new Set(),
        _observers: new Set()
    };

    // ===========================================================================
    // State Management
    // ===========================================================================

    DCE.Lifecycle.setState = function(newState) {
        if (!STATES[newState]) {
            console.error('[DCE Lifecycle] Invalid state:', newState);
            return false;
        }

        var oldState = DCE.Lifecycle.state;
        DCE.Lifecycle.state = newState;
        DCE.Lifecycle.isOpen = (newState === STATES.ACTIVE);

        // Update body classes for CSS
        document.body.className = 'cc-' + newState;

        console.log('[DCE Lifecycle] State:', oldState, '→', newState);
        return true;
    };

    DCE.Lifecycle.getState = function() {
        return DCE.Lifecycle.state;
    };

    DCE.Lifecycle.isReady = function() {
        return DCE.Lifecycle.state === STATES.READY;
    };

    DCE.Lifecycle.isOpenState = function() {
        return DCE.Lifecycle.state === STATES.ACTIVE;
    };

    // ===========================================================================
    // Resource Tracking
    // ===========================================================================

    DCE.Lifecycle.trackTimer = function(timerId) {
        DCE.Lifecycle._timers.add(timerId);
    };

    DCE.Lifecycle.untrackTimer = function(timerId) {
        DCE.Lifecycle._timers.delete(timerId);
    };

    DCE.Lifecycle.setInterval = function(callback, interval) {
        var timerId = setInterval(callback, interval);
        DCE.Lifecycle.trackTimer(timerId);
        return timerId;
    };

    DCE.Lifecycle.setTimeout = function(callback, delay) {
        var timerId = setTimeout(callback, delay);
        DCE.Lifecycle.trackTimer(timerId);
        return timerId;
    };

    DCE.Lifecycle.trackEventListener = function(element, event, handler) {
        var key = (typeof element) + ':' + event;
        var handlers = DCE.Lifecycle._eventListeners.get(key) || [];
        handlers.push({ element: element, event: event, handler: handler });
        DCE.Lifecycle._eventListeners.set(key, handlers);
    };

    DCE.Lifecycle.requestAnimationFrame = function(callback) {
        var frameId = requestAnimationFrame(function() {
            DCE.Lifecycle._animationFrames.delete(frameId);
            callback();
        });
        DCE.Lifecycle._animationFrames.add(frameId);
        return frameId;
    };

    // ===========================================================================
    // Message Handler for session lifecycle
    // ===========================================================================

    window.addEventListener('message', function(event) {
        var data = event.data;
        if (!data || !data.action) return;

        console.log('[DCE Lifecycle] Message:', data.action);

        // Handle lifecycle messages from Lua ApplicationManager
        if (data.action === 'lifecycle:cleanup' || data.action === 'lifecycle:reset') {
            DCE.Lifecycle.cleanup();
            DCE.Lifecycle.setState(STATES.READY);
        }
    });

    // ===========================================================================
    // Cleanup
    // ===========================================================================

    DCE.Lifecycle.cleanup = function() {
        console.log('[DCE Lifecycle] Cleaning up all resources...');

        // Clear all timers
        DCE.Lifecycle._timers.forEach(function(timerId) {
            clearInterval(timerId);
            clearTimeout(timerId);
        });
        DCE.Lifecycle._timers.clear();

        // Cancel all animation frames
        DCE.Lifecycle._animationFrames.forEach(function(frameId) {
            cancelAnimationFrame(frameId);
        });
        DCE.Lifecycle._animationFrames.clear();

        // Disconnect all observers
        DCE.Lifecycle._observers.forEach(function(observer) {
            if (observer.disconnect) {
                observer.disconnect();
            }
        });
        DCE.Lifecycle._observers.clear();

        // Remove all event listeners
        DCE.Lifecycle._eventListeners.forEach(function(handlers) {
            handlers.forEach(function(h) {
                if (h && h.element && h.event && h.handler) {
                    h.element.removeEventListener(h.event, h.handler);
                }
            });
        });
        DCE.Lifecycle._eventListeners.clear();

        console.log('[DCE Lifecycle] Cleanup complete');
    };

    console.log('[DCE Lifecycle] Module loaded (v2.0.0)');

})();
