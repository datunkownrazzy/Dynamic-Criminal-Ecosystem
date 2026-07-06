/**
 * DCE Control Center - Settings Module
 */

(function() {
    'use strict';
    window.DCE = window.DCE || {};
    DCE.Modules = DCE.Modules || {};

    DCE.Modules.settings = {
        configs: {},

        render: function(container) {
            container.innerHTML = '\
                <div class="card-header" style="margin-bottom: 12px;">Configuration Editor</div>\
                <div id="settings-sections">Loading configuration...</div>';
            
            this.loadData();
        },

        loadData: async function() {
            var data = await DCE.API.getConfigs();
            this.configs = data || {};
            this.renderSections();
        },

        renderSections: function() {
            var container = document.getElementById('settings-sections');
            if (!container) return;

            var html = '<div style="display: grid; gap: 12px;">';

            Object.keys(this.configs).forEach(function(resource) {
                var config = this.configs[resource];
                html += '<div class="card">\
                    <div class="card-header">' + resource + '</div>\
                    <div class="config-editor" data-resource="' + resource + '"></div>\
                </div>';
            }.bind(this));

            html += '</div>';
            container.innerHTML = html;
        }
    };
})();