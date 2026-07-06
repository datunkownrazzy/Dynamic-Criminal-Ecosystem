/**
 * DCE Control Center - Organizations Module
 */

(function() {
    'use strict';
    window.DCE = window.DCE || {};
    DCE.Modules = DCE.Modules || {};

    DCE.Modules.organizations = {
        orgs: [],

        render: function(container) {
            container.innerHTML = '\
                <div class="card-header" style="margin-bottom: 12px;">Organization List</div>\
                <table class="data-table">\
                    <thead>\
                        <tr>\
                            <th>Name</th>\
                            <th>State</th>\
                            <th>Members</th>\
                            <th>Money</th>\
                            <th>Heat</th>\
                        </tr>\
                    </thead>\
                    <tbody id="orgs-body">\
                        <tr><td colspan="5" class="loading">Loading...</td></tr>\
                    </tbody>\
                </table>';
            
            this.loadData();
        },

        loadData: async function() {
            var data = await DCE.API.getOrganizations();
            this.orgs = data || [];
            this.renderTable();
        },

        renderTable: function() {
            var tbody = document.getElementById('orgs-body');
            if (!tbody) return;

            if (this.orgs.length === 0) {
                tbody.innerHTML = '<tr><td colspan="5" class="loading">No organizations found</td></tr>';
                return;
            }

            var html = '';
            this.orgs.forEach(function(org) {
                html += '<tr>\
                    <td>' + (org.name || 'Unknown') + '</td>\
                    <td>' + (org.state || 'Unknown') + '</td>\
                    <td>' + (org.members || 0) + '</td>\
                    <td>$' + ((org.money || 0).toLocaleString()) + '</td>\
                    <td>' + (org.heat || 0) + '</td>\
                </tr>';
            });
            
            tbody.innerHTML = html;
        }
    };
})();