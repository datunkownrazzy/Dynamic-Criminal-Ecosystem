/**
 * DCE Control Center - Organizations Module
 */

(function() {
    'use strict';
    window.DCE = window.DCE || {};
    DCE.Modules = DCE.Modules || {};

DCE.Modules.organizations = {
        orgs: [],
        selectedOrg: null,

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
                            <th>Actions</th>\
                        </tr>\
                    </thead>\
                    <tbody id="orgs-body">\
                        <tr><td colspan="6" class="loading">Loading...</td></tr>\
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
                tbody.innerHTML = '<tr><td colspan="6" class="loading">No organizations found</td></tr>';
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
                    <td>\
                        <button class="btn btn-sm" onclick="DCE.Modules.organizations.editFacilities(\'' + org.id + '\')">Facilities</button>\
                    </td>\
                </tr>';
            });
            
            tbody.innerHTML = html;
        },

        editFacilities: async function(orgId) {
            this.selectedOrg = orgId;
            var org = this.orgs.find(function(o) { return o.id === orgId; });
            if (!org) return;

            // Open facilities modal or navigate to facilities view
            var facilitiesHtml = '\
                <div class="modal-content" style="background: #161b22; border: 1px solid #30363d; border-radius: 6px; max-width: 800px; width: 90%;">\
                    <div class="card-header" style="margin: 0; border-bottom: 1px solid #30363d; padding: 16px;">\
                        Facilities for ' + (org.name || 'Unknown') + '\
                        <button onclick="DCE.Modules.organizations.closeFacilities()" style="float: right; background: none; border: none; color: #8b949e; cursor: pointer;">×</button>\
                    </div>\
                    <div style="padding: 16px;">\
                        <div style="margin-bottom: 16px;">\
                            <button class="btn btn-primary" onclick="DCE.Modules.organizations.addFacility()">Add Facility</button>\
                        </div>\
                        <table class="data-table">\
                            <thead>\
                                <tr>\
                                    <th>Type</th>\
                                    <th>Location</th>\
                                    <th>Status</th>\
                                    <th>Actions</th>\
                                </tr>\
                            </thead>\
                            <tbody id="facilities-body">\
                                <tr><td colspan="4" class="loading">Loading facilities...</td></tr>\
                            </tbody>\
                        </table>\
                    </div>\
                </div>';
            
            this.showModal(facilitiesHtml);
            this.loadFacilities(orgId);
        },

        showModal: function(html) {
            var modalId = 'facilities-modal-' + Date.now();
            var existing = document.getElementById('org-facilities-modal');
            if (existing) existing.remove();

            var modal = document.createElement('div');
            modal.id = 'org-facilities-modal';
            modal.className = 'modal-overlay';
            modal.style.cssText = 'position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.7); display: flex; align-items: center; justify-content: center; z-index: 10000;';
            modal.innerHTML = html;
            document.body.appendChild(modal);
        },

        closeFacilities: function() {
            var modal = document.getElementById('org-facilities-modal');
            if (modal) modal.remove();
            this.selectedOrg = null;
        },

        loadFacilities: async function(orgId) {
            try {
                var response = await DCE.API.getOrganizationFacilities(orgId);
                var facilities = response.facilities || [];
                this.renderFacilities(facilities);
            } catch (error) {
                console.error('Failed to load facilities:', error);
            }
        },

        renderFacilities: function(facilities) {
            var tbody = document.getElementById('facilities-body');
            if (!tbody) return;

            if (facilities.length === 0) {
                tbody.innerHTML = '<tr><td colspan="4" class="loading">No facilities</td></tr>';
                return;
            }

            var html = '';
            facilities.forEach(function(fac) {
                html += '<tr>\
                    <td>' + (fac.type || 'Unknown') + '</td>\
                    <td>' + (fac.location || 'N/A') + '</td>\
                    <td>' + (fac.active ? 'Active' : 'Inactive') + '</td>\
                    <td>\
                        <button class="btn btn-sm" onclick="DCE.Modules.organizations.editFacility(\'' + fac.id + '\')">Edit</button>\
                    </td>\
                </tr>';
            });
            tbody.innerHTML = html;
        },

        addFacility: function() {
            // Open world editor to create location
            if (DCE.Modules.worldEditor) {
                DCE.Modules.worldEditor.openModal('location', 'create');
            }
        },

        editFacility: async function(facilityId) {
            // Load facility data and open editor
            try {
                var response = await DCE.API.getLocation(facilityId);
                if (response && DCE.Modules.worldEditor) {
                    DCE.Modules.worldEditor.openModal('location', 'edit', response.location);
                }
            } catch (error) {
                console.error('Failed to get facility:', error);
            }
        }
    };
})();
