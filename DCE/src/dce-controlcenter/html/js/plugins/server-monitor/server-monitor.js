/**
 * DCE Control Center v2 - Server Monitor Plugin
 * Live server statistics and player monitoring
 * 
 * Implements full plugin lifecycle: Initialize, Start, Stop, Destroy
 */

(function() {
    'use strict';
    
    window.DCE = window.DCE || {};
    DCE.Plugins = DCE.Plugins || {};
    
    // Internal state
    var intervalId = null;
    var pluginState = 'unloaded';
    
    DCE.Plugins['server-monitor'] = {
        // Plugin metadata
        id: 'server-monitor',
        displayName: 'Server Monitor',
        name: 'Server Monitor',
        icon: '📊',
        
        // Lifecycle: Initialize (called on boot)
        Initialize: function() {
            console.log('[ServerMonitor] Initialize');
            pluginState = 'initialized';
            DCE.NUI.post('dce-cc:plugin:initialized', { pluginId: 'server-monitor' }).catch(function() {});
        },
        
        // Lifecycle: Start (called on activation)
        Start: function() {
            console.log('[ServerMonitor] Start');
            pluginState = 'started';
            DCE.NUI.post('dce-cc:plugin:started', { pluginId: 'server-monitor' }).catch(function() {});
        },
        
        // Lifecycle: Stop (called on shutdown)
        Stop: function() {
            console.log('[ServerMonitor] Stop');
            pluginState = 'stopped';
        },
        
        // Lifecycle: Destroy (called on cleanup)
        Destroy: function() {
            console.log('[ServerMonitor] Destroy');
            if (intervalId) {
                clearInterval(intervalId);
                intervalId = null;
            }
            pluginState = 'destroyed';
        },
        
        // Render plugin UI
        render: function(container) {
            container.innerHTML = `
                <div class="card">
                    <div class="card-header">Server Monitor</div>
                    <div class="stats-grid">
                        <div class="stat-item">
                            <div class="stat-value" id="stat-players">0</div>
                            <div class="stat-label">Players Online</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value" id="stat-fps">0</div>
                            <div class="stat-label">Server FPS</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value" id="stat-memory">0 MB</div>
                            <div class="stat-label">Memory Usage</div>
                        </div>
                    </div>
                    <div style="margin-top: 16px;">
                        <div class="loading">Live data - awaiting runtime integration</div>
                    </div>
                </div>
            `;
        },
        
        // Cleanup when window closed
        onClose: function() {
            console.log('[ServerMonitor] Window closed');
            if (intervalId) {
                clearInterval(intervalId);
                intervalId = null;
            }
        }
    };
    
})();