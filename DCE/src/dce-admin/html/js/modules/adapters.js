/**
 * DCE Control Center - Adapters Module
 */

(function() {
    'use strict';
    window.DCE = window.DCE || {};
    DCE.Modules = DCE.Modules || {};

    DCE.Modules.adapters = {
        adapters: {},

        render: function(container) {
            container.innerHTML = '\
                <div class="card-header" style="margin-bottom: 12px;">Adapter Status</div>\
                <table class="data-table">\
                    <thead>\
                        <tr>\
                            <th>Adapter</th>\
                            <th>Type</th>\
                            <th>Status</th>\
                            <th>Health</th>\
                            <th>Latency</th>\
                            <th>Actions</th>\
                        </tr>\
                    </thead>\
                    <tbody id="adapters-body">\
                        <tr><td colspan="6" class="loading">Loading...</td></tr>\
                    </tbody>\
                </table>';
            
            this.loadData();
        },

        loadData: async function() {
            var data = await DCE.NUI.post('getAdapters', {});
            this.adapters = data || {};
            this.renderTable();
        },

        renderTable: function() {
            var tbody = document.getElementById('adapters-body');
            if (!tbody) return;

            var html = '';
            var hasData = false;

            Object.keys(this.adapters).forEach(function(adapterName) {
                hasData = true;
                var adapter = this.adapters[adapterName];
                html += '<tr>\
                    <td>' + adapterName + '</td>\
                    <td>' + (adapter.adapter || 'native') + '</td>\
                    <td><span class="status-indicator ' + (adapter.status === 'active' ? '' : 'warning') + '"></span> ' + (adapter.status || 'unknown') + '</td>\
                    <td>' + (adapter.health || 100) + '%</td>\
                    <td>' + (adapter.latency || 0) + 'ms</td>\
                    <td>\
                        <button class="btn secondary" data-action="reconnect" data-adapter="' + adapterName + '">Reconnect</button>\
                    </td>\
                </tr>';
            }.bind(this));

            if (!hasData) {
                tbody.innerHTML = '<tr><td colspan="6" class="loading">No adapters configured</td></tr>';
                return;
            }
            
            tbody.innerHTML = html;
        }
    };
})();