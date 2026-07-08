# ADR-0021: NUI Lifecycle Diagnostic Mode

## Status
Proposed

## Context
The DCE Control Center has experienced issues with a gray overlay appearing on player spawn, blocking gameplay. This was caused by incorrect NUI focus release logic, but identifying the root cause required extensive manual debugging. A systematic diagnostic instrumentation system is needed to trace the complete NUI lifecycle from resource startup through focus acquisition and release.

## Decision
Implement a comprehensive diagnostic instrumentation system that can be enabled via `Config.Debug.NUILifecycle = true`. When disabled, zero diagnostic output should be produced.

## Implementation

### Files Modified/Created

1. **DCE Core**
   - `core/diagnostics.lua` - New diagnostic module providing tracing functions
   - `config.lua` - Added `Config.Debug.NUILifecycle` configuration option
   - `init.lua` - Integrated diagnostics with core initialization and event emission

2. **DCE Admin**
   - `client/diagnostic-wrapper.lua` - Client-side wrapper for NUI function instrumentation
   - `client/nui.lua` - Added lifecycle state transitions and focus tracing
   - `init.lua` - Added server-side resource startup tracing
   - `fxmanifest.lua` - Registered diagnostic-wrapper.lua client script

3. **JavaScript Client**
   - `html/js/framework.js` - Added MessageHandler, Desktop, and UI instrumentation
   - `html/js/app.js` - Added DOMContentLoaded and window.onload tracing
   - `html/js/window-manager.js` - Added window open/close tracing

### Diagnostic Output Format

All diagnostic output follows standardized formats:

```
[DCE][BOOT]        - Resource startup (Step 1)
[DCE][THREAD]      - Thread execution (Step 2)
[DCE][EVENT]       - Event bus dispatch (Step 3)
[DCE][NUI]         - NUI focus/message operations (Step 4)
[DCE JS]           - JavaScript operations (Step 5)
[DCE MESSAGE]      - Browser message receiving (Step 6)
[DCE CALLBACK]     - NUI callback execution (Step 7)
[DCE STATE]        - Lifecycle state transitions (Step 8)
[DCE AUTH]         - Authorization checks (Step 9)
[DCE TIMER]        - Performance timing (Step 10)
[DCE WATCHDOG]     - Periodic focus/UI state check (Step 11)
[DCE OWNER]        - Resource ownership tracking (Step 12)
[DCE WARNING]      - Hang detection (Step 13)
[DCE CLOSE]        - Shutdown trace (Step 14)
[DCE SUMMARY]      - Final statistics (Step 15)
```

### Lifecycle States

The diagnostic mode tracks the following states:
- `BOOT` - Initial state before any initialization
- `RESOURCE_START` - Server resource starting
- `CLIENT_READY` - Client script loaded, NUI available
- `NUI_READY` - Browser DOM ready
- `WAITING` - UI ready, awaiting authorization
- `AUTHORIZED` - Permission check passed
- `OPENING` - Transition to open state
- `OPEN` - UI visible with focus
- `CLOSING` - Transition to closed state
- `CLOSED` - UI hidden, focus released

## Failure Detection Rules

The diagnostic system automatically highlights these conditions:
- `SetNuiFocus(true, true)` called before authorization
- More than one `SetNuiFocus(true, true)` without matching release
- `SendNUIMessage({ action = "open" })` before authorization
- Browser receives open while lifecycle state is WAITING
- Callback runs longer than 2 seconds
- Thread exceeds 5 seconds
- Resource fails to initialize
- Focus is true while UI state is closed
- Cursor is enabled while UI state is closed
- Any illegal lifecycle transition

## Usage

To enable diagnostic mode:
1. Set `Config.Debug.NUILifecycle = true` in `DCE/src/dce-core/config.lua`
2. Restart the server
3. Join the game and observe console output (server F8 and client)

## Consequences

- When disabled, zero overhead is added to production code
- When enabled, comprehensive tracing helps identify timing and state issues
- All instrumentation functions check for nil-safe access to Diagnostics module
- Thread timeout warnings help identify hung operations
- State machine prevents silent illegal transitions