/**
 * DCE Control Center v2 - Window Manager
 * Manages draggable, resizable windows with state persistence
 */

(function() {
    'use strict';

    window.DCE = window.DCE || {};
    
    // Window state storage (in-memory)
    const windows = new Map();
    let zIndex = 100;

    // DCE Window Manager
    const DCEWindowManager = {
        // Create a new window
        createWindow: function(pluginId, options) {
            options = options || {};
            
            const container = document.getElementById('window-container');
            if (!container) return null;
            
            // Load saved state or use defaults
            const savedState = DCEWindowManager.loadWindowState(pluginId);
            
            const width = savedState.width || options.width || 600;
            const height = savedState.height || options.height || 400;
            const x = savedState.x || options.x || 100;
            const y = savedState.y || options.y || 100;
            
            // Clone template
            const template = document.getElementById('template-window');
            const windowEl = template.content.cloneNode(true).querySelector('.window');
            
            windowEl.setAttribute('data-window-id', pluginId);
            windowEl.style.width = width + 'px';
            windowEl.style.height = height + 'px';
            windowEl.style.left = x + 'px';
            windowEl.style.top = y + 'px';
            windowEl.style.zIndex = ++zIndex;
            
            // Set title
            const titleEl = windowEl.querySelector('.window-title-text');
            titleEl.textContent = options.title || pluginId;
            
            // Set icon
            const iconEl = windowEl.querySelector('.window-icon');
            if (options.icon) {
                iconEl.textContent = options.icon;
            }
            
            // Bind events
            DCEWindowManager.bindWindowEvents(windowEl, pluginId);
            
            // Add to container
            container.appendChild(windowEl);
            
            // Store state
            windows.set(pluginId, {
                element: windowEl,
                x: x,
                y: y,
                width: width,
                height: height
            });
            
            // Load plugin content
            if (DCE.Plugins && DCE.Plugins[pluginId]) {
                DCE.Plugins[pluginId].render(windowEl.querySelector('.content-body'));
            }
            
            return windowEl;
        },
        
        // Bind window controls
        bindWindowEvents: function(windowEl, windowId) {
            const header = windowEl.querySelector('.window-header');
            const closeBtn = windowEl.querySelector('.window-btn.close');
            const minimizeBtn = windowEl.querySelector('.window-btn.minimize');
            const maximizeBtn = windowEl.querySelector('.window-btn.maximize');
            
            // Drag handling
            header.addEventListener('mousedown', function(e) {
                if (e.target.closest('.window-btn')) return;
                DCEWindowManager.startDrag(windowEl, windowId, e);
                DCEWindowManager.focus(windowId);
            });
            
            // Close button
            closeBtn.addEventListener('click', function() {
                DCEWindowManager.closeWindow(windowId);
            });
            
            // Minimize button
            minimizeBtn.addEventListener('click', function() {
                DCEWindowManager.minimize(windowId);
            });
            
            // Maximize button
            maximizeBtn.addEventListener('click', function() {
                DCEWindowManager.maximize(windowId);
            });
            
            // Resize handles
            const resizeHandles = windowEl.querySelectorAll('.resize-handle');
            resizeHandles.forEach(function(handle) {
                handle.addEventListener('mousedown', function(e) {
                    DCEWindowManager.startResize(windowEl, windowId, e);
                    e.stopPropagation();
                });
            });
        },
        
        // Start dragging
        startDrag: function(windowEl, windowId, e) {
            const startX = e.clientX;
            const startY = e.clientY;
            const startLeft = parseInt(windowEl.style.left) || 0;
            const startTop = parseInt(windowEl.style.top) || 0;
            
            function move(e) {
                windowEl.style.left = (startLeft + e.clientX - startX) + 'px';
                windowEl.style.top = (startTop + e.clientY - startY) + 'px';
            }
            
            function stop() {
                DCEWindowManager.saveWindowState(windowId, {
                    x: parseInt(windowEl.style.left) || 100,
                    y: parseInt(windowEl.style.top) || 100,
                    width: parseInt(windowEl.style.width) || 600,
                    height: parseInt(windowEl.style.height) || 400
                });
                document.removeEventListener('mousemove', move);
                document.removeEventListener('mouseup', stop);
            }
            
            document.addEventListener('mousemove', move);
            document.addEventListener('mouseup', stop);
        },
        
        // Start resizing
        startResize: function(windowEl, windowId, e) {
            const startX = e.clientX;
            const startY = e.clientY;
            const startWidth = parseInt(windowEl.style.width) || 600;
            const startHeight = parseInt(windowEl.style.height) || 400;
            
            function resize(e) {
                const minWidth = DCE.Config && DCE.Config.Windows && DCE.Config.Windows.MinWidth || 300;
                const minHeight = DCE.Config && DCE.Config.Windows && DCE.Config.Windows.MinHeight || 200;
                const maxWidth = DCE.Config && DCE.Config.Windows && DCE.Config.Windows.MaxWidth || 1200;
                const maxHeight = DCE.Config && DCE.Config.Windows && DCE.Config.Windows.MaxHeight || 800;
                
                windowEl.style.width = Math.min(Math.max(minWidth, startWidth + e.clientX - startX), maxWidth) + 'px';
                windowEl.style.height = Math.min(Math.max(minHeight, startHeight + e.clientY - startY), maxHeight) + 'px';
            }
            
            function stop() {
                DCEWindowManager.saveWindowState(windowId, {
                    x: parseInt(windowEl.style.left) || 100,
                    y: parseInt(windowEl.style.top) || 100,
                    width: parseInt(windowEl.style.width) || 600,
                    height: parseInt(windowEl.style.height) || 400
                });
                document.removeEventListener('mousemove', resize);
                document.removeEventListener('mouseup', stop);
            }
            
            document.addEventListener('mousemove', resize);
            document.addEventListener('mouseup', stop);
        },
        
        // Focus window
        focus: function(windowId) {
            const state = windows.get(windowId);
            if (!state) return;
            
            zIndex++;
            state.element.style.zIndex = zIndex;
            
            // Update active state
            document.querySelectorAll('.window').forEach(function(el) {
                el.classList.toggle('active', el === state.element);
            });
        },
        
        // Minimize window
        minimize: function(windowId) {
            const state = windows.get(windowId);
            if (!state) return;
            state.element.classList.add('minimized');
        },
        
        // Maximize window
        maximize: function(windowId) {
            const state = windows.get(windowId);
            if (!state) return;
            state.element.classList.toggle('maximized');
        },
        
        // Close window
        closeWindow: function(windowId) {
            const state = windows.get(windowId);
            if (!state) return;
            
            state.element.remove();
            windows.delete(windowId);
            
            // If no windows left, close desktop
            if (windows.size === 0) {
                DCE.NUI.post('dce-cc:window:allClosed');
            }
        },
        
        // Close all windows
        closeAll: function() {
            windows.forEach(function(state, id) {
                state.element.remove();
            });
            windows.clear();
        },
        
        // Save window state
        saveWindowState: function(windowId, state) {
            try {
                localStorage.setItem('dce-window-' + windowId, JSON.stringify(state));
            } catch (e) {
                console.error('Failed to save window state:', e);
            }
        },
        
        // Load window state
        loadWindowState: function(windowId) {
            try {
                const saved = localStorage.getItem('dce-window-' + windowId);
                if (saved) {
                    return JSON.parse(saved);
                }
            } catch (e) {
                console.error('Failed to load window state:', e);
            }
            return null;
        }
    };
    
    // Export globally for lifecycle.js to use
    window.DCEWindowManager = DCEWindowManager;
    
    // Also attach to DCE namespace
    DCE.Windows = DCEWindowManager;

})();