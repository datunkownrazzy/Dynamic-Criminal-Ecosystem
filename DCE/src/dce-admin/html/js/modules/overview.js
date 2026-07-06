/**
 * DCE Control Center - Overview Module
 * Main dashboard showing key metrics
 */

(function() {
    'use strict';
    window.DCE = window.DCE || {};
    DCE.Modules = DCE.Modules || {};

    DCE.Modules.overview = {
        render: function(container) {
            container.innerHTML = '\
                <div class="stats-grid">\
                    <div class="card stat-item">\
                        <div class="stat-value" id="stat-orgs">0</div>\
                        <div class="stat-label">Organizations</div>\
                    </div>\
                    <div class="card stat-item">\
                        <div class="stat-value" id="stat-incidents">0</div>\
                        <div class="stat-label">Active Incidents</div>\
                    </div>\
                    <div class="card stat-item">\
                        <div class="stat-value" id="stat-tasks">0</div>\
                        <div class="stat-label">Active Tasks</div>\
                    </div>\
                    <div class="card stat-item">\
                        <div class="stat-value" id="stat-errors">0</div>\
                        <div class="stat-label">Total Errors</div>\
                    </div>\
                </div>\
                <div class="card" style="margin-top: 12px;">\
                    <div class="card-header">Integration Status</div>\
                    <div id="integration-status">Loading...</div>\
                </div>';
            
            this.loadData();
        },

        loadData: async function() {
            var data = await DCE.API.getDashboardData();
            if (data) {
                document.getElementById('stat-orgs').textContent = (data.organizations || []).length;
                document.getElementById('stat-incidents').textContent = (data.incidents || []).length;
                document.getElementById('stat-tasks').textContent = data.performance?.activeTasks || 0;
                document.getElementById('stat-errors').textContent = data.performance?.totalErrors || 0;
                this.renderIntegrations(data.integrations);
            }
        },

        renderIntegrations: function(integrations) {
            var container = document.getElementById('integration-status');
            if (!integrations) {
                container.textContent = 'No integration data';
                return;
            }

            var html = '<div class="stats-grid" style="grid-template-columns: repeat(2, 1fr);">';
            
            if (integrations.dispatch) {
                html += '<div class="stat-item"><span class="status-indicator"></span> Dispatch: ' + integrations.dispatch.status + '</div>';
            }
            if (integrations.evidence) {
                html += '<div class="stat-item"><span class="status-indicator"></span> Evidence: ' + integrations.evidence.status + '</div>';
            }
            
            html += '</div>';
            container.innerHTML = html;
        }
    };
})();