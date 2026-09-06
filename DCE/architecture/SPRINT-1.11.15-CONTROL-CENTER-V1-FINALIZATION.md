# Sprint 1.11.15 - Control Center V1 Finalization

**Status:** Source-level finalized; live FiveM verification required.

## 1. Existing Control Center Architecture

The `dce-controlcenter` resource is a V1 consumer of the canonical `DCE_SDK_v1.11.7`. `ControlCenterService` owns permission checks and session orchestration. The server `SessionManager` owns server sessions and `SessionManagerClient` owns client session state. `FocusManager` is the sole focus owner. NUI boot is initiated by `bootstrap.lua`, lazily loads the application manager, then activates after focus is granted. The application manager owns the desktop DOM, plugin lifecycle, and existing UI modules. Plugins remain passive renderers.

## 2. Application Lifecycle

```
/dce -> server open request -> session start -> application:boot
-> bootstrap.js lazy-load -> Application.Boot -> application:booted
-> FocusManager.RequestFocus -> application:activate -> Application.Activate
-> plugin start -> Desktop.open -> Desktop.navigate('home')
```

`/dceclose` retains its existing session-close path: session end sends `application:shutdown`, plugins stop/destroy, focus is released, and the body returns to the unloaded state. Reopening runs activation again. The dock event listener is now registered once per NUI lifetime.

## 3. Root Cause of the Empty UI

**Source verified:** `Desktop.create()` created a dock, empty window container, and status bar only. `Application.Activate()` started plugins and refreshed a horizontal, icon-only dock but never selected a default destination or mounted a renderer. The visible result was an empty desktop until a plugin icon was clicked.

The declared `plugin-host.js` was also never loaded, but the active dock path directly uses plugin `render()` methods and does not depend on it.

## 4. Root Cause of Navigation Problems

**Source verified:** every discovered plugin, including Analytics, Server Monitor, and Developer Tools, was rendered as an unlabeled icon. A click opened a floating window through the window manager rather than selecting a clear application location. No Home destination existed.

## 5. Layout Findings and Changes

The desktop now owns a stable header, left navigation rail, main content region, and status bar. The dock renders textual V1 destinations and routes them to the existing plugin renderers in the main content region. Window manager code remains loaded but is no longer the visible primary navigation path.

## 6. Home Implementation Findings

Home was absent. It is now the deterministic default route and presents only source-known state:

- active application session
- number of plugins whose lifecycle state is `started`
- explicit unavailable states for World, Scenarios, Dispatch, Evidence, and Intelligence data

No simulation statistics, organizations, incidents, or financial values are fabricated.

## 7. Plugin/UI Registration Matrix

| Plugin | Starts | Primary navigation | Renderer | Data state | V1 result |
|---|---:|---:|---:|---|---|
| World | Yes | World | Yes | Missing NUI data handler | Unavailable/error/empty states |
| Organizations | Yes | Organizations | Yes | Missing NUI data handler | Unavailable/error/empty states |
| Scenarios | Yes | Scenarios | Yes | No provider | Unavailable state |
| Dispatch | Yes | Dispatch | Yes | No UI contract | Unavailable state |
| Evidence | Yes | Evidence | Yes | No UI contract | Unavailable state |
| Economy | Yes | Economy | Yes | No provider | Unavailable state |
| AI Manager | Yes | Intelligence | Yes | No provider | Unavailable state |
| Analytics | Yes | Hidden | Yes | No provider | Not exposed |
| Server Monitor | Yes | Hidden | Yes | Placeholder values only | Not exposed |
| Developer Tools | Yes | Hidden | Yes | No provider | Not exposed |

## 8. NUI Contract Findings

`DCE.NUI.post()` previously converted all transport failures into `null`. World and Organizations treated the result as no-op, leaving loading UI indefinitely. It now logs and rejects failed requests; those renderers convert missing responses into unavailable states and rejected requests into error states.

The following plugin requests still have no registered Lua callbacks and are intentionally represented as unavailable rather than fake data: `world-locations:get`, `world-territories:get`, `organization-list:get`, `organization-members:get`, and `organization:create`.

## 9. Lifecycle Findings

The prior activation report verifies the command, lazy boot, focus, and session ordering. This sprint preserves that ordering. `DCE.Dock.init()` now guards its event-listener registration, preventing repeated navigation handlers after a shutdown/reopen cycle.

## 10. Version Identity Findings

The visible resource metadata, document title, desktop status label, and taskbar fallback are now intentional V1 identity: `DCE Control Center V1` with `DCE SDK v1.11.7`. The codebase contains historical `v2` comments and non-visible diagnostic labels; these are not application identity and were intentionally not mass-renamed. The resource manifest version is now `1.11.7`.

