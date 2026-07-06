/**
 * DCE Control Center - Plugins Module
 */

(function() {
    'use strict';
    window.DCE = window.DCE || {};
    DCE.Modules = DCE.Modules || {};

    DCE.Modules.plugins = {
        plugins: [],

        render: function(container) {
            container.innerHTML = '\
                <div class="card-header" style="margin-bottom: 12px;">Registered Plugins</div>\
                <table class="data-table">\
                    <thead>\
                        <tr>\
                            <th>Name</th>\
                            <th>ID</th>\
                            <th>Version</th>\
                            <th>Status</th>\
                        </tr>\
                    </thead>\
                    <tbody id="plugins-body">\
                        <tr><td colspan="4" class="loading">Loading...</td></tr>\
                    </tbody>\
                </table>';
            
            this.loadData();
        },

        loadData: async function() {
            // Get plugins from admin service
            var data = await DCE.NUI.post('getPlugins', {});
            this.plugins = (data && data.plugins) || [];
            this.renderTable();
        },

        renderTable: function() {
            var tbody = document.getElementById('plugins-body');
            if (!tbody) return;

            if (this.plugins.length === 0) {
                tbody.innerHTML = '<tr><td colspan="4" class="loading">No plugins registered</td></tr>';
                return;
            }

            var html = '';
            this.plugins.forEach(function(plugin) {
                html += '<tr>\
                    <td>' + (plugin.Name || '') + '</td>\
                    <td>' + (plugin.Id || '') + '</td>\
                    <td>' + (plugin.Version || '') + '</td>\
                    <td><span class="status-indicator"></span> Active</td>\
                </tr>';
            });
            
            tbody.innerHTML = html;
        }
    };
})();