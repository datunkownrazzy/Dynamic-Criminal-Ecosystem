/**
 * DCE Control Center v2 - Dispatch Manager Plugin
 * Manage dispatch zones, stations, and incident zones
 */

(function() {
    'use strict';

    window.DCE = window.DCE || {};
    DCE.Plugins = DCE.Plugins || {};

    DCE.Plugins['dispatch-manager'] = {
        render: function(container) {
            container.innerHTML = `
                <div class="card">
                    <div class="card-header">Dispatch Manager</div>
                    <div class="tab-bar">
                        <button class="tab active" data-tab="stations">Stations</button>
                        <button class="tab" data-tab="zones">Zones</button>
                        <button class="tab" data-tab="incidents">Incidents</button>
                    </div>
                    <div id="dispatch-content" style="margin-top: 12px;">
                        <div class="loading">Loading dispatch data...</div>
                    </div>
                </div>
            `;
        }
    };

})();