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
            return data;
        }
    };

})();