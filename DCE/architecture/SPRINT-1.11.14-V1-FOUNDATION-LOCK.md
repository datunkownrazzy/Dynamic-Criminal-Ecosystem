# Sprint 1.11.14 - V1 Runtime Foundation Lock

**Audit date:** 2026-09-01  
**Status:** NOT READY - runtime certification remains unverified

## 1. Current Foundation Status

The source tree has one V1 core SDK and a Control Center resource labelled v2.0.0. The core's published runtime version is now consistently `1.11.7`. Static source checks identified and corrected version drift and two Control Center boundary defects. No FiveM server/client runtime was available to execute the full foundation suite.

## 2. Repository Audit Summary

Audited all resource manifests and the `src` resource tree. Resource ownership and dependencies are declared through FiveM manifests. `dce-core` provides the canonical SDK; dependent simulation resources consume it through `exports['dce-core']:GetDCEAPI()`.

## 3. Confirmed Problems

1. `dce-core` manifest and `CoreRegistry:GetDCEVersion()` reported `1.11.6`, while RuntimeState, SDK metadata, SDK `GetVersion()`, and lifecycle payloads reported `1.11.7`.
2. Control Center clients attempted `DCE:GetService("WorkspaceManager")`, although WorkspaceManager is registered on the server VM only.
3. Organization and world plugins referenced undefined `DCE.Bus` subscriptions. No matching producer events or JavaScript bus bridge exists in this tree.
4. The NUI session-closed callback emitted `dce-cc:session:closed`, but the server owns `dce-cc:session:close`.

## 4. Root Cause for Each Problem

The version values were maintained independently. Client WorkspaceManager calls crossed an invalid FiveM VM boundary. `DCE.Bus` was leftover UI architecture: the Lua forwarder sends a different NUI message shape and no JavaScript dispatcher consumes it. The close event names diverged.

## 5. Exact Changes Made

- Set the `dce-core` manifest version and server CoreRegistry version to `1.11.7`.
- Added SDK regression assertions that `GetVersion()`, `GetSnapshot().version`, and `CoreRegistry:GetDCEVersion()` agree.
- Routed workspace saves through `dce-cc:workspace:save`; the server verifies that the submitted session belongs to the event source before persisting it.
- Removed client-side WorkspaceManager access and corrected the session-close event name.
- Removed dead `DCE.Bus` lifecycle calls and stale state from the affected plugins.
- Updated certification output text from `v1.0.0` to `v1.11.7`.

## 6. SDK Contract Verification

Source inspection confirms one SDK builder, `DCE_SDK_v1.11.7`, with the documented 21 methods and immutable metatable. Server and client exports are declared. Cross-resource callability is deliberately handled by `IsCallable()` tests and normalizers. Runtime export behavior remains unexecuted.

## 7. EventBus Verification

Source inspection confirms `On`, `Once`, `Off`, and `Emit`; FunctionRef normalization; protected handler execution; sticky event replay; and listener cleanup through `Clear`. `lifecycle:ready` and `lifecycle:running` are sticky. Load execution remains unverified.

## 8. Scheduler Verification

Source inspection confirms FunctionRef normalization, invalid callback rejection, immediate and recurring execution, replacement, explicit unscheduling, callback isolation, task listing, and clear. Runtime timing behavior remains unverified.

## 9. Registry Verification

The canonical SDK delegates registry operations to one Registry instance. Duplicate registrations remain warnings rather than silent overrides. A live resource lifecycle run is required to certify owner/registration uniqueness.

## 10. FiveM Client/Server Boundary Verification

The client-loaded core leaf modules use guarded clocks. Server-only Scheduler is not client-loaded. Confirmed client access to server-only WorkspaceManager was removed. The client now sends workspace data to its server owner, which validates session ownership.

## 11. World Verification

Not runtime-verified. No source change was made to World, LocationManager, models, or simulation layers.

## 12. AI Foundation Verification

Not runtime-verified. No V2 AI work was introduced.

## 13. Events Verification

Not runtime-verified. No scenario mechanics were changed.

## 14. Dispatch Verification

Not runtime-verified. No adapter behavior was changed.

## 15. Evidence Verification

Not runtime-verified. No adapter behavior was changed.

## 16. Control Center `/dce` End-to-End Verification

The existing activation trace in `SPRINT-1.11.14-CONTROL-CENTER-ACTIVATION.md` matches the current command, session, NUI boot, and focus code. It was not executed against a live client in this audit.

## 17. WorkspaceManager Boundary Verification

WorkspaceManager remains server-owned and server-registered. Client registry lookups were removed. `dce-cc:workspace:save` is the narrow network boundary and rejects missing, unknown, or foreign sessions.

## 18. Control Center JS Event Contract Verification

`DCE.Bus` was confirmed dead legacy, not an active EventBus bridge: its event names have no producers, and its JavaScript dispatcher does not exist. Dead dependencies were removed. The Lua event forwarder is not certified as a UI live-update feature because its message contract has no JS consumer.

## 19. Shutdown Verification

Source contains shutdown hooks for core event listeners/tasks and Control Center sessions/UI. Restart and disconnect cleanup require runtime verification.

## 20. Test Results

- Static: Node syntax checks passed for the changed Control Center plugins.
- Static: no remaining client WorkspaceManager lookup or `DCE.Bus` dependency was found.
- Static: no remaining `GetDCEVersion()` publisher of `1.11.6` was found in core/test-suite.
- Static: `git diff --check` is blocked by trailing whitespace in unrelated `dce-ai/services/organizations.lua`.
- Runtime: not run. The in-resource FiveM test suite executes on resource start, but this workspace does not supply a runnable FiveM server/client environment.

## 21. Remaining Technical Debt

- `client/nui/event-forwarder.lua` uses `SetTimeout`, whose FiveM client availability must be confirmed or replaced with the documented client timeout API during a runtime-backed fix.
- The event forwarder has no proven JavaScript consumer for `eventbus:event`.
- Workspace restore is not implemented after removal of the invalid client server-service access; it needs a separately designed request/response boundary before being restored.
- Unrelated AI trailing whitespace prevents a clean repository-wide `git diff --check`.

## 22. Explicitly Deferred V2 Work

No V2 AI, simulation, economy, territory, or compatibility architecture was added. The Control Center's existing `v2.0.0` label is a source/documentation discrepancy, not a V1 core SDK version.

## 23. Final Foundation Certification

```
V1 FOUNDATION: NOT READY
```

**Blockers:** execute the automatic FiveM test suite on a real server/client; verify `/dce`, `/dceclose`, reopen, permission denial, disconnect, resource restart, NUI focus, and shutdown; then validate World, AI, Events, Dispatch, and Evidence startup against actual optional integrations. Until those runtime checks produce evidence, foundation readiness cannot be certified.