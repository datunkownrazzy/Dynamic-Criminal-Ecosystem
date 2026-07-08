/**
 * DCE Control Center v2 - NUI Lifecycle Manager
 * 
 * CRITICAL: This module manages the entire NUI lifecycle.
 * - UI is hidden by default (opacity: 0, pointer-events: none)
 * - UI becomes visible only when explicitly opened via message
 * - Every open has exactly one matching close
 * - Every focus acquisition has exactly one release
 * - No auto-open, no auto-focus, no gray overlay
 */

(function() {
    'use strict';

    // DCE Namespace
    window.DCE = window.DCE || {};

    // Lifecycle states
    const STATE_CLOSED = 'closed';
    const STATE_OPENING = 'opening';
    const STATE_OPEN = 'open';
    const STATE_CLOSING = 'closing';

    // Internal state
    let lifecycleState = STATE_CLOSED;
    let pendingFocusRelease = false;

    // ===========================================================================
    // Diagnostics
    // ===========================================================================

    const DCE_CALENDAR = {
        diagLog: function(message) {
            if (!window.Config || !window.Config.CC || !window.Config.CC.NUI || !window.Config.CC.NUI.DebugMode) {
                return;
            }
            console.log('[DCE Lifecycle] ' + new Date().toISOString() + ' - ' + message);
        }
    };

    // ===========================================================================
    // NUI Message Handler
    // ===========================================================================

    DCE.NUI = {
        post: async function(action, data) {
            data = data || {};
            try {
                const resp = await fetch('https://' + GetParentResourceName() + '/' + action, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(data)
                });
                
                if (!resp.ok) {
                    throw new Error('HTTP error: ' + resp.status);
                }
                
                return await resp.json();
            } catch (err) {
                console.error('NUI post error:', err);
                DCE.Notifications && DCE.Notifications.error('Connection error: ' + action);
                return null;
            }
        }
    };

    // ===========================================================================
    // Desktop Lifecycle
    // ===========================================================================

    DCE.Desktop = {
        isOpen: false,
        state: lifecycleState,

        setState: function(newState) {
            lifecycleState = newState;
            DCE.Desktop.state = newState;
            
            // Update body classes
            document.body.classList.remove('cc-closed', 'cc-opening', 'cc-open', 'cc-closing');
            document.body.classList.add('cc-' + newState);
            
            DCE_CALENDAR.diagLog('State changed to: ' + newState);
        },

        open: function() {
            if (lifecycleState === STATE_OPEN) {
                DCE_CALENDAR.diagLog('Already open');
                return;
            }
            
            DCE_CALENDAR.diagLog('Opening desktop');
            DCE.Desktop.setState(STATE_OPENING);
            
            // Notify Lua that NUI is ready for focus
            DCE.NUI.post('dce-cc:nui:ready');
            
            // Small delay to ensure DOM updates before showing
            requestAnimationFrame(() => {
                DCE.Desktop.setState(STATE_OPEN);
                DCE.Desktop.isOpen = true;
                DCE.Notifications && DCE.Notifications.info('Control Center v2 opened');
            });
        },

        close: function() {
            if (lifecycleState === STATE_CLOSED) {
                DCE_CALENDAR.diagLog('Already closed');
                return;
            }
            
            DCE_CALENDAR.diagLog('Closing desktop');
            DCE.Desktop.setState(STATE_CLOSING);
            
            // Close all windows first
            if (DCE.Windows) {
                DCE.Windows.closeAll();
            }
            
            // Notify Lua that we've released focus
            DCE.NUI.post('dce-cc:nui:focusReleased');
            
            // Small delay before hiding
            requestAnimationFrame(() => {
                DCE.Desktop.setState(STATE_CLOSED);
                DCE.Desktop.isOpen = false;
            });
        },

        toggle: function() {
            if (lifecycleState === STATE_OPEN) {
                DCE.Desktop.close();
            } else {
                DCE.Desktop.open();
            }
        }
    };

    // ===========================================================================
    // Window Manager Interface
    // ===========================================================================

    DCE.Windows = DCE.Windows || {
        open: function(pluginId, options) {
            if (!DCE.Desktop.isOpen) {
                DCE.Desktop.open();
            }
            
            // Delegate to actual window manager
            if (window.DCEWindowManager) {
                DCEWindowManager.createWindow(pluginId, options);
            }
        },

        closeAll: function() {
            const container = document.getElementById('window-container');
            if (container) {
                container.innerHTML = '';
            }
        }
    };

    // ===========================================================================
    // Message Handler
    // ===========================================================================

    window.addEventListener('message', function(event) {
        const data = event.data;
        if (!data || !data.action) return;

        DCE_CALENDAR.diagLog('Received message: ' + data.action);

        switch (data.action) {
            case 'lifecycle:open':
                DCE.Desktop.open();
                break;
                
            case 'lifecycle:close':
                DCE.Desktop.close();
                break;
                
            case 'lifecycle:reset':
                DCE.Desktop.setState(STATE_CLOSED);
                DCE.Windows.closeAll();
                break;
                
            case 'lifecycle:cleanup':
                DCE.Desktop.setState(STATE_CLOSED);
                DCE.Windows.closeAll();
                break;
        }
    });

    // ===========================================================================
    // ESC Key Handler
    // ===========================================================================

    // IMPORTANT: We do NOT add keydown listeners here because FiveM
    // auto-grants focus when it detects keyboard listeners.
    // ESC is handled via NUICallback when focus IS active.

    // ===========================================================================
    // Initialization
    // ===========================================================================

    function init() {
        DCE_CALENDAR.diagLog('Initializing lifecycle manager');
        
        // Ensure closed state on load
        DCE.Desktop.setState(STATE_CLOSED);
        
        // Notify Lua that NUI is loaded (but stay hidden)
        DCE.NUI.post('dce-cc:nui:loaded').then(function(response) {
            DCE_CALENDAR.diagLog('NUI loaded state: ' + response.state);
        });
    }

    // DOM ready check
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

})();