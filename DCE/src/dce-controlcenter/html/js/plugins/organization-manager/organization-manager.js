/**
 * DCE Control Center v2 - Organization Manager Plugin
 * Manage organizations, territories, and facilities
 */

(function() {
    'use strict';

    window.DCE = window.DCE || {};
    DCE.Plugins = DCE.Plugins || {};

    DCE.Plugins['organization-manager'] = {
        organizations: [],

        render: async function(container) {
            container.innerHTML = `
                <div class="card">
                    <div class="card-header">Organizations</div>
                    <div style="margin-bottom: 12px;">
                        <button class="btn" id="btn-create-org">Create Organization</button>
                        <button class="btn secondary" id="btn-refresh-orgs">Refresh</button>
                    </div>
                    <table class="data-table" id="orgs-table">
                        <thead>
                            <tr>
                                <th>ID</th>
                                <th>Name</th>
                                <th>Type</th>
                                <th>Members</th>
                                <th>Heat</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr><td colspan="6" class="loading">Loading organizations...</td></tr>
                        </tbody>
                    </table>
                </div>
            `;

            this.bindEvents();
            this.loadOrganizations();
        },

        bindEvents: function() {
            const self = this;

            const createBtn = document.getElementById('btn-create-org');
            if (createBtn) {
                createBtn.addEventListener('click', function() {
                    self.showCreateModal();
                });
            }

            const refreshBtn = document.getElementById('btn-refresh-orgs');
            if (refreshBtn) {
                refreshBtn.addEventListener('click', function() {
                    self.loadOrganizations();
                });
            }
        },

        loadOrganizations: async function() {
            const tbody = document.querySelector('#orgs-table tbody');
            if (!tbody) return;

            tbody.innerHTML = '<tr><td colspan="6" class="loading">Loading...</td></tr>';

            try {
                // This would integrate with Organizations service
                const response = await DCE.NUI.post('dcc-organization:list');
                const orgs = response.organizations || [];

                if (orgs.length === 0) {
                    tbody.innerHTML = '<tr><td colspan="6" class="loading">No organizations configured</td></tr>';
                    return;
                }

                let html = '';
                orgs.forEach(function(org) {
                    html += '<tr>' +
                        '<td>' + (org.id || 'N/A') + '</td>' +
                        '<td>' + (org.name || 'N/A') + '</td>' +
                        '<td>' + (org.type || 'N/A') + '</td>' +
                        '<td>' + (org.members || 0) + '</td>' +
                        '<td>' + (org.heat || 0) + '</td>' +
                        '<td>' +
                            '<button class="btn secondary btn-edit" data-id="' + org.id + '">Edit</button> ' +
                            '<button class="btn danger btn-delete" data-id="' + org.id + '">Delete</button>' +
                        '</td>' +
                    '</tr>';
                });

                tbody.innerHTML = html;

            } catch (err) {
                tbody.innerHTML = '<tr><td colspan="6" class="loading error">Failed to load</td></tr>';
            }
        },

        showCreateModal: function() {
            DCE.Notifications.info('Organization creation - coming soon');
        }
    };

})();