/**
 * DCE Control Center v2 - Organization Manager Plugin
 * Manages criminal organizations, leadership, and hierarchies
 * 
 * Implements full plugin lifecycle: Initialize, Start, Stop, Destroy
 * Provides organization CRUD, membership management, and heat tracking
 */

(function() {
    'use strict';
    
    window.DCE = window.DCE || {};
    DCE.Plugins = DCE.Plugins || {};
    
    // Internal state
    var organizations = [];
    var members = [];
    var searchQuery = '';
    var currentOrgId = null;
    var pluginState = 'unloaded';
    var eventUnsubscribers = [];
    
    /**
     * Fetch organizations from server
     */
    function fetchOrganizations() {
        return DCE.NUI.post('organization-list:get', {})
            .then(function(response) {
                if (response && response.organizations) {
                    organizations = response.organizations;
                    renderOrganizations();
                }
            })
            .catch(function(err) {
                console.error('[OrganizationManager] Failed to fetch organizations:', err);
            });
    }
    
    /**
     * Fetch members for current organization
     */
    function fetchMembers(orgId) {
        return DCE.NUI.post('organization-members:get', { organizationId: orgId })
            .then(function(response) {
                if (response && response.members) {
                    members = response.members;
                    renderMembers();
                }
            })
            .catch(function(err) {
                console.error('[OrganizationManager] Failed to fetch members:', err);
            });
    }
    
    /**
     * Render organizations list
     */
    function renderOrganizations() {
        var container = document.getElementById('orgs-list');
        if (!container) return;
        
        var filtered = organizations.filter(function(org) {
            return !searchQuery || 
                   org.name.toLowerCase().includes(searchQuery.toLowerCase());
        });
        
        container.innerHTML = filtered.map(function(org) {
            return '<div class="org-item" data-id="' + org.id + '">' +
                '<div class="org-name">' + org.name + '</div>' +
                '<div class="org-leader">Leader: ' + (org.leaderName || 'Unassigned') + '</div>' +
                '<div class="org-heat">Heat: ' + org.heat + '</div>' +
            '</div>';
        }).join('');
        
        // Add click handlers
        container.querySelectorAll('.org-item').forEach(function(item) {
            item.addEventListener('click', function() {
                var orgId = this.dataset.id;
                selectOrganization(orgId);
            });
        });
    }
    
    /**
     * Render members list
     */
    function renderMembers() {
        var container = document.getElementById('members-list');
        if (!container) return;
        
        container.innerHTML = members.map(function(member) {
            return '<div class="member-item" data-id="' + member.id + '">' +
                '<div class="member-name">' + member.name + '</div>' +
                '<div class="member-rank">Rank: ' + member.rank + '</div>' +
                '<div class="member-status">Status: ' + member.status + '</div>' +
            '</div>';
        }).join('');
    }
    
    /**
     * Select an organization and load its details
     */
    function selectOrganization(orgId) {
        currentOrgId = orgId;
        fetchMembers(orgId);
    }
    
    /**
     * Create new organization
     */
    function createOrganization(name) {
        return DCE.NUI.post('organization:create', { name: name })
            .then(function(response) {
                if (response && response.organization) {
                    organizations.push(response.organization);
                    renderOrganizations();
                }
            })
            .catch(function(err) {
                console.error('[OrganizationManager] Failed to create organization:', err);
            });
    }
    
    // Plugin subscription to EventBus for live updates
    function subscribeToEvents() {
        // Subscribe to organization updates
        var unsubOrg = DCE.Bus && DCE.Bus.on && DCE.Bus.on('organization:created', function(data) {
            organizations.push(data.organization);
            renderOrganizations();
        });
        if (unsubOrg) eventUnsubscribers.push(unsubOrg);
        
        // Subscribe to heat changes
        var unsubHeat = DCE.Bus && DCE.Bus.on && DCE.Bus.on('organization:heat:changed', function(data) {
            var idx = organizations.findIndex(function(o) { return o.id === data.organizationId; });
            if (idx >= 0) {
                organizations[idx].heat = data.heat;
                renderOrganizations();
            }
        });
        if (unsubHeat) eventUnsubscribers.push(unsubHeat);
    }
    
    // Unsubscribe from all events
    function unsubscribeFromEvents() {
        eventUnsubscribers.forEach(function(unsub) {
            if (typeof unsub === 'function') unsub();
        });
        eventUnsubscribers = [];
    }
    
    DCE.Plugins['organization-manager'] = {
        // Plugin metadata
        id: 'organization-manager',
        displayName: 'Organization Manager',
        name: 'Organization Manager',
        icon: '👥',
        version: '1.0.0',
        dependencies: [],
        
        // Lifecycle: Initialize (called on boot)
        Initialize: function() {
            console.log('[OrganizationManager] Initialize');
            pluginState = 'initialized';
            DCE.NUI.post('dce-cc:plugin:initialized', { pluginId: 'organization-manager' }).catch(function() {});
        },
        
        // Lifecycle: Start (called on activation)
        Start: function() {
            console.log('[OrganizationManager] Start');
            pluginState = 'started';
            subscribeToEvents();
            fetchOrganizations();
            DCE.NUI.post('dce-cc:plugin:started', { pluginId: 'organization-manager' }).catch(function() {});
        },
        
        // Lifecycle: Stop (called on shutdown)
        Stop: function() {
            console.log('[OrganizationManager] Stop');
            pluginState = 'stopped';
        },
        
        // Lifecycle: Destroy (called on cleanup)
        Destroy: function() {
            console.log('[OrganizationManager] Destroy');
            unsubscribeFromEvents();
            pluginState = 'destroyed';
        },
        
        // Render plugin UI
        render: function(container) {
            container.innerHTML = 
                '<div class="plugin-container">' +
                    '<div class="tab-bar">' +
                        '<button class="tab active" data-tab="orgs">Organizations</button>' +
                        '<button class="tab" data-tab="members">Members</button>' +
                    '</div>' +
                    '<div class="toolbar">' +
                        '<input type="text" class="form-control" placeholder="Search organizations..." id="org-search" style="flex: 1;">' +
                        '<button class="btn btn-primary" id="btn-add-org">+ Add</button>' +
                    '</div>' +
                    '<div class="tab-content" id="orgs-tab">' +
                        '<div class="orgs-list" id="orgs-list">' +
                            '<div class="loading">Loading organizations...</div>' +
                        '</div>' +
                    '</div>' +
                    '<div class="tab-content hidden" id="members-tab">' +
                        '<div class="members-list" id="members-list">' +
                            '<div class="loading">Select an organization to view members</div>' +
                        '</div>' +
                    '</div>' +
                '</div>';
            
            // Setup tab switching
            var tabs = container.querySelectorAll('.tab');
            tabs.forEach(function(tab) {
                tab.addEventListener('click', function() {
                    tabs.forEach(function(t) { t.classList.remove('active'); });
                    this.classList.add('active');
                    
                    var tabName = this.dataset.tab;
                    container.querySelectorAll('.tab-content').forEach(function(content) {
                        content.classList.add('hidden');
                    });
                    container.querySelector('#' + tabName + '-tab').classList.remove('hidden');
                });
            });
            
            // Setup search
            var searchInput = container.querySelector('#org-search');
            if (searchInput) {
                searchInput.addEventListener('input', function(e) {
                    searchQuery = e.target.value;
                    renderOrganizations();
                });
            }
            
            // Setup add button
            var addBtn = container.querySelector('#btn-add-org');
            if (addBtn) {
                addBtn.addEventListener('click', function() {
                    var name = prompt('Organization name:');
                    if (name) createOrganization(name);
                });
            }
            
            // Fetch initial data
            fetchOrganizations();
        },
        
        onClose: function() {
            console.log('[OrganizationManager] Window closed');
        }
    };
    
    console.log('[OrganizationManager] Plugin loaded');
    
})();