/**
 * DCE Control Center - API Client
 * Wraps DCE service data requests with caching and event-driven updates
 */

(function() {
    'use strict';

    window.DCE = window.DCE || {};

    DCE.API = {
        cache: {},
        subscriptions: {},

        // Dashboard Data
        getDashboardData: async function() {
            var data = await DCE.NUI.post('getDashboardData', {});
            DCE.API.cache.dashboard = data;
            return data;
        },

        // Organizations
        getOrganizations: async function() {
            var data = await DCE.NUI.post('getOrganizations', {});
            DCE.API.cache.organizations = data;
            return data;
        },

        getOrganizationState: async function(orgId) {
            var data = await DCE.NUI.post('getOrganizationState', { orgId: orgId });
            return data;
        },

        // Incidents
        getIncidents: async function() {
            var data = await DCE.NUI.post('getIncidents', {});
            DCE.API.cache.incidents = data;
            return data;
        },

        // Performance
        getPerformanceMetrics: async function() {
            var data = await DCE.NUI.post('getPerformanceMetrics', {});
            DCE.API.cache.performance = data;
            return data;
        },

        getTasks: async function() {
            var data = await DCE.NUI.post('getTasks', {});
            DCE.API.cache.tasks = data;
            return data;
        },

        // Services
        getServices: async function() {
            var data = await DCE.NUI.post('getServices', {});
            DCE.API.cache.services = data;
            return data;
        },

        // Events
        getEvents: async function() {
            var data = await DCE.NUI.post('getEvents', {});
            DCE.API.cache.events = data;
            return data;
        },

        // Debug
        executeDebug: async function(command, args) {
            var data = await DCE.NUI.post('executeDebug', { 
                command: command, 
                args: args || [] 
            });
            return data;
        },

        // Debug History
        getDebugHistory: async function(limit) {
            limit = limit || 50;
            var data = await DCE.NUI.post('getDebugHistory', { limit: limit });
            return data;
        },

        // Audit Log
        getAuditLog: async function(limit) {
            limit = limit || 50;
            var data = await DCE.NUI.post('getAuditLog', { limit: limit });
            return data;
        },

        // Config
        getConfigs: async function() {
            var data = await DCE.NUI.post('getConfigs', {});
            DCE.API.cache.configs = data;
            return data;
        },

        updateConfig: async function(resource, key, value) {
            var data = await DCE.NUI.post('updateConfig', {
                resource: resource,
                key: key,
                value: value
            });
            if (data && data.success) {
                // Notify listeners of config change
                if (DCE.EventHandler) {
                    DCE.EventHandler.handleEvent({
                        eventName: 'config:updated',
                        payload: { resource: resource, key: key, value: value }
                    });
                }
            }
            return data;
        },

        // Locations (World Editor)
        getLocations: async function() {
            var data = await DCE.NUI.post('getLocations', {});
            DCE.API.cache.locations = data;
            return data;
        },

        getLocation: async function(id) {
            var data = await DCE.NUI.post('getLocation', { id: id });
            return data;
        },

        createLocation: async function(locationData) {
            var data = await DCE.NUI.post('createLocation', locationData);
            if (data && data.success) {
                // Notify listeners
                if (DCE.EventHandler) {
                    DCE.EventHandler.handleEvent({
                        eventName: 'location:created',
                        payload: data.location
                    });
                }
            }
            return data;
        },

        updateLocation: async function(id, locationData) {
            var data = await DCE.NUI.post('updateLocation', { id: id, ...locationData });
            if (data && data.success) {
                if (DCE.EventHandler) {
                    DCE.EventHandler.handleEvent({
                        eventName: 'location:updated',
                        payload: data.location
                    });
                }
            }
            return data;
        },

        deleteLocation: async function(id) {
            var data = await DCE.NUI.post('deleteLocation', { id: id });
            if (data && data.success && DCE.EventHandler) {
                DCE.EventHandler.handleEvent({
                    eventName: 'location:deleted',
                    payload: { id: id }
                });
            }
            return data;
        },

        // Territories (World Editor)
        getTerritories: async function() {
            var data = await DCE.NUI.post('getTerritories', {});
            DCE.API.cache.territories = data;
            return data;
        },

        getTerritory: async function(id) {
            var data = await DCE.NUI.post('getTerritory', { id: id });
            return data;
        },

        createTerritory: async function(territoryData) {
            var data = await DCE.NUI.post('createTerritory', territoryData);
            if (data && data.success && DCE.EventHandler) {
                DCE.EventHandler.handleEvent({
                    eventName: 'territory:created',
                    payload: data.territory
                });
            }
            return data;
        },

        updateTerritory: async function(id, territoryData) {
            var data = await DCE.NUI.post('updateTerritory', { id: id, ...territoryData });
            if (data && data.success && DCE.EventHandler) {
                DCE.EventHandler.handleEvent({
                    eventName: 'territory:updated',
                    payload: data.territory
                });
            }
            return data;
        },

        deleteTerritory: async function(id) {
            var data = await DCE.NUI.post('deleteTerritory', { id: id });
            if (data && data.success && DCE.EventHandler) {
                DCE.EventHandler.handleEvent({
                    eventName: 'territory:deleted',
                    payload: { id: id }
                });
            }
            return data;
        },

        // Runtime Configuration (hot-reload)
        reloadConfig: async function(resource) {
            var data = await DCE.NUI.post('reloadConfig', { resource: resource });
            if (data && data.success && DCE.EventHandler) {
                DCE.EventHandler.handleEvent({
                    eventName: 'config:reloaded',
                    payload: { resource: resource }
                });
            }
            return data;
        }
    };

})();
