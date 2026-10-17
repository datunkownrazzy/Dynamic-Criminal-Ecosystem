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
    var drafts = { location: null, territory: null };
    var configurationChangedHandler = null;
    var capabilitiesReady = false;
    var targetCapabilities = { location: null, territory: null };

    function can(kind, operation) {
        if (!capabilitiesReady) return false;
        var capabilities = targetCapabilities[kind];
        return !!capabilities && capabilities.state === 'available' &&
            (capabilities.actions || []).indexOf(operation) !== -1;
    }

    function escapeHtml(value) {
        return String(value == null ? '' : value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    function setEditorStatus(kind, message, state) {
        var status = document.querySelector('#' + kind + '-editor-status');
        if (!status) return;
        status.className = 'editor-status ' + (state || '');
        status.textContent = message || '';
    }

    function setPlacementInput(kind, placement) {
        var draft = drafts[kind];
        if (!draft) return;
        draft.placement = placement;
        renderEditor(kind);
    }

    function cancelPlacement(kind) {
        var draft = drafts[kind];
        if (!draft || !draft.placement || draft.placement.state === 'not-started') return false;
        DCE.NUI.post('world-placement:cancel', {}).catch(function() {});
        draft.placement = { state: 'not-started' };
        renderEditor(kind);
        return true;
    }

    function startPlacement(kind) {
        var draft = drafts[kind];
        if (!draft) return;
        if (!can(kind, draft.operation === 'create' ? 'create' : 'update')) return;
        draft.placement = { state: 'active' };
        renderEditor(kind);
        DCE.NUI.post('world-placement:start', {}).catch(function() {
            draft.placement = { state: 'failed' };
            renderEditor(kind);
        });
    }

    function capturePlacement(kind) {
        var draft = drafts[kind];
        if (!draft || !draft.placement || draft.placement.state !== 'active') return;
        setEditorStatus(kind, 'Capturing current player position...', 'applying');
        DCE.NUI.post('world-placement:capture', {}).then(function(response) {
            if (!response || response.code !== 'SUCCESS' || !response.coordinates) {
                setPlacementInput(kind, { state: 'failed', message: (response && response.message) || 'Position capture failed.' });
                return;
            }
            setPlacementInput(kind, {
                state: 'captured',
                coordinates: response.coordinates,
                heading: Number(response.heading)
            });
        }).catch(function() {
            setPlacementInput(kind, { state: 'failed', message: 'Position capture failed.' });
        });
    }

    function renderEditor(kind) {
        var container = document.querySelector('#' + kind + '-editor');
        var draft = drafts[kind];
        if (!container) return;
        if (!draft) {
            container.innerHTML = '';
            return;
        }

        var record = draft.record;
        var isCreate = draft.operation === 'create';
        var placement = draft.placement || { state: 'not-started' };
        var captured = placement.state === 'captured';
        var canUpdate = can(kind, draft.operation === 'create' ? 'create' : 'update');
        var canDelete = can(kind, 'delete');
        var placementMessage = placement.state === 'active' ? 'Move your character to the desired location, then capture the current position.' :
            placement.state === 'captured' ? 'Position and heading captured.' :
            placement.state === 'failed' ? placement.message || 'Position capture failed.' : 'Not placed';
        container.innerHTML =
            '<div class="editor-panel" data-kind="' + kind + '">' +
                '<div class="editor-heading">' + (isCreate ? 'New ' : 'Edit ') + (kind === 'territory' ? 'Territory' : 'Location') + '</div>' +
                '<div class="editor-grid">' +
                    '<label>Id<input class="form-control" data-field="id" ' + (isCreate ? '' : 'readonly') + ' value="' + escapeHtml(record.id) + '"></label>' +
                    '<label>Name<input class="form-control" data-field="name" value="' + escapeHtml(record.name) + '"></label>' +
                    (kind === 'territory' ? '<label>Owner<input class="form-control" data-field="owner" value="' + escapeHtml(record.owner) + '"></label>' : '') +
                '</div>' +
                    '<div class="placement-panel ' + escapeHtml(placement.state) + '">' +
                    '<div class="placement-heading">' + (placement.state === 'active' ? 'Placement Mode' : 'Placement') + '</div>' +
                    '<div class="placement-message">' + escapeHtml(canUpdate ? placementMessage : ((targetCapabilities[kind] && targetCapabilities[kind].message) || 'World editing is unavailable.')) + '</div>' +
                    (captured ? '<div class="placement-summary">Position captured<br>Heading captured</div>' : '') +
                    '<div class="editor-actions placement-actions">' +
                        (canUpdate && placement.state === 'active' ? '<button type="button" class="btn primary" data-action="capture-placement">Capture Position</button>' : '') +
                        (canUpdate && captured ? '<button type="button" class="btn primary" data-action="apply">Confirm Placement</button><button type="button" class="btn secondary" data-action="start-placement">Reposition</button>' : (canUpdate ? '<button type="button" class="btn primary" data-action="start-placement">Place in World</button>' : '')) +
                        (placement.state === 'active' ? '<button type="button" class="btn secondary" data-action="cancel-placement">Cancel</button>' : '') +
                        (canUpdate && placement.state === 'active' ? '<button type="button" class="btn secondary" data-action="reset-placement">Reset</button>' : '') +
                    '</div>' +
                '</div>' +
                '<div class="editor-status" id="' + kind + '-editor-status"></div>' +
                '<div class="editor-actions" data-actions hidden>' +
                    (captured ? '' : '') +
                    '<button type="button" class="btn secondary" data-action="revert">Revert</button>' +
                '</div>' +
                (!isCreate && canDelete ? '<button type="button" class="btn danger" data-action="delete">Delete</button>' : '') +
            '</div>';
    }

    function beginCreate(kind) {
        if (!can(kind, 'create')) return;
        drafts[kind] = {
            operation: 'create',
            dirty: true,
            placement: { state: 'not-started' },
            record: { id: '', name: '' }
        };
        renderEditor(kind);
    }

    function selectRecord(kind, id) {
        if (!can(kind, 'update') && !can(kind, 'delete')) return;
        var records = kind === 'territory' ? territories : locations;
        var record = records.filter(function(item) { return item.id === id; })[0];
        if (!record) return;
        drafts[kind] = { operation: 'update', dirty: false, record: JSON.parse(JSON.stringify(record)) };
        renderEditor(kind);
    }

    function getPatch(kind) {
        var panel = document.querySelector('#' + kind + '-editor .editor-panel');
        if (!panel) return null;
        var value = function(field) { var input = panel.querySelector('[data-field="' + field + '"]'); return input ? input.value : ''; };
        var draft = drafts[kind];
        var placement = draft && draft.placement;
        if (!placement || placement.state !== 'captured') {
            setEditorStatus(kind, 'Capture a placement before confirming.', 'error');
            return null;
        }
        return {
            id: value('id'),
            name: value('name'),
            coordinates: placement.coordinates,
            heading: placement.heading,
            owner: kind === 'territory' ? value('owner') : undefined
        };
    }

    function applyDraft(kind, operation) {
        var draft = drafts[kind];
        if (!draft) return;
        if (!can(kind, operation)) return;
        var patch = operation === 'delete' ? {} : getPatch(kind);
        if (!patch && operation !== 'delete') return;
        var target = kind === 'territory' ? 'world.territory' : 'world.location';
        var request = {
            target: target,
            targetId: operation === 'create' ? null : draft.record.id,
            operation: operation,
            expectedRevision: operation === 'create' ? null : draft.record.revision,
            patch: operation === 'delete' ? {} : patch
        };
        setEditorStatus(kind, 'Applying...', 'applying');
        DCE.NUI.post('world-configuration:apply', request).then(function(response) {
            if (response && response.code === 'SUCCESS') {
                setEditorStatus(kind, response.persisted ? 'Applied and saved.' : 'Applied.');
                drafts[kind] = null;
                fetchLocations();
                fetchTerritories();
                return;
            }
                    var message = response && response.message;
                    if (response && response.code === 'PERMISSION_DENIED') {
                        message = 'You do not have permission to modify world locations.';
                    }
                    setEditorStatus(kind, message || 'Configuration failed.', 'error');
        }).catch(function() {
            setEditorStatus(kind, 'TIMEOUT: No authoritative response was received.', 'error');
        });
    }
    
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

    function fetchCapabilities() {
        return DCE.NUI.post('configuration:get', {}).then(function(response) {
            targetCapabilities = { location: null, territory: null };
            (response && response.targets || []).forEach(function(target) {
                if (target.target === 'world.location') targetCapabilities.location = target;
                if (target.target === 'world.territory') targetCapabilities.territory = target;
            });
            capabilitiesReady = true;
            renderLocations();
            renderTerritories();
            if (drafts.location) renderEditor('location');
            if (drafts.territory) renderEditor('territory');
        }).catch(function() {
            capabilitiesReady = true;
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
                     String(loc.name || loc.id || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
                     String(loc.type || '').toLowerCase().includes(searchQuery.toLowerCase());
        });
        
        container.innerHTML = filtered.length ? filtered.map(function(loc) {
            var coordinates = loc.coordinates || {};
            var x = Number(coordinates.x || 0).toFixed(2);
            var y = Number(coordinates.y || 0).toFixed(2);
            var z = Number(coordinates.z || 0).toFixed(2);
            return '<div class="location-item" data-id="' + escapeHtml(loc.id) + '">' +
                '<div class="location-name">' + escapeHtml(loc.name || loc.id) + '</div>' +
                '<div class="location-coords">(' + x + ', ' + y + ', ' + z + ')</div>' +
                '<div class="location-type">' + escapeHtml(loc.type || 'Unspecified') + '</div>' +
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
            return '<div class="territory-item" data-id="' + escapeHtml(territory.id) + '">' +
                '<div class="territory-name">' + escapeHtml(territory.name || territory.id) + '</div>' +
                '<div class="territory-owner">Owner: ' + escapeHtml(territory.owner || 'Unclaimed') + '</div>' +
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

        },
        
        // Lifecycle: Start (called on activation)
        Start: function() {
            console.log('[WorldManager] Start');
            pluginState = 'started';
            if (DCE.Runtime && !configurationChangedHandler) {
                configurationChangedHandler = function(change) {
                    var result = change && (change.payload || change);
                    if (result && /^world\.(location|territory)$/.test(result.target || '')) {
                        fetchLocations();
                        fetchTerritories();
                    }
                };
                DCE.Runtime.on('configuration:changed', configurationChangedHandler);
            }

        },
        
        // Lifecycle: Stop (called on shutdown)
        Stop: function() {
            console.log('[WorldManager] Stop');
            pluginState = 'stopped';
            if (DCE.Runtime && configurationChangedHandler) {
                DCE.Runtime.off('configuration:changed', configurationChangedHandler);
                configurationChangedHandler = null;
            }
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
                        '<div class="context-actions"><button type="button" class="btn secondary" data-action="new-location" data-capability="location.create">New location</button></div>' +
                        '<div class="locations-list" id="locations-list">' +
                            '<div class="loading">Loading locations...</div>' +
                        '</div>' +
                        '<div id="location-editor"></div>' +
                    '</div>' +
                    '<div class="tab-content hidden" id="territories-tab">' +
                        '<div class="context-actions"><button type="button" class="btn secondary" data-action="new-territory" data-capability="territory.create">New territory</button></div>' +
                        '<div class="territories-list" id="territories-list">' +
                            '<div class="loading">Loading territories...</div>' +
                        '</div>' +
                        '<div id="territory-editor"></div>' +
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

            container.addEventListener('click', function(event) {
                var item = event.target.closest('.location-item, .territory-item');
                if (item) {
                    selectRecord(item.classList.contains('territory-item') ? 'territory' : 'location', item.dataset.id);
                    return;
                }
                var action = event.target.dataset.action;
                if (action === 'new-location') return beginCreate('location');
                if (action === 'new-territory') return beginCreate('territory');
                var panel = event.target.closest('.editor-panel');
                if (!panel || !action) return;
                var kind = panel.dataset.kind;
                if (action === 'apply') return applyDraft(kind, drafts[kind].operation);
                if (action === 'start-placement') return startPlacement(kind);
                if (action === 'capture-placement') return capturePlacement(kind);
                if (action === 'cancel-placement') return cancelPlacement(kind);
                if (action === 'reset-placement') {
                    return DCE.NUI.post('world-placement:reset', {}).then(function(response) {
                        if (response && response.code === 'SUCCESS') {
                            capturePlacement(kind);
                        } else {
                            setPlacementInput(kind, { state: 'failed', message: (response && response.message) || 'Placement reset failed.' });
                        }
                    }).catch(function() {
                        setPlacementInput(kind, { state: 'failed', message: 'Placement reset failed.' });
                    });
                }
                if (action === 'delete') return applyDraft(kind, 'delete');
                if (action === 'revert') {
                    drafts[kind] = null;
                    renderEditor(kind);
                }
            });

            container.addEventListener('input', function(event) {
                var panel = event.target.closest('.editor-panel');
                if (!panel) return;
                var draft = drafts[panel.dataset.kind];
                if (!draft) return;
                var field = event.target.dataset.field;
                if (field && draft.record) {
                    draft.record[field] = event.target.value;
                }
                draft.dirty = true;
                var actions = panel.querySelector('[data-actions]');
                if (actions) actions.hidden = false;
            });
            
            // Fetch initial data
            fetchLocations();
            fetchTerritories();
            fetchCapabilities();
        },
        
        onClose: function() {
            console.log('[WorldManager] Window closed');
            cancelPlacement('location');
            cancelPlacement('territory');
        },

        cancelPlacement: function() {
            return cancelPlacement('location') || cancelPlacement('territory');
        }
    };
    
    console.log('[WorldManager] Plugin loaded');
    
})();