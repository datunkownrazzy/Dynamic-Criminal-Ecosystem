/**
 * DCE Control Center v2 - Taskbar
 * 
 * Provides a taskbar showing open windows and system status.
 * Lazy loaded by ApplicationManager on Boot.
 * Never exists until /dce command.
 */

(function() {
    'use strict';
    
    window.DCE = window.DCE || {};
    
    DCE.Taskbar = {
        _element: null,
        _taskItems: new Map(),
        
        init: function() {
            console.log('[DCE Taskbar] Initializing...');
            
            var statusBar = document.getElementById('status-bar');
            if (!statusBar) {
                console.warn('[DCE Taskbar] Status bar not found, creating...');
                statusBar = document.createElement('div');
                statusBar.id = 'status-bar';
                statusBar.className = 'status-bar';
                statusBar.innerHTML = '<div class="status-section left">' +
                    '<span class="status-indicator ready" id="status-indicator"></span>' +
                    '<span id="status-text">Ready</span>' +
                    '</div>' +
                    '<div class="status-section center">' +
                        '<span id="breadcrumb"></span>' +
                    '</div>' +
                    '<div class="status-section right">' +
                        '<span id="status-timestamp"></span>' +
                        '<span class="status-version">DCE v2.0.0</span>' +
                    '</div>';
                
                var desktop = document.getElementById('desktop');
                if (desktop) {
                    desktop.appendChild(statusBar);
                } else {
                    document.body.appendChild(statusBar);
                }
            }
            
            DCE.Taskbar._element = statusBar;
            DCE.Taskbar._updateClock();
            
            if (DCE.Application && DCE.Application.setInterval) {
                DCE.Application.setInterval(function() {
                    DCE.Taskbar._updateClock();
                }, 1000);
            }
            
            console.log('[DCE Taskbar] Initialized');
            return true;
        },
        
        _updateClock: function() {
            var timestamp = document.getElementById('status-timestamp');
            if (!timestamp) return;
            
            var now = new Date();
            var timeStr = now.toLocaleTimeString('en-US', { 
                hour: '2-digit', 
                minute: '2-digit',
                second: '2-digit',
                hour12: false
            });
            var dateStr = now.toLocaleDateString('en-US', {
                month: 'short',
                day: 'numeric',
                year: 'numeric'
            });
            timestamp.textContent = dateStr + ' ' + timeStr;
        },
        
        addTask: function(windowId, title) {
            if (DCE.Taskbar._taskItems.has(windowId)) return;
            
            var item = document.createElement('div');
            item.className = 'taskbar-item';
            item.setAttribute('data-window-id', windowId);
            item.textContent = title || windowId;
            
            item.addEventListener('click', function() {
                if (DCE.Windows && DCE.Windows.focus) {
                    DCE.Windows.focus(windowId);
                }
            });
            
            var breadcrumb = document.getElementById('breadcrumb');
            if (breadcrumb) {
                breadcrumb.appendChild(item);
            }
            
            DCE.Taskbar._taskItems.set(windowId, item);
        },
        
        removeTask: function(windowId) {
            var item = DCE.Taskbar._taskItems.get(windowId);
            if (!item) return;
            
            item.remove();
            DCE.Taskbar._taskItems.delete(windowId);
            
            var breadcrumb = document.getElementById('breadcrumb');
            if (breadcrumb && DCE.Taskbar._taskItems.size === 0) {
                breadcrumb.innerHTML = '';
            }
        },
        
        setStatus: function(text, indicatorClass) {
            var statusText = document.getElementById('status-text');
            var indicator = document.getElementById('status-indicator');
            
            if (statusText) statusText.textContent = text;
            if (indicator) {
                indicator.className = 'status-indicator ' + (indicatorClass || 'ready');
            }
        },
        
        destroy: function() {
            DCE.Taskbar._taskItems.clear();
            DCE.Taskbar._element = null;
        }
    };
    
    console.log('[DCE Taskbar] Loaded');
    
})();