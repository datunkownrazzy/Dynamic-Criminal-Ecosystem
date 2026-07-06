/**
 * DCE Control Center - Dispatch Module
 */

(function() {
    'use strict';
    window.DCE = window.DCE || {};
    DCE.Modules = DCE.Modules || {};

    DCE.Modules.dispatch = {
        calls: [],

        render: function(container) {
            container.innerHTML = '\
                <div class="card-header" style="margin-bottom: 12px;">Dispatch Calls</div>\
                <table class="data-table">\
                    <thead>\
                        <tr>\
                            <th>ID</th>\
                            <th>Description</th>\
                            <th>Status</th>\
                            <th>Priority</th>\
                            <th>Region</th>\
                        </tr>\
                    </thead>\
                    <tbody id="dispatch-body">\
                        <tr><td colspan="5" class="loading">Loading...</td></tr>\
                    </tbody>\
                </table>';
            
            this.loadData();
        },

        loadData: async function() {
            this.calls = await DCE.API.getIncidents();
            this.renderTable();
        },

        renderTable: function() {
            var tbody = document.getElementById('dispatch-body');
            if (!tbody) return;

            if (this.calls.length === 0) {
                tbody.innerHTML = '<tr><td colspan="5" class="loading">No active calls</td></tr>';
                return;
            }

            var html = '';
            this.calls.forEach(function(call) {
                html += '<tr>\
                    <td>' + (call.id || '') + '</td>\
                    <td>' + (call.description || '') + '</td>\
                    <td>' + (call.status || 'Unknown') + '</td>\
                    <td>' + (call.priority || 'medium') + '</td>\
                    <td>' + (call.regionId || '') + '</td>\
                </tr>';
            });
            
            tbody.innerHTML = html;
        }
    };
})();