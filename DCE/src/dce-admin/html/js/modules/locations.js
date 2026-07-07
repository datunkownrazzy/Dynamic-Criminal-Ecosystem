/**
 * DCE Control Center - Locations Module
 * World Editor: Location management UI
 */

(function() {
    'use strict';
    window.DCE = window.DCE || {};
    DCE.Modules = DCE.Modules || {};

    DCE.Modules.locations = {
        locations: [],

        render: function(container) {
            container.innerHTML = '\
                <div class="card-header">Location Management</div>\
                <div style="margin-bottom: 12px;">\
                    <button class="btn" id="btn-create-location">Create Location</button>\
                    <button class="btn secondary" id="btn-refresh-locations">Refresh</button>\
                </div>\
                <table class="data-table" id="locations-table">\
                    <thead>\
                        <tr>\
                            <th>ID</th>\
                            <th>Name</th>\
                            <th>Type</th>\
                            <th>Organization</th>\
                            <th>Status</th>\
                            <th>Actions</th>\
                        </tr>\
                    </thead>\
                    <tbody id="locations-tbody">\
                        <tr><td colspan="6" class="loading">Loading locations...</td></tr>\
                    </tbody>\
                </table>';
            
            this.bindEvents();
            this.loadLocations();
        },

        bindEvents: function() {
            var self = this;
            
            var createBtn = document.getElementById('btn-create-location');
            if (createBtn) {
                createBtn.addEventListener('click', function() {
                    self.showCreateModal();
                });
            }

            var refreshBtn = document.getElementById('btn-refresh-locations');
            if (refreshBtn) {
                refreshBtn.addEventListener('click', function() {
                    self.loadLocations();
                });
            }
        },

        showCreateModal: function() {
            var modal = document.createElement('div');
            modal.className = 'modal-overlay';
            modal.innerHTML = '\
                <div class="card" style="width: 400px;">\
                    <div class="card-header">Create New Location</div>\
                    <div class="form-group">\
                        <label class="form-label">Location ID</label>\
                        <input class="form-control" id="loc-id" placeholder="unique_location_id">\
                    </div>\
                    <div class="form-group">\
                        <label class="form-label">Name</label>\
                        <input class="form-control" id="loc-name" placeholder="Display Name">\
                    </div>\
                    <div class="form-group">\
                        <label class="form-label">Type</label>\
                        <select class="form-control" id="loc-type">\
                            <option value="hq">HQ</option>\
                            <option value="safehouse">Safehouse</option>\
                            <option value="druglab">Drug Lab</option>\
                            <option value="garage">Garage</option>\
                            <option value="meeting">Meeting Room</option>\
                            <option value="dock">Dock</option>\
                            <option value="helipad">Helipad</option>\
                            <option value="emergency">Emergency Exit</option>\
                        </select>\
                    </div>\
                    <div class="form-group">\
                        <label class="form-label">Coordinates (X, Y, Z)</label>\
                        <input class="form-control" id="loc-coords" placeholder="0.0, 0.0, 0.0">\
                    </div>\
                    <div class="form-group">\
                        <label class="form-label">Heading</label>\
                        <input class="form-control" id="loc-heading" placeholder="0.0" type="number">\
                    </div>\
                    <div style="display: flex; gap: 8px; justify-content: flex-end;">\
                        <button class="btn secondary" id="btn-cancel-create">Cancel</button>\
                        <button class="btn" id="btn-save-location">Save</button>\
                    </div>\
                </div>';
            
            document.body.appendChild(modal);

            document.getElementById('btn-cancel-create').addEventListener('click', function() {
                modal.remove();
            });

            document.getElementById('btn-save-location').addEventListener('click', function() {
                var locationData = {
                    id: document.getElementById('loc-id').value,
                    name: document.getElementById('loc-name').value,
                    type: document.getElementById('loc-type').value,
                    coords: document.getElementById('loc-coords').value,
                    heading: parseFloat(document.getElementById('loc-heading').value) || 0
                };
                
                if (locationData.id && locationData.name) {
                    DCE.API.createLocation(locationData).then(function(result) {
                        if (result && result.success) {
                            DCE.Notifications.success('Location created');
                            self.loadLocations();
                        } else {
                            DCE.Notifications.error(result && result.error || 'Failed to create location');
                        }
                        modal.remove();
                    });
                }
            });
        },

        loadLocations: function() {
            var tbody = document.getElementById('locations-tbody');
            if (!tbody) return;

            DCE.API.getLocations().then(function(data) {
                var locations = data && (data.locations || data) || [];
                this.locations = locations;
                
                if (!locations || locations.length === 0) {
                    tbody.innerHTML = '<tr><td colspan="6" class="loading">No locations configured</td></tr>';
                    return;
                }

                var html = '';
                for (var i = 0; i < locations.length; i++) {
                    var loc = locations[i];
                    html += '<tr>\
                        <td>' + (loc.id || 'N/A') + '</td>\
                        <td>' + (loc.name || loc.id || 'N/A') + '</td>\
                        <td>' + (loc.type || 'N/A') + '</td>\
                        <td>' + ((loc.metadata && loc.metadata.orgId) || 'None') + '</td>\
                        <td>' + ((loc.active !== false) ? '<span class="status-indicator"></span> Active' : '<span class="status-indicator error"></span> Inactive') + '</td>\
                        <td>\
                            <button class="btn secondary btn-edit" data-id="' + loc.id + '">Edit</button>\
                            <button class="btn danger btn-delete" data-id="' + loc.id + '">Delete</button>\
                        </td>\
                    </tr>';
                }
                tbody.innerHTML = html;

                // Bind edit/delete buttons
                var editBtns = tbody.querySelectorAll('.btn-edit');
                for (var i = 0; i < editBtns.length; i++) {
                    editBtns[i].addEventListener('click', function(e) {
                        var id = this.getAttribute('data-id');
                        self.editLocation(id);
                    });
                }

                var deleteBtns = tbody.querySelectorAll('.btn-delete');
                for (var i = 0; i < deleteBtns.length; i++) {
                    deleteBtns[i].addEventListener('click', function(e) {
                        var id = this.getAttribute('data-id');
                        self.deleteLocation(id);
                    });
                }
            }.bind(this));
        },

        editLocation: function(id) {
            // Placeholder for edit functionality
            DCE.Notifications.info('Edit location: ' + id);
        },

        deleteLocation: function(id) {
            if (confirm('Delete location ' + id + '?')) {
                DCE.API.deleteLocation(id).then(function(result) {
                    if (result && result.success) {
                        DCE.Notifications.success('Location deleted');
                        this.loadLocations();
                    } else {
                        DCE.Notifications.error('Failed to delete location');
                    }
                }.bind(this));
            }
        }
    };
})();