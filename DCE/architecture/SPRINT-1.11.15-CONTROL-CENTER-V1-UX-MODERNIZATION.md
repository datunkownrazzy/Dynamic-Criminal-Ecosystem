# Sprint 1.11.15 - Control Center V1 UX Modernization

**Status:** Source-level UX modernization complete. Live FiveM verification remains required.

## 1. Scope and Architecture

This work modernizes the existing `dce-controlcenter` V1 presentation layer. It preserves the established ownership model:

- `ControlCenterService` and the server `SessionManager` own authorization and server sessions.
- `SessionManagerClient` owns client session state.
- `FocusManager` remains the sole owner of NUI focus.
- The application manager owns the NUI desktop, navigation, and plugin lifecycle.
- The existing `dce-cc:session:close` flow remains the single session-close path.

No Core, SDK, Event Bus, registry, scheduler, focus, browser, or session architecture was changed. No ADR is required because this is a presentation-layer improvement that uses existing NUI callbacks and lifecycle contracts.

## 2. UX Problems Discovered

1. The V1 application shell had no visible close control, despite Lua already exposing close and escape NUI callbacks.
2. ESC had no frontend handler. The existing command palette was the only overlay capable of receiving ESC, leaving the expected application-close behavior incomplete.
3. Page headings exposed plugin-oriented names such as `World Manager` and `AI Manager` instead of user-facing destinations.
4. Home gave limited orientation and no direct route to common operational pages.
5. Organizations displayed an `Add` button even though its NUI create callback is not registered. This appeared actionable but could not succeed.
6. World and Organizations requested unavailable data once during plugin startup and again when their views rendered.
7. Several unavailable pages gave only a terse, generic message.
8. Keyboard focus feedback was incomplete for buttons and inputs.

## 3. Navigation and Layout Changes

The existing application shell remains a header, left navigation rail, main content area, and status bar. Primary navigation continues to expose only operational destinations: Home, World, Organizations, Scenarios, Dispatch, Evidence, Economy, and Intelligence. Developer-oriented Analytics, Server Monitor, and Developer Tools remain out of primary navigation because their current content is incomplete or placeholder-only.

Page headings and status breadcrumbs now use human-facing labels: World, Organizations, Scenarios, Dispatch, Evidence, Economy, and Intelligence. This keeps the navigation task-oriented without renaming plugin identifiers or changing backend contracts.

Home remains the deterministic activation destination. It now explains that it represents the current Control Center session, identifies the connected frontend session, reports the number of active UI modules, explicitly labels unavailable runtime and data states, and provides two meaningful quick actions: view World status and view Organizations.

## 4. Closing and ESC Improvements

A persistent **Close** button is now available in the application header on every page. It calls the existing `dce-cc:nui:close` NUI callback; Lua then triggers the existing session-close flow. It does not manipulate focus, browser state, or sessions directly.

The frontend now handles ESC with the expected precedence:

1. Dismiss the command palette when it is open.
2. Dismiss the existing modal overlay when it is visible.
3. Otherwise call the existing `dce-cc:nui:escape` NUI callback.

Both UI exits ultimately reach `dce-cc:session:close`. `/dceclose` remains unchanged as the command fallback. A close-request guard prevents duplicate close posts while a close is in progress and resets on the next application activation.

## 5. Interaction Improvements

- Navigation keeps its existing active-destination treatment and focuses the selected content region.
- Home quick actions navigate to existing primary pages only.
- The nonfunctional Organizations creation control and its unused helper were removed.
- World and Organizations no longer make background data requests on plugin startup. Data is requested only when the user opens the relevant page.
- Failed World and Organization requests now explain that the responsible service did not return usable data, while technical errors remain in the console.

## 6. Loading, Empty, Error, and Unavailable States

World and Organizations retain their page-specific loading state while a request is pending. Successful empty arrays still show domain-specific empty states. Missing responses render as unavailable, and rejected NUI requests render a plain-language error explanation.

Scenarios, Dispatch, Evidence, Economy, and Intelligence do not have a live V1 data-provider contract. Their pages now state both the unavailable state and what information is absent, rather than presenting an empty or ambiguous surface. No records, statistics, organizations, scenarios, dispatch calls, evidence, intelligence, or economy values are fabricated.

## 7. Accessibility Improvements

