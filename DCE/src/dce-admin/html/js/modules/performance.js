/**
 * DCE Control Center - Performance Module
 */

(function() {
    'use strict';
    window.DCE = window.DCE || {};
    DCE.Modules = DCE.Modules || {};

    DCE.Modules.performance = {
        tasks: [],

        render: function(container) {
            container.innerHTML = '\
                <div class="card-header" style="margin-bottom: 12px;">Task Scheduler</div>\
                <table class="data-table">\
                    <thead>\
                        <tr>\
                            <th>Task Name</th>\
                            <th>Interval</th>\
                            <th>Status</th>\
                            <th>Errors</th>\
                            <th>Runs</th>\
                        </tr>\
                    </thead>\
                    <tbody id="tasks-body">\
                        <tr><td colspan="5" class="loading">Loading...</td></tr>\
                    </tbody>\
                </table>';
            
            this.loadData();
        },

        loadData: async function() {
            this.tasks = await DCE.API.getTasks();
            this.renderTable();
        },

        renderTable: function() {
            var tbody = document.getElementById('tasks-body');
            if (!tbody) return;

            if (this.tasks.length === 0) {
                tbody.innerHTML = '<tr><td colspan="5" class="loading">No scheduled tasks</td></tr>';
                return;
            }

            var html = '';
            this.tasks.forEach(function(task) {
                html += '<tr>\
                    <td>' + (task.name || '') + '</td>\
                    <td>' + (task.interval || 0) + 'ms</td>\
                    <td>' + (task.running ? 'Running' : 'Idle') + '</td>\
                    <td>' + (task.errorCount || 0) + '</td>\
                    <td>' + (task.runCount || 0) + '</td>\
                </tr>';
            });
            
            tbody.innerHTML = html;
        }
    };
})();