## 11. Files Inspected

- `src/dce-controlcenter/fxmanifest.lua`
- bootstrap, client, session, service, adapter, NUI, desktop, dock, taskbar, window-manager, application-manager, plugin-manager, and plugin source files
- `architecture/SPRINT-1.11.14-CONTROL-CENTER-ACTIVATION.md`

## 12. Files Modified

- `src/dce-controlcenter/fxmanifest.lua`
- `src/dce-controlcenter/html/bootstrap.html`
- `src/dce-controlcenter/html/css/style.css`
- `src/dce-controlcenter/html/js/bootstrap/bootstrap.js`
- `src/dce-controlcenter/html/js/application/application-manager.js`
- `src/dce-controlcenter/html/js/ui/desktop.js`
- `src/dce-controlcenter/html/js/ui/dock.js`
- `src/dce-controlcenter/html/js/ui/taskbar.js`
- the World, Organizations, Scenarios, Dispatch, Evidence, Economy, and AI Manager plugin renderers

## 13. Exact Changes Made

1. Added a main-content navigation model with Home as the default activation destination.
2. Replaced unlabelled all-plugin dock entries with meaningful V1 destinations.
3. Hid incomplete internal/developer plugins from primary navigation.
4. Added focused Home and page unavailable/empty/error UI states.
5. Propagated NUI request failures instead of swallowing them.
6. Prevented duplicate dock click listeners across reopen cycles.
7. Initialized the existing taskbar clock on activation.
8. Aligned visible Control Center identity with V1.11.7.

## 14. Navigation Model

| Control | Handler | Destination | Renderer |
|---|---|---|---|
| Home | `Dock.handleDockClick` | `home` | `Desktop.navigate` |
| World | `Dock.handleDockClick` | `world-manager` | World plugin |
| Organizations | `Dock.handleDockClick` | `organization-manager` | Organizations plugin |
| Scenarios | `Dock.handleDockClick` | `scenario-manager` | Scenarios plugin |
| Dispatch | `Dock.handleDockClick` | `dispatch-manager` | Dispatch plugin |
| Evidence | `Dock.handleDockClick` | `evidence-manager` | Evidence plugin |
| Economy | `Dock.handleDockClick` | `economy-manager` | Economy plugin |
| Intelligence | `Dock.handleDockClick` | `ai-manager` | Intelligence plugin |

Every visible primary control has a renderer. The current location is shown by the selected control and status-bar breadcrumb.

## 15. Home Model

Home is application-owned UI in `Desktop.navigate('home')`. It derives only lifecycle state already held by the frontend plugin manager. Data domains without a source show an intentional unavailable state.

## 16. Loading, Empty, Error, and Unavailable States

World and Organizations retain loading text while a request is pending. Empty successful arrays show domain-specific empty states. Missing responses show unavailable states. Rejected NUI requests show load-error states. The other V1 pages show unavailable until a real provider and contract exist.

## 17. Tests Added or Modified

No automated FiveM/NUI test harness exists in this repository. Source checks performed:

- `node --check` passed for all 26 Control Center JavaScript files.
- VS Code diagnostics reported no errors in the modified JavaScript files.

## 18. Source-Level Validation

**Verified from source:** Home is mounted during activation; all visible navigation destinations resolve to a `render()` function; hidden plugins are absent from the dock; NUI rejections reach page error UI; reopening cannot add another dock click listener; visible version labels use V1.11.7.

## 19. Previously Live-Verified Behavior

Sprint 1.11.14 records successful `/dce` command routing, session startup, NUI bootstrap, focus acquisition, activation, and `/dceclose` shutdown flow. This report does not claim that this sprint was live-tested.

## 20. Remaining Issues

- Plugin data callbacks are missing and require a future, owned server-to-client data transport implementation before real World or Organization data can be shown.
- Server adapters contain placeholder/default values and must not be presented as simulation data.
- `event-forwarder.lua` uses `SetTimeout`, which was previously identified as a separate FiveM compatibility concern.

## 21. Intentionally Deferred

V2 work, AI implementation, performance engineering, new simulation systems, EventBus/Registry/Scheduler/SDK replacement, plugin-host redesign, and a new data transport architecture are deferred.

## 22. Final V1 Control Center Readiness Assessment

The source now provides a coherent, non-blank V1 Control Center application shell: Home renders on activation, navigation is limited to meaningful DCE domains, incomplete systems state their availability explicitly, and the visible version identity is V1.11.7. Final operational readiness requires live FiveM verification of opening, navigation, closing, and reopening, plus future implementation of the documented data-provider contracts.
