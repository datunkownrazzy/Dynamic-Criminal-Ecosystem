/**
 * DCE Control Center v2 - World Manager Plugin
 * Complete World & Location Manager UI
 */

(function() {
    'use strict';

    window.DCE = window.DCE || {};
    DCE.Plugins = DCE.Plugins || {};

    DCE.Plugins['world-manager'] = {
        windows: {},

        render: function(container) {
            container.innerHTML = `
                <div class="card">
                    <div class="card-header">World Manager</div>
                    <div style="margin-bottom: 12px;">
                        <div class="tab-bar">
                            <button class="tab active" data-tab="locations">Locations</button>
                            <button class="tab" data-tab="territories">Territories</button>
                            <button class="tab" data-tab="providers">Providers</button>
                        </div>
                        <div style="display: flex; gap: 8px; margin-top: 8px;">
                            <button class="btn" id="btn-create-location">Create Location</button>
                            <button class="btn secondary" id="btn-refresh">Refresh</button>
                        </div>
                    </div>
                    <div class="content-body" id="world-content">
                        <div class="loading">Loading...</div>
                    </div>
                </div>
            `;

            this.bindEvents(container);
            this.loadLocations();
        },

        bindEvents: function(container) {
            const self = this;
            
            // Tab switching
            const tabs = container.querySelectorAll('.tab');
            tabs.forEach(function(tab) {
                tab.addEventListener('click', function() {
                    container.querySelectorAll('.tab').forEach(function(t) {
                        t.classList.remove('active');
                    });
                    tab.classList.add('active');
                    
                    const tabName = tab.getAttribute('data-tab');
                    self.switchTab(tabName);
                });
            });

            // Create location button
            const createBtn = container.querySelector('#btn-create-location');
            if (createBtn) {
                createBtn.addEventListener('click', function() {
                    self.showCreateModal();
                });
            }

            const refreshBtn = container.querySelector('#btn-refresh');
            if (refreshBtn) {
                refreshBtn.addEventListener('click', function() {
                    self.loadLocations();
                });
            }
        },

        switchTab: function(tabName) {
            const content = document.getElementById('world-content');
            if (!content) return;

            switch (tabName) {
                case 'locations':
                    this.loadLocations();
                    break;
                case 'territories':
                    this.loadTerritories();
                    break;
                case 'providers':
                    this.loadProviders();
                    break;
            }
        },

        loadLocations: async function() {
            const content = document.getElementById('world-content');
            if (!content) return;

            try {
                const response = await DCE.NUI.post('dcc-location:list');
                const locations = response.locations || [];

                if (locations.length === 0) {
                    content.innerHTML = '<div class="loading">No locations configured</div>';
                    return;
                }

                let html = '<table class="data-table"><thead><tr>' +
                    '<th>ID</th><th>Name</th><th>Type</th><th>Status</th><th>Actions</th></tr></thead><tbody>';

                locations.forEach(function(loc) {
                    html += '<tr>' +
                        '<td>' + (loc.id || 'N/A') + '</td>' +
                        '<td>' + (loc.name || loc.id || 'N/A') + '</td>' +
                        '<td>' + (loc.type || 'N/A') + '</td>' +
                        '<td><span class="status-indicator ' + (loc.active ? '' : 'error') + '"></span> ' + 
                            (loc.active ? 'Active' : 'Inactive') + '</td>' +
                        '<td>' +
                            '<button class="btn secondary btn-edit" data-id="' + loc.id + '">Edit</button> ' +
                            '<button class="btn danger btn-delete" data-id="' + loc.id + '">Delete</button>' +
                        '</td>' +
                    '</tr>';
                });

                html += '</tbody></table>';
                content.innerHTML = html;

                // Bind edit/delete buttons
                this.bindLocationButtons();

            } catch (err) {
                content.innerHTML = '<div class="loading error">Failed to load locations</div>';
            }
        },

        bindLocationButtons: function() {
            const self = this;
            
            document.querySelectorAll('.btn-edit').forEach(function(btn) {
                btn.addEventListener('click', function() {
                    const id = this.getAttribute('data-id');
                    self.editLocation(id);
                });
            });

            document.querySelectorAll('.btn-delete').forEach(function(btn) {
                btn.addEventListener('click', function() {
                    const id = this.getAttribute('data-id');
                    self.deleteLocation(id);
                });
            });
        },

        loadTerritories: async function() {
            const content = document.getElementById('world-content');
            if (!content) return;

            try {
                const response = await DCE.NUI.post('dcc-territory:list');
                const territories = response.territories || [];

                if (territories.length === 0) {
                    content.innerHTML = '<div class="loading">No territories configured</div>';
                    return;
                }

                let html = '<table class="data-table"><thead><tr>' +
                    '<th>ID</th><th>Name</th><th>Center</th><th>Owner</th><th>Actions</th></tr></thead><tbody>';

                territories.forEach(function(terr) {
                    html += '<tr>' +
                        '<td>' + (terr.id || 'N/A') + '</td>' +
                        '<td>' + (terr.name || terr.id || 'N/A') + '</td>' +
                        '<td>' + (terr.center ? 
                            (terr.center.x + ', ' + terr.center.y + ', ' + terr.center.z) : 'N/A') + '</td>' +
                        '<td>' + (terr.ownerId || 'None') + '</td>' +
                        '<td>' +
                            '<button class="btn secondary btn-edit" data-id="' + terr.id + '">Edit</button> ' +
                            '<button class="btn danger btn-delete" data-id="' + terr.id + '">Delete</button>' +
                        '</td>' +
                    '</tr>';
                });

                html += '</tbody></table>';
                content.innerHTML = html;

            } catch (err) {
                content.innerHTML = '<div class="loading error">Failed to load territories</div>';
            }
        },

        loadProviders: function() {
            const content = document.getElementById('world-content');
            if (!content) return;

            content.innerHTML = `
                <div class="stats-grid">
                    <div class="stat-item">
                        <div class="stat-value">Native</div>
                        <div class="stat-label">GTA Interiors</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-value">MLO</div>
                        <div class="stat-label">Walk-in Interiors</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-value">Instanced</div>
                        <div class="stat-label">Bucket Interiors</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-value">Hybrid</div>
                        <div class="stat-label">Chained Transitions</div>
                    </div>
                </div>
            `;
        },

        showCreateModal: function() {
            const modal = document.createElement('div');
            modal.className = 'modal-overlay';
            modal.innerHTML = `
                <div class="card" style="width: 500px;">
                    <div class="card-header">Create Location</div>
                    <div class="form-group">
                        <label class="form-label">Location ID</label>
                        <input class="form-control" id="loc-id" placeholder="unique_location_id">
                    </div>
                    <div class="form-group">
                        <label class="form-label">Name</label>
                        <input class="form-control" id="loc-name" placeholder="Display Name">
                    </div>
                    <div class="form-group">
                        <label class="form-label">Type</label>
                        <select class="form-control" id="loc-type">
                            <option value="vanilla">Vanilla (Native GTA)</option>
                            <option value="walkin-mlo">Walk-in MLO</option>
                            <option value="instanced">Instanced Interior</option>
                            <option value="business">Business</option>
                            <option value="safehouse">Safehouse</option>
                            <option value="druglab">Drug Lab</option>
                            <option value="warehouse">Warehouse</option>
                        </select>
                    </div>
                    <div style="display: flex; gap: 8px; justify-content: flex-end;">
                        <button class="btn secondary" id="btn-cancel">Cancel</button>
                        <button class="btn" id="btn-save">Save</button>
                    </div>
                </div>
            `;

            document.body.appendChild(modal);

            modal.querySelector('#btn-cancel').addEventListener('click', function() {
                modal.remove();
            });

            modal.querySelector('#btn-save').addEventListener('click', async () => {
                const locationData = {
                    id: modal.querySelector('#loc-id').value,
                    name: modal.querySelector('#loc-name').value,
                    type: modal.querySelector('#loc-type').value
                };

                if (locationData.id && locationData.name) {
                    const result = await DCE.NUI.post('dcc-location:create', locationData);
                    if (result && result.success) {
                        DCE.Notifications.success('Location created');
                        this.loadLocations();
                    } else {
                        DCE.Notifications.error(result && result.error || 'Failed to create');
                    }
                    modal.remove();
                }
            });
        },

        deleteLocation: async function(id) {
            if (confirm('Delete location ' + id + '?')) {
                const result = await DCE.NUI.post('dcc-location:delete', { id: id });
                if (result && result.success) {
                    DCE.Notifications.success('Location deleted');
                    this.loadLocations();
                } else {
                    DCE.Notifications.error('Failed to delete location');
                }
            }
        },

        editLocation: function(id) {
            DCE.Notifications.info('Edit location: ' + id);
        }
    };

})();