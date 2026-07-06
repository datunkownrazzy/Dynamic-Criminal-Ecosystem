/**
 * DCE Control Center - Analytics Module
 * Chart.js integration for data visualization
 */

(function() {
    'use strict';
    window.DCE = window.DCE || {};
    DCE.Modules = DCE.Modules || {};

    DCE.Modules.analytics = {
        chartInstances: {},

        render: function(container) {
            container.innerHTML = '\
                <div class="card-header" style="margin-bottom: 12px;">Organization Activity</div>\
                <div style="margin-bottom: 20px;">\
                    <canvas id="chart-org-activity" height="200"></canvas>\
                </div>\
                <div class="card-header" style="margin-bottom: 12px;">Performance Metrics</div>\
                <div style="margin-bottom: 20px;">\
                    <canvas id="chart-performance" height="200"></canvas>\
                </div>';
            
            this.loadData();
        },

        loadData: async function() {
            var data = await DCE.API.getDashboardData();
            this.renderCharts(data);
        },

        renderCharts: function(data) {
            if (!data) return;

            // Organization Activity Chart
            var orgCtx = document.getElementById('chart-org-activity');
            if (orgCtx) {
                this.chartInstances.orgActivity = new Chart(orgCtx, {
                    type: 'line',
                    data: {
                        labels: ['Robberies', 'Shootings', 'Drug Activity', 'Gang Influence'],
                        datasets: [{
                            label: 'Activity Level',
                            data: [12, 5, 18, 8],
                            borderColor: '#58a6ff',
                            backgroundColor: 'rgba(88, 166, 255, 0.1)',
                            tension: 0.3
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        plugins: {
                            legend: { display: false }
                        },
                        scales: {
                            y: {
                                beginAtZero: true,
                                grid: { color: 'rgba(255,255,255,0.05)' }
                            }
                        }
                    }
                });
            }

            // Performance Chart
            var perfCtx = document.getElementById('chart-performance');
            if (perfCtx) {
                this.chartInstances.performance = new Chart(perfCtx, {
                    type: 'bar',
                    data: {
                        labels: ['Tasks', 'Errors', 'Services'],
                        datasets: [{
                            label: 'Count',
                            data: [
                                data.performance?.activeTasks || 0,
                                data.performance?.totalErrors || 0,
                                (data.organizations || []).length
                            ],
                            backgroundColor: ['#58a6ff', '#f85149', '#3fb950']
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        plugins: {
                            legend: { display: false }
                        },
                        scales: {
                            y: {
                                beginAtZero: true,
                                grid: { color: 'rgba(255,255,255,0.05)' }
                            }
                        }
                    }
                });
            }
        }
    };
})();