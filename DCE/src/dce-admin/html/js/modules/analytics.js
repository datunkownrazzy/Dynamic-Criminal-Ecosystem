/**
 * DCE Control Center - Analytics Module
 * Real-time Chart.js integration via EventBus
 */

(function() {
    'use strict';
    window.DCE = window.DCE || {};
    DCE.Modules = DCE.Modules || {};

    DCE.Modules.analytics = {
        chartInstances: {},
        metricsData: {
            eventbus: { throughput: [], errors: [] },
            scheduler: { activeTasks: 0, executionTime: 0 },
            ai: { decisionsPerSecond: 0, population: 0 },
            organization: { active: 0, heat: {} },
            dispatch: { activeCalls: 0, responseTime: 0 }
        },

        render: function(container) {
            container.innerHTML = '\
                <div class="card-header" style="margin-bottom: 12px;">EventBus Metrics</div>\
                <div style="margin-bottom: 20px;">\
                    <canvas id="chart-eventbus" height="150"></canvas>\
                </div>\
                <div class="card-header" style="margin-bottom: 12px;">Scheduler Performance</div>\
                <div style="margin-bottom: 20px;">\
                    <canvas id="chart-scheduler" height="150"></canvas>\
                </div>\
                <div class="card-header" style="margin-bottom: 12px;">Organization Activity</div>\
                <div style="margin-bottom: 20px;">\
                    <canvas id="chart-org-activity" height="150"></canvas>\
                </div>\
                <div class="card-header" style="margin-bottom: 12px;">Dispatch Metrics</div>\
                <div style="margin-bottom: 20px;">\
                    <canvas id="chart-dispatch" height="150"></canvas>\
                </div>\
                <div class="card-header" style="margin-bottom: 12px;">Performance Overview</div>\
                <div style="margin-bottom: 20px;">\
                    <canvas id="chart-performance" height="150"></canvas>\
                </div>';
            
            this.initializeCharts();
            this.subscribeToEvents();
        },

        initializeCharts: function() {
            // EventBus Chart
            var eventbusCtx = document.getElementById('chart-eventbus');
            if (eventbusCtx) {
                this.chartInstances.eventbus = new Chart(eventbusCtx, {
                    type: 'line',
                    data: {
                        labels: [],
                        datasets: [{
                            label: 'Throughput (events/sec)',
                            data: [],
                            borderColor: '#58a6ff',
                            backgroundColor: 'rgba(88, 166, 255, 0.1)',
                            tension: 0.3,
                            fill: true
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        animation: false,
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

            // Scheduler Chart
            var schedulerCtx = document.getElementById('chart-scheduler');
            if (schedulerCtx) {
                this.chartInstances.scheduler = new Chart(schedulerCtx, {
                    type: 'bar',
                    data: {
                        labels: ['Active', 'Queued', 'Errors'],
                        datasets: [{
                            data: [0, 0, 0],
                            backgroundColor: ['#58a6ff', '#3fb950', '#f85149']
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        animation: false,
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

            // Organization Activity Chart
            var orgCtx = document.getElementById('chart-org-activity');
            if (orgCtx) {
                this.chartInstances.orgActivity = new Chart(orgCtx, {
                    type: 'line',
                    data: {
                        labels: [],
                        datasets: [{
                            label: 'Organizations',
                            data: [],
                            borderColor: '#3fb950',
                            backgroundColor: 'rgba(63, 185, 80, 0.1)',
                            tension: 0.3,
                            fill: true
                        }, {
                            label: 'Avg Heat',
                            data: [],
                            borderColor: '#f85149',
                            backgroundColor: 'rgba(248, 81, 73, 0.1)',
                            tension: 0.3,
                            fill: true
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        animation: false,
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

            // Dispatch Chart
            var dispatchCtx = document.getElementById('chart-dispatch');
            if (dispatchCtx) {
                this.chartInstances.dispatch = new Chart(dispatchCtx, {
                    type: 'doughnut',
                    data: {
                        labels: ['Active', 'Pending', 'Completed'],
                        datasets: [{
                            data: [0, 0, 0],
                            backgroundColor: ['#58a6ff', '#d29922', '#3fb950']
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        animation: false,
                        plugins: {
                            legend: { position: 'bottom' }
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
                            data: [0, 0, 0],
                            backgroundColor: ['#58a6ff', '#f85149', '#3fb950']
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        animation: false,
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
        },

        subscribeToEvents: function() {
            if (!DCE.EventHandler) return;
            
            // EventBus metrics subscription
            DCE.EventHandler.subscribe('eventbus:metrics:updated', function(payload) {
                DCE.Modules.analytics.updateEventbusMetrics(payload);
            });

            // Scheduler task execution subscription
            DCE.EventHandler.subscribe('scheduler:task:executed', function(payload) {
                DCE.Modules.analytics.updateSchedulerMetrics(payload);
            });

            // Organization metrics subscription
            DCE.EventHandler.subscribe('organization:state:changed', function(payload) {
                DCE.Modules.analytics.updateOrganizationMetrics(payload);
            });

            // Dispatch metrics subscription
            DCE.EventHandler.subscribe('dispatch:call:created', function(payload) {
                DCE.Modules.analytics.updateDispatchMetrics(payload);
            });
        },

        updateEventbusMetrics: function(payload) {
            if (!this.chartInstances.eventbus) return;
            
            var chart = this.chartInstances.eventbus;
            var now = new Date().toLocaleTimeString();
            
            chart.data.labels.push(now);
            chart.data.datasets[0].data.push((payload.throughput || 0));
            
            // Keep last 20 data points
            if (chart.data.labels.length > 20) {
                chart.data.labels.shift();
                chart.data.datasets[0].data.shift();
            }
            
            chart.update('none');
        },

        updateSchedulerMetrics: function(payload) {
            if (!this.chartInstances.scheduler) return;
            
            this.chartInstances.scheduler.data.datasets[0].data = [
                (payload.activeTasks || 0),
                (payload.queued || 0),
                (payload.errors || 0)
            ];
            this.chartInstances.scheduler.update('none');
        },

        updateOrganizationMetrics: function(payload) {
            if (!this.chartInstances.orgActivity) return;
            
            var chart = this.chartInstances.orgActivity;
            var now = new Date().toLocaleTimeString();
            
            chart.data.labels.push(now);
            chart.data.datasets[0].data.push((payload.organizationCount || 0));
            chart.data.datasets[1].data.push((payload.avgHeat || 0));
            
            if (chart.data.labels.length > 20) {
                chart.data.labels.shift();
                chart.data.datasets[0].data.shift();
                chart.data.datasets[1].data.shift();
            }
            
            chart.update('none');
        },

        updateDispatchMetrics: function(payload) {
            if (!this.chartInstances.dispatch) return;
            
            this.chartInstances.dispatch.data.datasets[0].data = [
                (payload.activeCalls || 0),
                (payload.pendingCalls || 0),
                (payload.completedCalls || 0)
            ];
            this.chartInstances.dispatch.update('none');
        },

        updatePerformanceChart: function(data) {
            if (!this.chartInstances.performance || !data) return;
            
            var perfData = data.performance || {};
            this.chartInstances.performance.data.datasets[0].data = [
                (perfData.activeTasks || 0),
                (perfData.totalErrors || 0),
                ((data.organizations || []).length)
            ];
            this.chartInstances.performance.update('none');
        }
    };
})();