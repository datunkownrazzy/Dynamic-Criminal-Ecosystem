/**
 * DCE Control Center v2 - Developer Tools Plugin
 * Live EventBus monitor, Service inspector, and debugging tools
 */

(function() {
    'use strict';

    window.DCE = window.DCE || {};
    DCE.Plugins = DCE.Plugins || {};

    DCE.Plugins['dev-tools'] = {
        events: [],
        services: [],

        render: async function(container) {
            container.innerHTML = `
                <div class="card">
                    <div class="card-header">Developer Tools</div>
                    <div class="tab-bar">
                        <button class="tab active" data-tab="eventbus">EventBus</button>
                        <button class="tab" data-tab="services">Services</button>
                        <button class="tab" data-tab="performance">Performance</button>
                        <button class="tab" data-tab="memory">Memory</button>
                    </div>
                    <div id="dev-content" style="margin-top: 12px; max-height: 400px; overflow: auto;">
                        <div class="loading">Loading...</div>
                    </div>
                </div>
            `;

            this.bindEvents();
            await this.loadEventBus();
        },

        bindEvents: function() {
            const self = this;
            
            document.querySelectorAll('#dev-content').forEach(function(content) {
                content.addEventListener('click', function(e) {
                    const tab = e.target.closest('.tab');
                    if (!tab) return;

                    const container = tab.closest('.card');
                    const tabName = tab.getAttribute('data-tab');
                    
                    container.querySelectorAll('.tab').forEach(function(t) {
                        t.classList.remove('active');
                    });
                    tab.classList.add('active');
                    
                    self.switchTab(tabName);
                });
            });
        },

        switchTab: async function(tabName) {
            const content = document.getElementById('dev-content');
            if (!content) return;

            switch (tabName) {
                case 'eventbus':
                    await this.loadEventBus();
                    break;
                case 'services':
                    await this.loadServices();
                    break;
                case 'performance':
                    await this.loadPerformance();
                    break;
                case 'memory':
                    await this.loadMemory();
                    break;
            }
        },

        loadEventBus: async function() {
            const content = document.getElementById('dev-content');
            if (!content) return;

            try {
                const response = await DCE.NUI.post('dcc-eventbus:metrics');
                const metrics = response.events || [];

                let html = '<table class="data-table"><thead><tr>' +
                    '<th>Event</th><th>Count</th><th>Avg (ms)</th><th>Max (ms)</th></tr></thead><tbody>';

                metrics.forEach(function(event) {
                    html += '<tr>' +
                        '<td>' + (event.name || 'N/A') + '</td>' +
                        '<td>' + (event.totalDispatches || 0) + '</td>' +
                        '<td>' + (event.avgDispatchMs ? event.avgDispatchMs.toFixed(2) : '0') + '</td>' +
                        '<td>' + (event.maxDispatchMs || 0) + '</td>' +
                    '</tr>';
                });

                html += '</tbody></table>';
                content.innerHTML = html;

            } catch (err) {
                content.innerHTML = '<div class="loading error">Failed to load EventBus data</div>';
            }
        },

        loadServices: async function() {
            const content = document.getElementById('dev-content');
            if (!content) return;

            try {
                const response = await DCE.NUI.post('dcc-services:list');
                const services = response.services || [];

                let html = '<table class="data-table"><thead><tr>' +
                    '<th>Service</th><th>Status</th><th>Tasks</th></tr></thead><tbody>';

                services.forEach(function(service) {
                    html += '<tr>' +
                        '<td>' + (service || 'N/A') + '</td>' +
                        '<td><span class="status-indicator"></span> Active</td>' +
                        '<td>' + (service.tasks || 0) + '</td>' +
                    '</tr>';
                });

                html += '</tbody></table>';
                content.innerHTML = html;

            } catch (err) {
                content.innerHTML = '<div class="loading error">Failed to load services</div>';
                console.error('DevTools: Failed to load services', err);
            }
        },

        loadPerformance: async function() {
            const content = document.getElementById('dev-content');
            if (!content) return;

            try {
                const response = await DCE.NUI.post('dcc-profiler:metrics');

                let html = '<div class="stats-grid">';

                for (const [serviceId, metrics] of Object.entries(response.metrics || {})) {
                    html += '<div class="stat-item"><div class="stat-value">' + 
                        (metrics.cpuMs || 0).toFixed(1) + 'ms</div>' +
                        '<div class="stat-label">' + serviceId + '</div></div>';
                }

                html += '</div>';
                content.innerHTML = html || '<div class="loading">No performance data</div>';

            } catch (err) {
                content.innerHTML = '<div class="loading error">Failed to load performance data</div>';
            }
        },

        loadMemory: function() {
            const content = document.getElementById('dev-content');
            if (!content) return;

            // This would show browser memory stats if available
            const perf = performance && performance.memory;
            
            if (perf) {
                const usedMB = (perf.usedJSHeapSize / 1048576).toFixed(2);
                const totalMB = (perf.totalJSHeapSize / 1048576).toFixed(2);
                const limitMB = (perf.jsHeapSizeLimit / 1048576).toFixed(2);

                content.innerHTML = `
                    <div class="stats-grid">
                        <div class="stat-item">
                            <div class="stat-value">${usedMB} MB</div>
                            <div class="stat-label">Used Heap</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value">${totalMB} MB</div>
                            <div class="stat-label">Total Heap</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-value">${limitMB} MB</div>
                            <div class="stat-label">Heap Limit</div>
                        </div>
                    </div>
                `;
            } else {
                content.innerHTML = '<div class="loading">Memory stats not available in this browser</div>';
            }
        }
    };

})();