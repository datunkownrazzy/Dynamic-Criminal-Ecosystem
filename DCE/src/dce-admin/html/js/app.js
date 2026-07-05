// DCE Admin Dashboard - Vanilla JS Application
// Performance-optimized, minimal footprint

(function() {
    'use strict';

    // State
    let currentView = 'overview';
    let refreshTimer = null;
    let dataCache = {};

    // Elements
    const elements = {
        tabs: document.querySelectorAll('.tab-btn'),
        views: document.querySelectorAll('.view'),
        refreshBtn: document.getElementById('refreshBtn'),
        timestamp: document.querySelector('.timestamp'),
        debugCommand: document.getElementById('debug-command'),
        debugExec: document.getElementById('debug-exec'),
        debugOutput: document.getElementById('debug-output'),
    };

    // Fetch data from server via NUI callback
    async function fetchDashboardData() {
        const resp = await fetch(`https://${GetParentResourceName()}/getDashboardData`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
        const data = await resp.json();
        dataCache = data;
        renderOverview(data);
        return data;
    }

    async function fetchOrganizations() {
        const resp = await fetch(`https://${GetParentResourceName()}/getOrganizations`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
        const orgs = await resp.json();
        renderOrganizations(orgs);
        return orgs;
    }

    async function fetchIncidents() {
        const resp = await fetch(`https://${GetParentResourceName()}/getIncidents`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
        const incidents = await resp.json();
        renderIncidents(incidents);
        return incidents;
    }

    async function fetchTasks() {
        const resp = await fetch(`https://${GetParentResourceName()}/getTasks`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
        const tasks = await resp.json();
        renderTasks(tasks);
        return tasks;
    }

    async function fetchServices() {
        const resp = await fetch(`https://${GetParentResourceName()}/getServices`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
        const services = await resp.json();
        renderServices(services);
        return services;
    }

    async function executeDebug(command) {
        const resp = await fetch(`https://${GetParentResourceName()}/executeDebug`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ command, args: [] })
        });
        const result = await resp.json();
        renderDebugResult(result);
        return result;
    }

    // Render functions
    function renderOverview(data) {
        if (!data) return;
        
        document.getElementById('stat-tasks').textContent = data.performance?.activeTasks || 0;
        document.getElementById('stat-errors').textContent = data.performance?.totalErrors || 0;
        document.getElementById('stat-orgs').textContent = (data.organizations || []).length;
        document.getElementById('stat-incidents').textContent = (data.incidents || []).length;
        
        if (data.timestamp) {
            const date = new Date(data.timestamp * 1000);
            elements.timestamp.textContent = date.toLocaleTimeString();
        }
    }

    function renderOrganizations(orgs) {
        const tbody = document.getElementById('orgs-table');
        if (!orgs || orgs.length === 0) {
            tbody.innerHTML = '<tr><td colspan="7" class="loading">No organizations found</td></tr>';
            return;
        }

        tbody.innerHTML = orgs.map(org => `
            <tr>
                <td>${escapeHtml(org.name || 'Unknown')}</td>
                <td>${escapeHtml(org.type || 'Unknown')}</td>
                <td>${escapeHtml(org.state || 'Unknown')}</td>
                <td>${org.members || 0}</td>
                <td>$${org.money?.toLocaleString() || 0}</td>
                <td>${org.heat || 0}</td>
                <td>${org.morale || 0}</td>
            </tr>
        `).join('');
    }

    function renderIncidents(incidents) {
        const tbody = document.getElementById('incidents-table');
        if (!incidents || incidents.length === 0) {
            tbody.innerHTML = '<tr><td colspan="6" class="loading">No active incidents</td></tr>';
            return;
        }

        tbody.innerHTML = incidents.map(inc => `
            <tr>
                <td>${escapeHtml(inc.id || '')}</td>
                <td>${escapeHtml(inc.organizationId || 'Unknown')}</td>
                <td>${escapeHtml(inc.activity || '')}</td>
                <td>${escapeHtml(inc.stage || '')}</td>
                <td>${escapeHtml(inc.state || '')}</td>
                <td>${escapeHtml(inc.regionId || '')}</td>
            </tr>
        `).join('');
    }

    function renderTasks(tasks) {
        const tbody = document.getElementById('tasks-table');
        if (!tasks || tasks.length === 0) {
            tbody.innerHTML = '<tr><td colspan="5" class="loading">No scheduled tasks</td></tr>';
            return;
        }

        tbody.innerHTML = tasks.map(task => `
            <tr>
                <td>${escapeHtml(task.name || '')}</td>
                <td>${task.interval || 0}ms</td>
                <td>${task.running ? 'Running' : 'Idle'}</td>
                <td>${task.errorCount || 0}</td>
                <td>${task.runCount || 0}</td>
            </tr>
        `).join('');
    }

    function renderServices(services) {
        const container = document.getElementById('services-list');
        if (!services || services.length === 0) {
            container.innerHTML = '<div class="loading">No services registered</div>';
            return;
        }

        container.innerHTML = services.map(svc => `
            <div class="service-card">
                <h4><span class="service-status ${svc.running ? 'active' : 'inactive'}"></span>${escapeHtml(svc.name || '')}</h4>
                <p>Tasks: ${svc.tasks || 0}</p>
            </div>
        `).join('');
    }

    function renderDebugResult(result) {
        const line = document.createElement('div');
        line.className = `debug-line ${result.success ? 'success' : 'error'}`;
        line.textContent = result.message || JSON.stringify(result.output || result);
        
        // Keep only last 50 lines
        while (elements.debugOutput.children.length > 50) {
            elements.debugOutput.removeChild(elements.debugOutput.firstChild);
        }
        
        elements.debugOutput.appendChild(line);
        elements.debugOutput.scrollTop = elements.debugOutput.scrollHeight;
    }

    // Utility
    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    // View switching
    function switchView(viewName) {
        currentView = viewName;
        
        // Update tabs
        elements.tabs.forEach(btn => {
            btn.classList.toggle('active', btn.dataset.view === viewName);
        });
        
        // Update views
        elements.views.forEach(view => {
            view.classList.toggle('active', view.id === `view-${viewName}`);
        });
        
        // Load view-specific data
        switch(viewName) {
            case 'overview':
                fetchDashboardData();
                break;
            case 'organizations':
                fetchOrganizations();
                break;
            case 'incidents':
                fetchIncidents();
                break;
            case 'performance':
                fetchTasks();
                break;
            case 'services':
                fetchServices();
                break;
            default:
                // Unknown view - do nothing
                break;
        }
    }

    // Event listeners
    function init() {
        // Tab switching
        elements.tabs.forEach(btn => {
            btn.addEventListener('click', () => switchView(btn.dataset.view));
        });

        // Refresh button
        if (elements.refreshBtn) {
            elements.refreshBtn.addEventListener('click', () => {
                fetchDashboardData();
            });
        }

        // Debug console
        if (elements.debugExec && elements.debugCommand) {
            elements.debugExec.addEventListener('click', () => {
                const cmd = elements.debugCommand.value.trim();
                if (cmd) {
                    executeDebug(cmd);
                    elements.debugCommand.value = '';
                }
            });

            elements.debugCommand.addEventListener('keypress', (e) => {
                if (e.key === 'Enter') {
                    elements.debugExec.click();
                }
            });
        }

        // Initial load
        fetchDashboardData();
    }

    // Initialize when DOM ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

    // Expose for debugging
    window.DCEDebug = { switchView, refresh: fetchDashboardData };
})();