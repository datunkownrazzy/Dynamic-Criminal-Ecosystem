# Sprint 1.10.8 — Runtime Observatory

## Purpose

The Runtime Observatory is a permanent runtime observability framework that allows an external runtime analyst to determine exactly what occurred during startup using only the FiveM server console output. No source code is required.

## Architecture

### File Location

`DCE/src/dce-core/runtime/observatory.lua`

### Registration

The module registers itself as `_G.DCERuntimeObservatory` and is loaded via `fxmanifest.lua` in both `server_scripts` and `client_scripts`.

### Execution

The Runtime Observatory executes **automatically** on every clean server startup. It is called from:
1. **Server**: `dce-core/init.lua` — `ReadyPhase()` function, after SDK identity verification, before export validation
2. **Client**: `dce-core/client/init.lua` — `InitializeCore()` function, after service registration, before marking ready

There are no commands, debug modes, or manual activation required.

## Logging Profiles

The observatory respects three logging profiles:

| Profile       | Displayed Sections                          | Configuration                     |
|---------------|---------------------------------------------|-----------------------------------|
| **Production** | Header, Errors, Runtime Summary             | `_G.DCE.ObservatoryProfile = "production"` |
| **Development**| Header, Boot Pipeline, Errors, Summary      | `_G.DCE.ObservatoryProfile = "development"` (default) |
| **Verbose**    | Complete 15-section Runtime Observatory     | `_G.DCE.ObservatoryProfile = "verbose"` |

Configuration precedence:
1. `_G.DCE.ObservatoryProfile`
2. `_G.DCE_ObservatoryProfile` (global variable)
3. `_G.Config.Observatory.Profile` (config table)
4. Default: `"development"`

## Architectural Rules

1. **Every reported PASS must come from an actual runtime verification.**
   - The observatory reads `_G.DCERegistry`, `_G.DCE_FROZEN_SDK`, `_G.DCEBootTimeline`, etc. at runtime.
   - It never assumes a service is initialized based on source code.

2. **If runtime verification cannot be performed, display UNKNOWN. Never PASS.**
   - Example: If the EventBus has no `GetMetrics` function, `UNKNOWN` is displayed for subscriptions.
   - Example: If `_G.DCE_FROZEN_SDK` is nil, `FAIL` is displayed for the SDK audit.

3. **Never add logging simply to show PASS.**
   - Every PASS corresponds to a service being found, a function being callable, etc.

4. **Source code is not proof. Only runtime evidence is proof.**
   - The framework never inspects source files. It only reads runtime globals and calls runtime functions.

5. **This framework is read-only. It never modifies runtime state.**
   - It uses `pcall()` for all runtime interactions.
   - It never writes to any global, registry, or service.

## Output Sections

### Section 1 — Platform Header (Level 1: Always)
```
====================================================
DCE Runtime Observatory
====================================================
Core Version: 1.0.0
SDK Version: 1.0.0
Build Version: 1.0.0
Boot ID: XXXXX
Boot Timestamp: 2026-07-26 12:00:00
Runtime Mode: SERVER
Logging Profile: development
====================================================
```

### Section 2 — Boot Pipeline (Level 2: Development+)
Displays every boot pipeline stage with PASS/FAIL/UNKNOWN and execution time:
- BOOT (Core initialization)
- REGISTRATION (Service registration)  
- VERIFICATION (Runtime verification)
- REPORTING (Report generation)
- READY (Platform ready)

Each stage shows estimated or actual execution time. If boot aborts, displays exactly where.

### Section 3 — Resource Initialization (Level 3: Verbose only)
Displays every DCE resource:
- dce-core
- dce-events
- dce-ai
- dce-controlcenter
- dce-test-suite

For each resource: starting, initialized, ready status.

### Section 4 — Service Registry Audit (Level 3: Verbose only)
Displays every registered service:
- CoreRegistry
- Logger
- EventBus
- Scheduler

Each with lifecycle state, registration state, initialization state, singleton verification.

### Section 5 — SDK Audit (Level 3: Verbose only)
Verifies the frozen SDK:
- SDK identity marker (`DCE_FROZEN_SDK_v1.0.0`)
- Frozen status
- Version
- Canonical instance (exports['dce-core']:GetDCEAPI() returns frozen SDK)
- API count (verifies each of 22 expected APIs individually)

