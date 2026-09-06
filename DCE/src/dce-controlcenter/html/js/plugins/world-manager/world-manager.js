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
    
    /**
     * Fetch locations from server via EventBus
     */
    function fetchLocations() {
        return DCE.NUI.post('world-locations:get', {})
            .then(function(response) {
                if (response && response.locations) {
                    locations = response.locations;
                    renderLocations();
                } else {
                    renderLocationsState('World location data is not currently available.');
                }
            })
            .catch(function(err) {
                console.error('[WorldManager] Failed to fetch locations:', err);
                renderLocationsState('Unable to load world location data. The world service did not return usable data.');
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
                } else {
                    renderTerritoriesState('Territory data is not currently available.');
                }
            })
            .catch(function(err) {
                console.error('[WorldManager] Failed to fetch territories:', err);
                renderTerritoriesState('Unable to load territory data. The world service did not return usable data.');
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
        
        container.innerHTML = filtered.length ? filtered.map(function(loc) {
            var coordinates = loc.coordinates || {};
            var x = Number(coordinates.x || 0).toFixed(2);
            var y = Number(coordinates.y || 0).toFixed(2);
            var z = Number(coordinates.z || 0).toFixed(2);
            return '<div class="location-item" data-id="' + loc.id + '">' +
                '<div class="location-name">' + (loc.name || loc.id) + '</div>' +
                '<div class="location-coords">(' + x + ', ' + y + ', ' + z + ')</div>' +
                '<div class="location-type">' + (loc.type || 'Unspecified') + '</div>' +
            '</div>';
        }).join('') : '<div class="page-state empty">No active world locations.</div>';
    }
    
    /**
     * Render territories list
     */
    function renderTerritories() {
        var container = document.getElementById('territories-list');
        if (!container) return;
        
        container.innerHTML = territories.length ? territories.map(function(territory) {
            return '<div class="territory-item" data-id="' + territory.id + '">' +
                '<div class="territory-name">' + (territory.name || territory.id) + '</div>' +
                '<div class="territory-owner">Owner: ' + (territory.owner || 'Unclaimed') + '</div>' +
                '<div class="territory-heat">Heat: ' + (territory.heat == null ? 'Unavailable' : territory.heat) + '</div>' +
            '</div>';
        }).join('') : '<div class="page-state empty">No active territories.</div>';
    }

    function renderLocationsState(message) {
        var container = document.getElementById('locations-list');
        if (container) container.innerHTML = '<div class="page-state unavailable">' + message + '</div>';
    }

    function renderTerritoriesState(message) {
        var container = document.getElementById('territories-list');
        if (container) container.innerHTML = '<div class="page-state unavailable">' + message + '</div>';
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