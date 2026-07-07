/**
 * DCE Control Center - Territories Module
 * World Editor: Territory management UI
 */

(function() {
    'use strict';
    window.DCE = window.DCE || {};
    DCE.Modules = DCE.Modules || {};

    DCE.Modules.territories = {
        territories: [],

        render: function(container) {
            container.innerHTML = '\
                <div class="card-header">Territory Management</div>\
                <div style="margin-bottom: 12px;">\
                    <button class="btn" id="btn-create-territory">Create Territory</button>\
                    <button class="btn secondary" id="btn-refresh-territories">Refresh</button>\
                </div>\
                <table class="data-table" id="territories-table">\
                    <thead>\
                        <tr>\
                            <th>ID</th>\
                            <th>Name</th>\
                            <th>Organization</th>\
                            <th>Heat</th>\
                            <th>Status</th>\
                            <th>Actions</th>\
                        </tr>\
                    </thead>\
                    <tbody id="territories-tbody">\
                        <tr><td colspan="6" class="loading">Loading territories...</td></tr>\
                    </tbody>\
                </table>';
            
            this.bindEvents();
            this.loadTerritories();
        },

        bindEvents: function() {
            var self = this;
            
            var createBtn = document.getElementById('btn-create-territory');
            if (createBtn) {
                createBtn.addEventListener('click', function() {
                    self.showCreateModal();
                });
            }

            var refreshBtn = document.getElementById('btn-refresh-territories');
            if (refreshBtn) {
                refreshBtn.addEventListener('click', function() {
                    self.loadTerritories();
                });
            }
        },

        showCreateModal: function() {
            var modal = document.createElement('div');
            modal.className = 'modal-overlay';
            modal.innerHTML = '\
                <div class="card" style="width: 400px;">\
                    <div class="card-header">Create New Territory</div>\
                    <div class="form-group">\
                        <label class="form-label">Territory ID</label>\
                        <input class="form-control" id="terr-id" placeholder="unique_territory_id">\
                    </div>\
                    <div class="form-group">\
                        <label class="form-label">Name</label>\
                        <input class="form-control" id="terr-name" placeholder="Display Name">\
                    </div>\
                    <div class="form-group">\
                        <label class="form-label">Organization ID</label>\
                        <input class="form-control" id="terr-org" placeholder="org_id">\
                    </div>\
                    <div class="form-group">\
                        <label class="form-label">Bounds (minX, minY, minZ, maxX, maxY, maxZ)</label>\
                        <input class="form-control" id="terr-bounds" placeholder="0.0, 0.0, 0.0, 100.0, 100.0, 50.0">\
                    </div>\
                    <div style="display: flex; gap: 8px; justify-content: flex-end;">\
                        <button class="btn secondary" id="btn-cancel-terr">Cancel</button>\
                        <button class="btn" id="btn-save-territory">Save</button>\
                    </div>\
                </div>';
            
            document.body.appendChild(modal);

            document.getElementById('btn-cancel-terr').addEventListener('click', function() {
                modal.remove();
            });

            document.getElementById('btn-save-territory').addEventListener('click', function() {
                var territoryData = {
                    id: document.getElementById('terr-id').value,
                    name: document.getElementById('terr-name').value,
                    organizationId: document.getElementById('terr-org').value,
                    bounds: document.getElementById('terr-bounds').value
                };
                
                if (territoryData.id && territoryData.name) {
                    DCE.API.createTerritory(territoryData).then(function(result) {
                        if (result && result.success) {
                            DCE.Notifications.success('Territory created');
                            self.loadTerritories();
                        } else {
                            DCE.Notifications.error(result && result.error || 'Failed to create territory');
                        }
                        modal.remove();
                    });
                }
            });
        },

        loadTerritories: function() {
            var tbody = document.getElementById('territories-tbody');
            if (!tbody) return;

            DCE.API.getTerritories().then(function(data) {
                var territories = data && (data.territories || data) || [];
                this.territories = territories;
                
                if (!territories || territories.length === 0) {
                    tbody.innerHTML = '<tr><td colspan="6" class="loading">No territories configured</td></tr>';
                    return;
                }

                var html = '';
                for (var i = 0; i < territories.length; i++) {
                    var terr = territories[i];
                    var heatLevel = terr.heat || 0;
                    var heatClass = heatLevel > 75 ? 'error' : (heatLevel > 50 ? 'warning' : '');
                    html += '<tr>\
                        <td>' + (terr.id || 'N/A') + '</td>\
                        <td>' + (terr.name || terr.id || 'N/A') + '</td>\
                        <td>' + (terr.organizationId || 'None') + '</td>\
                        <td><span class="status-indicator ' + heatClass + '"></span> ' + heatLevel + '%</td>\
                        <td>' + ((terr.active !== false) ? '<span class="status-indicator"></span> Active' : '<span class="status-indicator error"></span> Inactive') + '</td>\
                        <td>\
                            <button class="btn secondary btn-edit" data-id="' + terr.id + '">Edit</button>\
                            <button class="btn danger btn-delete" data-id="' + terr.id + '">Delete</button>\
                        </td>\
                    </tr>';
                }
                tbody.innerHTML = html;

                // Bind edit/delete buttons
                var editBtns = tbody.querySelectorAll('.btn-edit');
                for (var i = 0; i < editBtns.length; i++) {
                    editBtns[i].addEventListener('click', function(e) {
                        var id = this.getAttribute('data-id');
                        self.editTerritory(id);
                    });
                }

                var deleteBtns = tbody.querySelectorAll('.btn-delete');
                for (var i = 0; i < deleteBtns.length; i++) {
                    deleteBtns[i].addEventListener('click', function(e) {
                        var id = this.getAttribute('data-id');
                        self.deleteTerritory(id);
                    });
                }
            }.bind(this));
        },

        editTerritory: function(id) {
            DCE.Notifications.info('Edit territory: ' + id);
        },

        deleteTerritory: function(id) {
            if (confirm('Delete territory ' + id + '?')) {
                DCE.API.deleteTerritory(id).then(function(result) {
                    if (result && result.success) {
                        DCE.Notifications.success('Territory deleted');
                        this.loadTerritories();
                    } else {
                        DCE.Notifications.error('Failed to delete territory');
                    }
                }.bind(this));
            }
        }
    };
})();