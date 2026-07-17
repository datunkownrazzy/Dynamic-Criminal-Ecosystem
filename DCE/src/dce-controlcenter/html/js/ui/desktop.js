/**
 * DCE Control Center v2 - Desktop Manager
 * 
 * Created on-demand by ApplicationManager.Boot()
 * Never exists until /dce command is processed
 * 
 * Owns: DOM elements for desktop UI only
 */

(function() {
    'use strict';
    
    // DCE namespace
    window.DCE = window.DCE || {};
    
    const DESKTOP_STATES = {
        HIDDEN: 'hidden',
        VISIBLE: 'visible'
    };
    
    // Desktop manager - lazy instantiated
    DCE.Desktop = DCE.Desktop || {
        state: DESKTOP_STATES.HIDDEN,
        _element: null,
        
        // Create desktop DOM elements (called by ApplicationManager.Boot)
        create: function() {
            if (DCE.Desktop._element) {
                return true; // Already exists
            }
            
            console.log('[DCE Desktop] Creating desktop elements...');
            
            // Create desktop container
            const desktop = document.createElement('div');
            desktop.id = 'desktop';
            desktop.className = 'desktop';
            desktop.innerHTML = `
                <div id="dock" class="dock">
                    <div class="dock-content"></div>
                    <div class="dock-resize-handle"></div>
                </div>
                <div id="window-container" class="window-container"></div>
                <div id="status-bar" class="status-bar">
                    <div class="status-section left">
                        <span class="status-indicator ready" id="status-indicator"></span>
                        <span id="status-text">Ready</span>
                    </div>
                    <div class="status-section center">
                        <span id="breadcrumb"></span>
                    </div>
                    <div class="status-section right">
                        <span id="status-timestamp"></span>
                        <span class="status-version">DCE v2.0.0</span>
                    </div>
                </div>
                <div id="notifications" class="notifications"></div>
                <div id="modal-overlay" class="modal-overlay hidden"></div>
            `;
            
            document.body.appendChild(desktop);
            DCE.Desktop._element = desktop;
            
            console.log('[DCE Desktop] Desktop created');
            return true;
        },
        
        // Open desktop (make visible after focus)
        open: function() {
            if (!DCE.Desktop._element) {
                console.error('[DCE Desktop] Cannot open - not created');
                return false;
            }
            
            console.log('[DCE Desktop] Opening desktop...');
            DCE.Desktop.state = DESKTOP_STATES.VISIBLE;
            
            // CSS class handles visibility (body.cc-active makes UI visible)
            document.body.className = 'cc-active';
            
            return true;
        },
        
        // Close desktop (hide but keep DOM for next activation)
        close: function() {
            console.log('[DCE Desktop] Closing desktop...');
            DCE.Desktop.state = DESKTOP_STATES.HIDDEN;
        },
        
        // Destroy desktop (remove DOM)
        destroy: function() {
            if (DCE.Desktop._element) {
                DCE.Desktop._element.remove();
                DCE.Desktop._element = null;
            }
            DCE.Desktop.state = DESKTOP_STATES.HIDDEN;
        },
        
        // Get desktop state
        getState: function() {
            return DCE.Desktop.state;
        },
        
        // Get element
        getElement: function() {
            return DCE.Desktop._element;
        }
    };
    
})();