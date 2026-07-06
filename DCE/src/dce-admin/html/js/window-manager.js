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
            windowEl.style.width = (options.width || 600) + 'px';
            windowEl.style.height = (options.height || 400) + 'px';
            windowEl.style.left = (options.x || 100) + 'px';
            windowEl.style.top = (options.y || 100) + 'px';

            var titleEl = windowEl.querySelector('.window-title');
            if (options.title) {
                titleEl.textContent = options.title;
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

            // Drag handling
            header.addEventListener('mousedown', function(e) {
                if (e.target.closest('.window-btn')) return;
                DCE.Windows.startDrag(windowId, e);
            });

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

        startDrag: function(windowId, e) {
            var windowEl = DCE.Windows.windows[windowId];
            var startX = e.clientX;
            var startY = e.clientY;
            var startLeft = parseInt(windowEl.style.left) || 0;
            var startTop = parseInt(windowEl.style.top) || 0;

            function move(e) {
                windowEl.style.left = (startLeft + e.clientX - startX) + 'px';
                windowEl.style.top = (startTop + e.clientY - startY) + 'px';
            }

            function stop() {
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

            // Notify Lua of window close
            DCE.NUI.post('windowClosed', { windowId: windowId });
        },

        closeAll: function() {
            Object.keys(DCE.Windows.windows).forEach(function(windowId) {
                DCE.Windows.close(windowId);
            });
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