### Section 6 — Server Export Audit (Level 3: Verbose only)
Verifies every server export:
- Declared (global function exists)
- Registered (accessible via exports table)
- Callable (invocation succeeds)
- Invocation Test (returns result)
- Result

Required exports: `GetDCEAPI`, `IsReady`, `DCE_Subscribe`

### Section 7 — Client Export Audit (Level 3: Verbose only)
Same audit for client exports. Server and client exports reported separately.
Note: Full client invocation cannot be verified from server context.

### Section 8 — SDK Consumer Audit (Level 3: Verbose only)
Displays every resource requesting the SDK:
- dce-controlcenter
- dce-test-suite
- dce-events
- dce-ai

Each with PASS/FAIL/UNKNOWN status for SDK acquisition.

### Section 9 — Dependency Graph (Level 3: Verbose only)
Displays runtime dependency resolution with tree structure:
```
dce-core
└─ dce-core
dce-controlcenter
└─ dce-core
dce-test-suite
└─ dce-core
```

Each dependency reports PASS/FAIL/UNKNOWN.

### Section 10 — Event Bus Audit (Level 3: Verbose only)
Verifies:
- EventBus singleton (global exists)
- EventRegistry (defined event contracts)
- Subscriptions/listeners (metrics available)
- Listener count
- Duplicate detection
- Orphan detection

### Section 11 — Scheduler Audit (Level 3: Verbose only)
Verifies:
- Scheduler initialized (module exists with Init function)
- Worker count
- Queue state
- Pending tasks
- Paused tasks

### Section 12 — Plugin Manager Audit (Level 3: Verbose only)
Verifies:
- Plugin manager initialized
- Registered plugins
- Dependency resolution
- Lifecycle state

### Section 13 — Configuration Audit (Level 3: Verbose only)
Verifies:
- Configuration loaded (DCEConfigLoader global exists)
- Schema validated (ConfigFramework.Validate available)
- Migrations complete
- Overrides applied (Config global table)

### Section 14 — Runtime Identity Verification (Level 3: Verbose only)
Verifies singleton identity for:
- SDK (_G.DCE_FROZEN_SDK)
- Registry (_G.DCERegistry)
- Scheduler (_G.DCEScheduler)
- EventBus (_G.DCEEventBus)
- PluginManager (_G.DCEPluginArchitecture)
- Logger (_G.DCELogger)

If duplicate instances exist, displays FAIL.

### Section 15 — Runtime Summary (Level 1: Always)
```
=========================================
DCE Runtime Summary
=========================================
  Boot:       PASS
  Services:   4 / 4
  SDK APIs:   22 / 22
  Server Exports: 3 / 3
  Client Exports: 3 / 3
  SDK Consumers: 4 / 4
  Resources Ready: 5 / 5
-------------------------------------------
  Overall Runtime: PASS  (42 passed, 0 unknown)
=========================================
```

## Color Coding

- `^2` (Green): PASS — Runtime verification succeeded
- `^1` (Red): FAIL — Runtime verification failed
- `^3` (Yellow/Orange): UNKNOWN — Cannot verify at runtime
- `^0`: Reset color

## Files Modified

| File | Change |
|------|--------|
| `DCE/src/dce-core/runtime/observatory.lua` | **NEW** — Runtime Observatory implementation |
| `DCE/src/dce-core/fxmanifest.lua` | Added `'runtime/observatory.lua'` to server_scripts and client_scripts |
| `DCE/src/dce-core/init.lua` | Added observatory generation call in ReadyPhase |
| `DCE/src/dce-core/client/init.lua` | Added observatory generation call in client InitializeCore |

## Root Cause Explanation

No runtime defects were corrected in this sprint. The purpose was strictly to ensure the implementation produces enough runtime evidence for external analysis.

## Regression Prevention Notes

1. The observatory is **read-only** — it never modifies runtime state
2. The observatory uses `pcall()` for all runtime interactions — it never crashes
3. The observatory runs **after** all initialization is complete — it never interferes with boot
4. Every PASS comes from actual `_G` global checks or function calls — never from assumptions
5. UNKNOWN is displayed when runtime verification cannot be performed — never PASS
6. The observatory always runs with no commands, debug modes, or manual activation required

## Completion Status

Sprint 1.10.8 implementation complete. Awaiting external runtime validation.