# Service Lifecycle Framework

**Version:** 1.0.0
**Status:** FROZEN
**Sprint:** 1.9

## Lifecycle States

```
UNKNOWN → CREATED → INITIALIZED → STARTING → RUNNING → READY
                                                    ↓
                                              DEGRADED
                                                    ↓
                                              STOPPING → STOPPED
                                              FAILED
```

## Valid Transitions

| From | To |
|------|-----|
| UNKNOWN | CREATED, FAILED |
| CREATED | INITIALIZED, FAILED |
| INITIALIZED | STARTING, STOPPED, FAILED |
| STARTING | RUNNING, DEGRADED, FAILED |
| RUNNING | READY, DEGRADED, STOPPING, FAILED |
| READY | RUNNING, DEGRADED, STOPPING, FAILED |
| DEGRADED | RUNNING, STOPPING, FAILED |
| STOPPING | STOPPED, FAILED |
| STOPPED | INITIALIZED, CREATED, FAILED |
| FAILED | CREATED, STOPPED |

## Required Methods

Every service must support:
- `Initialize()` — allocate resources, validate dependencies
- `Start()` — begin processing, register event handlers
- `Ready()` — signal readiness, emit ready event
- `Shutdown()` — graceful stop, flush pending work
- `Dispose()` — release all resources
- `Restart()` — full restart cycle
- `FailureRecovery()` — attempt recovery from degraded state

## Registry Integration

Services are registered via `ServiceLifecycle.Register(name, implementation)`, which:
1. Creates a lifecycle-managed instance
2. Registers with DCE service registry via `DCE.RegisterService()`
3. Makes lifecycle methods available through the registry

## Events

Lifecycle transitions emit `lifecycle:service:stateChanged` with payload:
- `payload.service` — service name
- `payload.from` — previous state
- `payload.to` — new state
- `payload.reason` — transition reason