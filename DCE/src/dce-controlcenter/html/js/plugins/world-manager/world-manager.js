/**
 * DCE Control Center v2 - World Manager Plugin
 * Manages world locations, territories, and map overlays
 * 
 * Implements full plugin lifecycle: Initialize, Start, Stop, Destroy
 * Provides location management and territory visualization
 */

(function() {
    'use strict';
    
    window.DCE = window.DCE || {};
    DCE.Plugins = DCE.Plugins || {};
    
    // Internal state
    var locations = [];
    var territories = [];
    var searchQuery = '';
    var pluginState = 'unloaded';
    var eventUnsubscribers = [];
    
    /**
     * Fetch locations from server via EventBus
     */
    function fetchLocations() {
        return DCE.NUI.post('world-locations:get', {})
            .then(function(response) {
                if (response && response.locations) {
                    locations = response.locations;
                    renderLocations();
                }
            })
            .catch(function(err) {
                console.error('[WorldManager] Failed to fetch locations:', err);
            });
    }
    
    /**
     * Fetch territories from server via EventBus
     */
    function fetchTerritories() {
        return DCE.NUI.post('world-territories:get', {})
            .then(function(response) {
                if (response && response.territories) {
                    territories = response.territories;
                    renderTerritories();
                }
            })
            .catch(function(err) {
                console.error('[WorldManager] Failed to fetch territories:', err);
            });
    }
    
    /**
     * Render locations list
     */
    function renderLocations() {
        var container = document.getElementById('locations-list');
        if (!container) return;
        
        var filtered = locations.filter(function(loc) {
            return !searchQuery || 
                   loc.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                   loc.type.toLowerCase().includes(searchQuery.toLowerCase());
        });
        
        container.innerHTML = filtered.map(function(loc) {
            return '<div class="location-item" data-id="' + loc.id + '">' +
                '<div class="location-name">' + loc.name + '</div>' +
                '<div class="location-coords">(' + loc.x.toFixed(2) + ', ' + loc.y.toFixed(2) + ', ' + loc.z.toFixed(2) + ')</div>' +
                '<div class="location-type">' + loc.type + '</div>' +
            '</div>';
        }).join('');
    }
    
    /**
     * Render territories list
     */
    function renderTerritories() {
        var container = document.getElementById('territories-list');
        if (!container) return;
        
        container.innerHTML = territories.map(function(territory) {
            return '<div class="territory-item" data-id="' + territory.id + '" style="border-left: 4px solid ' + territory.color + '">' +
                '<div class="territory-name">' + territory.name + '</div>' +
                '<div class="territory-owner">Owner: ' + (territory.owner || 'Unclaimed') + '</div>' +
                '<div class="territory-heat">Heat: ' + territory.heat + '</div>' +
            '</div>';
        }).join('');
    }
    
    // Plugin subscription to EventBus for live updates
    function subscribeToEvents() {
        // Subscribe to location updates
        var unsubLoc = DCE.Bus && DCE.Bus.on && DCE.Bus.on('world:location:created', function(data) {
            locations.push(data.location);
            renderLocations();
        });
        if (unsubLoc) eventUnsubscribers.push(unsubLoc);
        
        // Subscribe to territory updates
        var unsubTer = DCE.Bus && DCE.Bus.on && DCE.Bus.on('world:territory:updated', function(data) {
            var idx = territories.findIndex(function(t) { return t.id === data.territory.id; });
            if (idx >= 0) {
                territories[idx] = data.territory;
            } else {
                territories.push(data.territory);
            }
            renderTerritories();
        });
        if (unsubTer) eventUnsubscribers.push(unsubTer);
    }
    
    // Unsubscribe from all events
    function unsubscribeFromEvents() {
        eventUnsubscribers.forEach(function(unsub) {
            if (typeof unsub === 'function') unsub();
        });
        eventUnsubscribers = [];
    }
    
    DCE.Plugins['world-manager'] = {
        // Plugin metadata
        id: 'world-manager',
        displayName: 'World Manager',
        name: 'World Manager',
        icon: '🌍',
        version: '1.0.0',
        dependencies: [],
        
        // Lifecycle: Initialize (called on boot)
        Initialize: function() {
            console.log('[WorldManager] Initialize');
            pluginState = 'initialized';
            DCE.NUI.post('dce-cc:plugin:initialized', { pluginId: 'world-manager' }).catch(function() {});
        },
        
        // Lifecycle: Start (called on activation)
        Start: function() {
            console.log('[WorldManager] Start');
            pluginState = 'started';
            subscribeToEvents();
            fetchLocations();
            fetchTerritories();
            DCE.NUI.post('dce-cc:plugin:started', { pluginId: 'world-manager' }).catch(function() {});
        },
        
        // Lifecycle: Stop (called on shutdown)
        Stop: function() {
            console.log('[WorldManager] Stop');
            pluginState = 'stopped';
        },
        
        // Lifecycle: Destroy (called on cleanup)
        Destroy: function() {
            console.log('[WorldManager] Destroy');
            unsubscribeFromEvents();
            pluginState = 'destroyed';
        },
        
        // Render plugin UI
        render: function(container) {
            container.innerHTML = 
                '<div class="plugin-container">' +
                    '<div class="tab-bar">' +
                        '<button class="tab active" data-tab="locations">Locations</button>' +
                        '<button class="tab" data-tab="territories">Territories</button>' +
                    '</div>' +
                    '<div class="search-box">' +
                        '<input type="text" class="form-control" placeholder="Search locations..." id="location-search">' +
                    '</div>' +
                    '<div class="tab-content" id="locations-tab">' +
                        '<div class="locations-list" id="locations-list">' +
                            '<div class="loading">Loading locations...</div>' +
                        '</div>' +
                    '</div>' +
                    '<div class="tab-content hidden" id="territories-tab">' +
                        '<div class="territories-list" id="territories-list">' +
                            '<div class="loading">Loading territories...</div>' +
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
            var searchInput = container.querySelector('#location-search');
            if (searchInput) {
                searchInput.addEventListener('input', function(e) {
                    searchQuery = e.target.value;
                    renderLocations();
                });
            }
            
            // Fetch initial data
            fetchLocations();
            fetchTerritories();
        },
        
        onClose: function() {
            console.log('[WorldManager] Window closed');
        }
    };
    
    console.log('[WorldManager] Plugin loaded');
    
})();