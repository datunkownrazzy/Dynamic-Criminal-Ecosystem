/**
 * DCE Control Center - World Editor Module
 * Unified world editing interface
 */

(function() {
    'use strict';
    window.DCE = window.DCE || {};
    DCE.Modules = DCE.Modules || {};

    DCE.Modules['world-editor'] = {
        render: function(container) {
            container.innerHTML = '\
                <div class="card-header">World Editor</div>\
                <div class="stats-grid" style="grid-template-columns: repeat(3, 1fr);">\
                    <div class="card stat-item" style="cursor: pointer;" id="open-locations">\
                        <div class="stat-value">📍</div>\
                        <div class="stat-label">Locations</div>\
                    </div>\
                    <div class="card stat-item" style="cursor: pointer;" id="open-territories">\
                        <div class="stat-value">🗺️</div>\
                        <div class="stat-label">Territories</div>\
                    </div>\
                    <div class="card stat-item" style="cursor: pointer;" id="open-org-editor">\
                        <div class="stat-value">🏢</div>\
                        <div class="stat-label">Organizations</div>\
                    </div>\
                </div>\
                <div class="card" style="margin-top: 12px;">\
                    <div class="card-header">Quick Actions</div>\
                    <div style="display: flex; gap: 8px; flex-wrap: wrap;">\
                        <button class="btn" id="btn-capture-pos">Capture Position</button>\
                        <button class="btn secondary" id="btn-preview-mode">Preview Mode</button>\
                        <button class="btn secondary" id="btn-undo">Undo</button>\
                        <button class="btn secondary" id="btn-redo">Redo</button>\
                    </div>\
                </div>\
                <div class="card" style="margin-top: 12px;">\
                    <div class="card-header">Recent Changes</div>\
                    <div id="recent-changes" style="max-height: 200px; overflow-y: auto;">\
                        <div class="loading">No recent changes</div>\
                    </div>\
                </div>';
            
            this.bindEvents();
        },

        bindEvents: function() {
            var self = this;

            document.getElementById('open-locations').addEventListener('click', function() {
                DCE.Windows.create('locations');
            });

            document.getElementById('open-territories').addEventListener('click', function() {
                DCE.Windows.create('territories');
            });

            document.getElementById('open-org-editor').addEventListener('click', function() {
                DCE.Windows.create('organizations');
            });

            document.getElementById('btn-capture-pos').addEventListener('click', function() {
                DCE.NUI.post('capturePosition', {});
                DCE.Notifications.info('Position capture requested - check server logs');
            });

            document.getElementById('btn-preview-mode').addEventListener('click', function() {
                DCE.Notifications.info('Preview mode toggled');
            });

            document.getElementById('btn-undo').addEventListener('click', function() {
                DCE.Notifications.info('Undo activated');
            });

            document.getElementById('btn-redo').addEventListener('click', function() {

                DCE.Notifications.info('Redo activated');
            });
        }
    };
})();