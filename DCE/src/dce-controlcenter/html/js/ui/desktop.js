/**
 * DCE Control Center v2 - Desktop Manager
 * 
 * Created on-demand by ApplicationManager.Boot()
 * Never exists until /dce command is processed
 * 
 * Owns: DOM elements for desktop UI only
 */

(function() {
    'use strict';
    
    // DCE namespace
    window.DCE = window.DCE || {};
    
    const DESKTOP_STATES = {
        HIDDEN: 'hidden',
        VISIBLE: 'visible'
    };
    
    // Desktop manager - lazy instantiated
    DCE.Desktop = DCE.Desktop || {
        state: DESKTOP_STATES.HIDDEN,
        _element: null,
        
        // Create desktop DOM elements (called by ApplicationManager.Boot)
        create: function() {
            if (DCE.Desktop._element) {
                return true; // Already exists
            }
            
            console.log('[DCE Desktop] Creating desktop elements...');
            
            // Create desktop container
            const desktop = document.createElement('div');
            desktop.id = 'desktop';
            desktop.className = 'desktop';
            desktop.innerHTML = `
                <header class="application-header">
                    <div class="application-identity">
                        <div class="application-title">DCE Control Center</div>
                        <div class="application-subtitle">Operations overview</div>
                    </div>
                    <button type="button" id="close-control-center" class="close-control-center" aria-label="Close Control Center">Close</button>
                </header>
                <div class="application-workspace">
                    <nav id="dock" class="dock" aria-label="Control Center navigation">
                        <div class="dock-content"></div>
                    </nav>
                    <main id="application-content" class="application-content" tabindex="-1">
                        <div class="loading">Loading Control Center...</div>
                    </main>
                </div>
                <div id="status-bar" class="status-bar">
                    <div class="status-section left">
                        <span class="status-indicator ready" id="status-indicator"></span>
                        <span id="status-text">Ready</span>
                    </div>
                    <div class="status-section center">
                        <span id="breadcrumb"></span>
                    </div>
                    <div class="status-section right">
                        <span id="status-timestamp"></span>
                        <span class="status-version">DCE SDK v1.0.0</span>
                    </div>
                </div>
                <div id="notifications" class="notifications"></div>
                <div id="modal-overlay" class="modal-overlay hidden"></div>
            `;
            
            document.body.appendChild(desktop);
            DCE.Desktop._element = desktop;

            document.getElementById('close-control-center').addEventListener('click', function() {
                DCE.Desktop.requestClose('close');
            });
            document.addEventListener('keydown', DCE.Desktop.handleKeydown);
            
            console.log('[DCE Desktop] Desktop created');
            return true;
        },
        
        // Open desktop (make visible after focus)
        open: function() {
            if (!DCE.Desktop._element) {
                console.error('[DCE Desktop] Cannot open - not created');
                return false;
            }
            
            console.log('[DCE Desktop] Opening desktop...');
            DCE.Desktop.state = DESKTOP_STATES.VISIBLE;
            DCE.Desktop._closeRequested = false;
            
            // CSS class handles visibility (body.cc-active makes UI visible)
            document.body.className = 'cc-active';
            
            return true;
        },
        
        // Close desktop (hide but keep DOM for next activation)
        close: function() {
            console.log('[DCE Desktop] Closing desktop...');
            DCE.Desktop.state = DESKTOP_STATES.HIDDEN;
        },
        
        // Destroy desktop (remove DOM)
        destroy: function() {
            if (DCE.Desktop._element) {
                DCE.Desktop._element.remove();
                DCE.Desktop._element = null;
            }
            DCE.Desktop.state = DESKTOP_STATES.HIDDEN;
        },
        
        // Get desktop state
        getState: function() {
            return DCE.Desktop.state;
        },
        
        // Get element
        getElement: function() {
            return DCE.Desktop._element;
        },

        _closeRequested: false,

        requestClose: function(action) {
            if (DCE.Desktop._closeRequested || DCE.Desktop.state !== DESKTOP_STATES.VISIBLE) return;
            DCE.Desktop._closeRequested = true;
            DCE.NUI.post('dce-cc:nui:' + action, {}).catch(function() {
                DCE.Desktop._closeRequested = false;
                if (DCE.Notifications && DCE.Notifications.error) {
                    DCE.Notifications.error('Unable to close the Control Center.');
                }
            });
        },

        handleKeydown: function(event) {
            if (event.key !== 'Escape' || DCE.Desktop.state !== DESKTOP_STATES.VISIBLE) return;

            if (DCE.Plugins && DCE.Plugins['world-manager'] && DCE.Plugins['world-manager'].cancelPlacement) {
                if (DCE.Plugins['world-manager'].cancelPlacement()) {
                    event.preventDefault();
                    return;
                }
            }

            if (DCE.CommandPalette && DCE.CommandPalette._visible) {
                DCE.CommandPalette.hide();
                return;
            }

            var modalOverlay = document.getElementById('modal-overlay');
            if (modalOverlay && !modalOverlay.classList.contains('hidden')) {
                modalOverlay.classList.add('hidden');
                modalOverlay.replaceChildren();
                return;
            }

            DCE.Desktop.requestClose('escape');
        },

        navigate: function(destination) {
            var content = document.getElementById('application-content');
            var breadcrumb = document.getElementById('breadcrumb');
            var statusText = document.getElementById('status-text');
            var pageLabels = {
                'world-manager': 'World',
                'organization-manager': 'Organizations',
                'scenario-manager': 'Scenarios',
                'dispatch-manager': 'Dispatch',
                'evidence-manager': 'Evidence',
                'economy-manager': 'Economy',
                'ai-manager': 'Intelligence',
                'configuration': 'Configuration',
                'integrations': 'Integrations',
                'runtime': 'Runtime',
                'diagnostics': 'Diagnostics'
            };
            var unavailablePages = {
                integrations: 'Adapter discovery and administration are not exposed by the available V1 contracts.',
                runtime: 'Detailed service, plugin, scheduler, and session inspection is not exposed by the available V1 contracts.',
                diagnostics: 'Diagnostic history and developer tools are not exposed by the available V1 contracts.'
            };
            if (!content) return false;

            if (destination === 'home') {
                var pluginManager = DCE.Plugins && DCE.Plugins.Manager;
                var plugins = pluginManager && pluginManager.listPlugins ? pluginManager.listPlugins() : [];
                var startedCount = plugins.filter(function(plugin) { return plugin.state === 'started'; }).length;
                content.innerHTML =
                    '<section class="home-view">' +
                        '<h1>Home</h1>' +
                        '<p class="page-description">A clear view of this Control Center session and the DCE information currently available.</p>' +
                        '<div class="overview-grid">' +
                            '<article class="overview-item"><span class="overview-label">Control Center</span><strong>Connected</strong></article>' +
                            '<article class="overview-item"><span class="overview-label">DCE Runtime</span><strong>Runtime status unavailable</strong></article>' +
                            '<article class="overview-item"><span class="overview-label">Active modules</span><strong>' + startedCount + ' available</strong></article>' +
                            '<article class="overview-item"><span class="overview-label">Scenarios</span><strong>No scenario data available</strong></article>' +
                        '</div>' +
                        '<section class="quick-actions" aria-labelledby="quick-actions-title">' +
                            '<h2 id="quick-actions-title">Quick actions</h2>' +
                            '<div><button type="button" class="btn" data-destination="world-manager">View world status</button></div>' +
                        '</section>' +
                        '<section class="state-list" aria-label="DCE data availability">' +
                            '<div><strong>Organizations</strong><span>Organization data is not currently available.</span></div>' +
                            '<div><strong>Dispatch</strong><span>No dispatch data is currently available.</span></div>' +
                            '<div><strong>Evidence</strong><span>No evidence data is currently available.</span></div>' +
                            '<div><strong>Economy</strong><span>Economy data is currently unavailable.</span></div>' +
                            '<div><strong>Intelligence</strong><span>Intelligence data is currently unavailable.</span></div>' +
                        '</section>' +
                    '</section>';
                content.querySelectorAll('[data-destination]').forEach(function(button) {
                    button.addEventListener('click', function() {
                        DCE.Desktop.navigate(button.getAttribute('data-destination'));
                    });
                });
                if (breadcrumb) breadcrumb.textContent = 'Home';
                if (statusText) statusText.textContent = 'Active';
            } else if (destination === 'configuration') {
                content.innerHTML =
                    '<section class="page-state"><h1>Configuration</h1>' +
                    '<p>Loading server configuration capabilities...</p></section>';
                if (breadcrumb) breadcrumb.textContent = 'Configuration';
                if (statusText) statusText.textContent = 'Loading';
                DCE.NUI.post('configuration:get', {}).then(function(response) {
                    if (!response || response.status !== 'ok') {
                        content.innerHTML = '<section class="page-state unavailable"><h1>Configuration</h1><p>' +
                            ((response && response.message) || 'Runtime configuration editing is not backed by a V1 server contract.') +
                            '</p></section>';
                        if (statusText) statusText.textContent = 'Unavailable';
                        return;
                    }
                    var targets = response.targets || [];
                    var items = targets.length ? targets.map(function(target) {
                        var details = (target.actions || []).join(', ') || 'No hot actions';
                        var state = target.restartRequired ? 'Restart required' : target.state;
                        return '<div><strong>' + target.target + '</strong><span>' + state + ': ' + details + '</span></div>';
                    }).join('') : '<div><strong>No editable targets</strong><span>No V1 configuration target is currently registered.</span></div>';
                    content.innerHTML = '<section class="page-state"><h1>Configuration</h1><section class="state-list">' + items +
                        '</section><div class="quick-actions"><div><button type="button" class="btn" data-destination="world-manager">Manage world locations</button></div></div></section>';
                    content.querySelector('[data-destination="world-manager"]').addEventListener('click', function() {
                        DCE.Desktop.navigate('world-manager');
                    });
                    if (statusText) statusText.textContent = targets.length ? 'Active' : 'Unavailable';
                }).catch(function() {
                    content.innerHTML = '<section class="page-state unavailable"><h1>Configuration</h1><p>Unable to read authoritative configuration capabilities.</p></section>';
                    if (statusText) statusText.textContent = 'Unavailable';
                });
            } else {
                var plugin = DCE.Plugins && DCE.Plugins[destination];
                if (!plugin || !plugin.render) {
                    var message = unavailablePages[destination] || 'This Control Center section is not available.';
                    content.innerHTML = '<section class="page-state unavailable"><h1>' + (pageLabels[destination] || destination) + '</h1><p>' + message + '</p></section>';
                    if (breadcrumb) breadcrumb.textContent = pageLabels[destination] || destination;
                    if (statusText) statusText.textContent = 'Unavailable';
                    if (DCE.Dock && DCE.Dock.setActive) DCE.Dock.setActive(destination);
                    return false;
                }

                content.innerHTML = '<div class="page-heading"><h1></h1></div><div class="plugin-content"></div>';
                content.querySelector('h1').textContent = pageLabels[destination] || plugin.displayName || plugin.name || destination;
                plugin.render(content.querySelector('.plugin-content'));
                if (breadcrumb) breadcrumb.textContent = pageLabels[destination] || plugin.displayName || plugin.name || destination;
                if (statusText) statusText.textContent = 'Active';
            }

            if (DCE.Dock && DCE.Dock.setActive) DCE.Dock.setActive(destination);
            content.focus();
            return true;
        }
    };
    
})();