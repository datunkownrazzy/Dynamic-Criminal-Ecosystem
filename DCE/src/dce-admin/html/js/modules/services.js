/**
 * DCE Control Center - Services Module
 */

(function() {
    'use strict';
    window.DCE = window.DCE || {};
    DCE.Modules = DCE.Modules || {};

    DCE.Modules.services = {
        render: function(container) {
            container.innerHTML = '\
                <div class="stats-grid" id="services-grid">\
                    <div class="loading">Loading services...</div>\
                </div>';
            
            this.loadData();
        },

        loadData: async function() {
            var services = await DCE.API.getServices();
            this.renderServices(services);
        },

        renderServices: function(services) {
            var grid = document.getElementById('services-grid');
            if (!grid) return;

            if (services.length === 0) {
                grid.innerHTML = '<div class="loading">No services registered</div>';
                return;
            }

            var html = '';
            services.forEach(function(svc) {
                html += '<div class="card">\
                    <div class="card-header">' + (svc.name || '') + '</div>\
                    <div>Tasks: ' + (svc.tasks || 0) + '</div>\
                </div>';
            });
            
            grid.innerHTML = html;
        }
    };
})();