- The close control has a visible label and an explicit accessible name.
- Buttons and inputs now display a consistent visible keyboard focus outline.
- The navigation region retains its `aria-label`.
- The main content region is focusable after navigation.
- The header remains responsive: its identity group stacks cleanly on narrow viewports while Close remains available.

## 8. Removed or Consolidated UI

- Removed the dead Organizations **Add** action and its unsupported `organization:create` frontend path.
- Removed duplicate automatic World and Organization data loading during plugin activation.
- Kept internal/developer plugins hidden from primary navigation, avoiding duplicate or misleading administration entry points.

## 9. Working Functionality

**Source-verified working behavior:**

- `/dce` triggers the existing server open request.
- NUI boot lazily loads the application manager, creates the desktop, starts plugins, receives focus through `FocusManager`, activates, and navigates to Home.
- All visible primary navigation items resolve to a renderer.
- Home quick actions resolve to visible primary destinations.
- Header Close posts through the existing close callback and session lifecycle.
- ESC closes the active overlay before requesting the existing escape lifecycle.
- `/dceclose` remains registered and uses the existing server close request.
- Shutdown unloads plugins, closes desktop windows, cleans application timers, and returns the application to the unloaded state.
- Activation resets the close-request guard and navigates to Home, supporting the next open cycle without duplicate close requests.

## 10. Intentionally Unavailable Functionality

The following are deliberately represented as unavailable because their V1 NUI provider callbacks are absent or do not supply usable runtime data:

- World locations and territories: `world-locations:get`, `world-territories:get`
- Organizations and members: `organization-list:get`, `organization-members:get`
- Scenario records
- Dispatch calls
- Evidence records
- Economy operational data
- Intelligence operational data
- Runtime health data from DCE Core

Organization creation is intentionally not exposed because `organization:create` has no registered provider. Analytics, Server Monitor, and Developer Tools are intentionally not in primary navigation because their current output is incomplete, diagnostic-only, or placeholder-backed.

## 11. Testing Performed

- Audited the application manager, desktop, dock, plugin manager, all visible plugin renderers, bootstrap callbacks, client command registration, session callbacks, and existing finalization report.
- Ran `node --check` across all 26 files in `src/dce-controlcenter/html/js`: all passed.
- Confirmed no remaining references to `btn-add-org`, `organization:create`, or `createOrganization` in the Organizations frontend module.
- Checked VS Code diagnostics for the changed desktop script and stylesheet: no errors found.
- Traced the source-level exit routes from Close and ESC to the existing `dce-cc:session:close` event.

## 12. Remaining Limitations

- No automated FiveM/NUI browser harness is available in this repository, so live verification of `/dce`, navigation, Close, ESC, `/dceclose`, focus release, and reopening must be performed in a FiveM runtime.
- Real operational data requires future, owned data-provider contracts; this UX work intentionally does not add a parallel transport or backend implementation.
- The legacy code contains historical `v2` comments and internal identifiers. They are not visible application identity and were not renamed, avoiding a breaking architectural rename.
- The generic modal overlay has no dedicated modal manager. ESC safely dismisses the existing overlay before closing the application; a future modal system should own richer dialog lifecycle behavior if one is introduced.

## 13. Visual Correction Pass

Live testing found that the otherwise functional shell still read as an uncontrolled full-screen overlay. The cause was presentation-only: both the active NUI body and the desktop claimed the full FiveM viewport.

The desktop is now a bounded, centered application surface using viewport-aware dimensions:

- Maximum surface: `1440px` wide by `900px` high.
- Desktop margins scale with the viewport and cap at `192px` horizontally and `128px` vertically.
- At narrow resolutions, the surface keeps a `12px` perimeter instead of compressing text or navigation.
- The active NUI body is transparent outside the surface, exposing the surrounding game environment.
- Header, navigation, content, status bar, notifications, and the modal overlay all remain inside the same bounded desktop surface.

The header retains its dedicated right-aligned Close action. Its fixed-size action area, responsive identity group, and bounded parent prevent it from colliding with surrounding FiveM UI or being displaced by page content.

### Correction-Pass Validation

- CSS diagnostics for the surface changes reported no errors.
- Source review confirms the footer/status bar, notifications, and modal overlay are positioned within the desktop surface rather than the full NUI viewport.
- Existing Close, ESC, and `/dceclose` routing remains unchanged and continues through the established session-close lifecycle.
- This workspace cannot start or attach to a FiveM client, so the required live tests at `1920x1080`, `2560x1440`, and repeated open/close cycles remain an operational verification step.