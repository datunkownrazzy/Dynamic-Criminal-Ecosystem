/**
 * DCE Control Center - Settings Module
 * Runtime configuration editor with live propagation
 */

(function() {
    'use strict';
    window.DCE = window.DCE || {};
    DCE.Modules = DCE.Modules || {};

    DCE.Modules.settings = {
        configs: {},
        originalConfigs: {},

        render: function(container) {
            container.innerHTML = '\
                <div class="card-header" style="margin-bottom: 12px;">Configuration Editor</div>\
                <div style="margin-bottom: 16px;">\
                    <button class="btn btn-primary" onclick="DCE.Modules.settings.saveAll()">Save All Changes</button>\
                    <button class="btn" onclick="DCE.Modules.settings.reloadAll()">Reload All</button>\
                </div>\
                <div id="settings-sections">Loading configuration...</div>';
            
            this.loadData();
        },

        loadData: async function() {
            var data = await DCE.API.getConfigs();
            this.configs = JSON.parse(JSON.stringify(data || {}));
            this.originalConfigs = JSON.parse(JSON.stringify(data || {}));
            this.renderSections();
        },

        renderSections: function() {
            var container = document.getElementById('settings-sections');
            if (!container) return;

            var html = '<div style="display: grid; gap: 12px;">';

            Object.keys(this.configs).forEach(function(resource) {
                html += this.renderResourceConfig(resource, this.configs[resource]);
            }.bind(this));

            html += '</div>';
            container.innerHTML = html;
        },

        renderResourceConfig: function(resource, config) {
            var html = '<div class="card">\
                <div class="card-header">' + resource + ' <span style="font-size: 12px; color: #8b949e;">(Runtime: ' + (this.isRuntimeEditable(resource) ? 'Yes' : 'No') + ')</span></div>\
                <div class="config-editor" data-resource="' + resource + '" style="padding: 12px;">';
            
            html += this.renderConfigObject(config, resource, '');
            html += '</div></div>';
            
            return html;
        },

        renderConfigObject: function(obj, resource, path, indent) {
            indent = indent || 0;
            var html = '';
            var pad = 'padding-left: ' + (indent * 16) + 'px;';
            
            Object.keys(obj).forEach(function(key) {
                var value = obj[key];
                var fullPath = path ? path + '.' + key : key;
                var isEditable = this.isRuntimeEditable(resource, fullPath);
                
                if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
                    html += '<div style="' + pad + ' margin: 8px 0;">\
                        <strong>' + key + '</strong>\
                    </div>';
                    html += this.renderConfigObject(value, resource, fullPath, indent + 1);
                } else if (Array.isArray(value)) {
                    html += '<div style="' + pad + ' margin: 8px 0;">\
                        <span>' + key + ': [' + value.length + ' items]</span>\
                    </div>';
                } else {
                    var inputType = typeof value === 'boolean' ? 'checkbox' : 'text';
                    var inputValue = typeof value === 'boolean' ? '' : String(value);
                    var readonly = isEditable ? '' : 'readonly';
                    
                    html += '<div style="' + pad + ' margin: 4px 0; display: flex; align-items: center; gap: 8px;">\
                        <label style="min-width: 120px;">' + key + '</label>\
                        <input type="' + inputType + '" class="form-control config-input" \
                            data-resource="' + resource + '" data-path="' + fullPath + '" \
                            value="' + this.escapeHtml(inputValue) + '" ' + readonly + ' ' + (typeof value === 'boolean' ? 'checked="' + value + '"' : '') + '>\
                    </div>';
                }
            }.bind(this));
            
            return html;
        },

        escapeHtml: function(str) {
            if (!str) return '';
            return String(str).replace(/[&<>"']/g, function(match) {
                return {'&': '&', '<': '<', '>': '>', '"': '"', "'": '&#39;'}[match];
            });
        },

        isRuntimeEditable: function(resource, path) {
            // Resources that support runtime config updates
            var runtimeEditable = {
                'dce-world': true,
                'dce-ai': ['AIDirector.BasePopulation', 'AIDirector.MaxPerPedestrian', 'AIDirector.MaxPerVehicle'],
                'dce-admin': true
            };
            
            if (!runtimeEditable[resource]) return false;
            if (runtimeEditable[resource] === true) return true;
            if (Array.isArray(runtimeEditable[resource])) {
                return runtimeEditable[resource].some(function(p) { return path && path.startsWith(p); });
            }
            return false;
        },

        saveAll: async function() {
            var updates = [];
            var promises = [];
            
            document.querySelectorAll('.config-input').forEach(function(input) {
                var resource = input.getAttribute('data-resource');
                var path = input.getAttribute('data-path');
                var newValue = input.type === 'checkbox' ? input.checked : input.value;
                
                if (path) {
                    promises.push(DCE.API.updateConfig(resource, path, newValue));
                }
            });
            
            await Promise.all(promises);
            DCE.Notifications.info('Configuration saved');
        },

        reloadAll: async function() {
            var data = await DCE.API.getConfigs();
            this.configs = JSON.parse(JSON.stringify(data || {}));
            this.renderSections();
            DCE.Notifications.info('Configuration reloaded');
        }
    };

    // Subscribe to config update events
    if (DCE.EventHandler) {
        DCE.EventHandler.subscribe('config:updated', function(payload) {
            console.log('Config updated:', payload);
            DCE.Notifications.info('Config changed: ' + payload.resource + '.' + payload.key);
        });

        DCE.EventHandler.subscribe('config:reloaded', function(payload) {
            DCE.Modules.settings.loadData();
            DCE.Notifications.info('Config reloaded: ' + payload.resource);
        });
    }
})();
