/**
 * DCE Control Center - Window Manager
 * Manages draggable, resizable windows within the desktop environment
 */

(function() {
    'use strict';

    // DCE Namespace
    window.DCE = window.DCE || {};

    DCE.Windows = {
        windows: {},
        zIndex: 100,
        activeWindow: null,

        init: function() {
            this.bindToolbar();
        },

        bindToolbar: function() {
            var toolbar = document.getElementById('main-toolbar');
            if (!toolbar) return;

            toolbar.addEventListener('click', function(e) {
                var btn = e.target.closest('.toolbar-btn');
                if (!btn) return;

                var action = btn.getAttribute('data-action');
                var windowId = btn.getAttribute('data-window');

                if (action === 'open-window' && windowId) {
                    DCE.Windows.create(windowId);
                }
            });
        },

        // Load saved window state from localStorage
        loadWindowState: function(windowId) {
            var saved = localStorage.getItem('dce-window-' + windowId);
            if (saved) {
                try {
                    return JSON.parse(saved);
                } catch (e) {
                    console.error('Failed to parse window state:', e);
                }
            }
            return null;
        },

        // Save window state to localStorage
        saveWindowState: function(windowId, state) {
            try {
                localStorage.setItem('dce-window-' + windowId, JSON.stringify(state));
            } catch (e) {
                console.error('Failed to save window state:', e);
            }
        },

        create: function(windowId, options) {
            options = options || {};
            
            // If window already exists, just focus it
            if (DCE.Windows.windows[windowId]) {
                DCE.Windows.focus(windowId);
                return;
            }

            var template = document.getElementById('template-window');
            var clone = template.content.cloneNode(true);
            var windowEl = clone.querySelector('.window');

            windowEl.setAttribute('data-window-id', windowId);
            
            // Load saved state or use defaults
            var savedState = DCE.Windows.loadWindowState(windowId);
            windowEl.style.width = (savedState.width || options.width || 600) + 'px';
            windowEl.style.height = (savedState.height || options.height || 400) + 'px';
            windowEl.style.left = (savedState.x || options.x || 100) + 'px';
            windowEl.style.top = (savedState.y || options.y || 100) + 'px';

            var titleEl = windowEl.querySelector('.window-title');
            if (options.title) {
                titleEl.textContent = options.title;
            } else {
                // Default title based on windowId
                var titles = {
                    organizations: 'Organizations',
                    dispatch: 'Dispatch',
                    analytics: 'Analytics',
                    performance: 'Performance',
                    services: 'Services',
                    plugins: 'Plugins',
                    adapters: 'Adapters',
                    settings: 'Settings',
                    locations: 'Locations',
                    territories: 'Territories'
                };
                titleEl.textContent = titles[windowId] || windowId;
            }

            DCE.Windows.setupWindow(windowId, windowEl);
            document.getElementById('desktop').appendChild(windowEl);
            DCE.Windows.windows[windowId] = windowEl;
            DCE.Windows.focus(windowId);

            // Load module content
            DCE.Windows.loadModule(windowId, windowEl.querySelector('.window-content'));
        },

        setupWindow: function(windowId, windowEl) {
            var header = windowEl.querySelector('.window-header');
            var minimizeBtn = windowEl.querySelector('.window-btn.minimize');
            var maximizeBtn = windowEl.querySelector('.window-btn.maximize');
            var closeBtn = windowEl.querySelector('.window-btn.close');
            var resizeHandle = windowEl.querySelector('.window-resize-handle');

            // Drag handling
            header.addEventListener('mousedown', function(e) {
                if (e.target.closest('.window-btn')) return;
                DCE.Windows.startDrag(windowId, e);
                DCE.Windows.focus(windowId);
            });

            // Resize handling
            if (resizeHandle) {
                resizeHandle.addEventListener('mousedown', function(e) {
                    DCE.Windows.startResize(windowId, e);
                    e.stopPropagation();
                });
            }

            // Window controls
            minimizeBtn.addEventListener('click', function() {
                DCE.Windows.minimize(windowId);
            });

            maximizeBtn.addEventListener('click', function() {
                DCE.Windows.maximize(windowId);
            });

            closeBtn.addEventListener('click', function() {
                DCE.Windows.close(windowId);
            });
        },

        startResize: function(windowId, e) {
            var windowEl = DCE.Windows.windows[windowId];
            if (!windowEl) return;

            var startX = e.clientX;
            var startY = e.clientY;
            var startWidth = parseInt(windowEl.style.width) || 600;
            var startHeight = parseInt(windowEl.style.height) || 400;

            function resize(e) {
                var newWidth = startWidth + (e.clientX - startX);
                var newHeight = startHeight + (e.clientY - startY);
                
                // Enforce min/max bounds
                newWidth = Math.max(300, Math.min(1200, newWidth));
                newHeight = Math.max(200, Math.min(800, newHeight));
                
                windowEl.style.width = newWidth + 'px';
                windowEl.style.height = newHeight + 'px';
            }

            function stop() {
                // Save window state
                DCE.Windows.saveWindowState(windowId, {
                    x: parseInt(windowEl.style.left) || 100,
                    y: parseInt(windowEl.style.top) || 100,
                    width: parseInt(windowEl.style.width) || 600,
                    height: parseInt(windowEl.style.width) || 400
                });
                
                document.removeEventListener('mousemove', resize);
                document.removeEventListener('mouseup', stop);
            }

            document.addEventListener('mousemove', resize);
            document.addEventListener('mouseup', stop);
            e.preventDefault();
        },

        startDrag: function(windowId, e) {
            var windowEl = DCE.Windows.windows[windowId];
            if (!windowEl) return;

            var startX = e.clientX;
            var startY = e.clientY;
            var startLeft = parseInt(windowEl.style.left) || 0;
            var startTop = parseInt(windowEl.style.top) || 0;

            function move(e) {
                windowEl.style.left = (startLeft + e.clientX - startX) + 'px';
                windowEl.style.top = (startTop + e.clientY - startY) + 'px';
            }

            function stop() {
                // Save window position
                DCE.Windows.saveWindowState(windowId, {
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

        focus: function(windowId) {
            var windowEl = DCE.Windows.windows[windowId];
            if (!windowEl) return;

            DCE.Windows.zIndex++;
            windowEl.style.zIndex = DCE.Windows.zIndex;
            DCE.Windows.activeWindow = windowId;
        },

        minimize: function(windowId) {
            var windowEl = DCE.Windows.windows[windowId];
            if (!windowEl) return;
            windowEl.classList.add('minimized');
        },

        maximize: function(windowId) {
            var windowEl = DCE.Windows.windows[windowId];
            if (!windowEl) return;
            windowEl.classList.toggle('maximized');
            if (windowEl.classList.contains('maximized')) {
                windowEl.style.width = 'calc(100vw - 240px)';
                windowEl.style.height = 'calc(100vh - 72px)';
                windowEl.style.left = '0';
                windowEl.style.top = '0';
            }
        },

        close: function(windowId) {
            var windowEl = DCE.Windows.windows[windowId];
            if (!windowEl) return;

            windowEl.remove();
            delete DCE.Windows.windows[windowId];

            // Check if this was the last window - if so, release focus
            var remainingWindows = Object.keys(DCE.Windows.windows).length;
            if (remainingWindows === 0 && DCE.UI && DCE.UI.getState('isOpen')) {
                // All windows closed, release NUI focus
                DCE.NUI.post('close', { allWindowsClosed: true });
                DCE.UI.setState('isOpen', false);
            }
        },

        closeAll: function() {
            var windowIds = Object.keys(DCE.Windows.windows);
            for (var i = 0; i < windowIds.length; i++) {
                DCE.Windows.close(windowIds[i]);
            }
        },

        loadModule: function(windowId, container) {
            // Modules are loaded in order, they self-register their render functions
            if (DCE.Modules && DCE.Modules[windowId]) {
                DCE.Modules[windowId].render(container);
            } else {
                container.innerHTML = '<div class="loading">Loading ' + windowId + '...</div>';
            }
        }
    };

    // Initialize when DOM ready
    document.addEventListener('DOMContentLoaded', function() {
        DCE.Windows.init();
    });

})();