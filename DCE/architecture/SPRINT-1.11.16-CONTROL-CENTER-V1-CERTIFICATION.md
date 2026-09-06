# Sprint 1.11.16 - Control Center V1 Certification

**Audit date:** 2026-09-06  
**Scope:** Control Center application shell, lifecycle, navigation, focus, and current truthful data states.  
**Excluded:** Subsystem data implementation, UI redesign, V2 work, and Core architecture changes.

## Result

**CONTROL CENTER V1: ATTENTION**

The Control Center is suitable to proceed to V1 integration certification. No blocker was identified in the supplied live evidence or in the audited open, navigation, close, focus, and bounded-surface source paths.

`ATTENTION` is assigned because the supplied live observations do not include the requested ten repeated open/navigate/close/reopen cycles, the three close-route reopen checks, resolution-specific results, or browser/client-console output. Those are certification evidence gaps, not confirmed Control Center failures.

## Verified

### Live In-Game Verification

The following observations were supplied as manually verified in FiveM:

- `/dce` opens the Control Center.
- The Control Center is centered and bounded; the game world remains visible around it.
- Header readability and the Close control are acceptable.
- Primary navigation works, including Home, World, Organizations, Evidence, Economy, and the other currently implemented destinations.
- Pages display unavailable/empty states instead of fabricated records.

### Source Verification

- The resource requires `dce-core`, registers `/dce` and `/dceclose`, and lazy-loads the NUI application after session start. See [fxmanifest.lua](../src/dce-controlcenter/fxmanifest.lua), [client/init.lua](../src/dce-controlcenter/client/init.lua), [bootstrap.js](../src/dce-controlcenter/html/js/bootstrap/bootstrap.js), and [application-manager.js](../src/dce-controlcenter/html/js/application/application-manager.js).
- The dock maps all eight visible destinations to renderers: Home, World, Organizations, Scenarios, Dispatch, Evidence, Economy, and Intelligence. The selected destination receives the active state. See [dock.js](../src/dce-controlcenter/html/js/ui/dock.js) and [desktop.js](../src/dce-controlcenter/html/js/ui/desktop.js).
- Close button and ESC use the existing NUI callbacks, which both trigger the existing session-close event. `/dceclose` routes through the existing server close request. See [desktop.js](../src/dce-controlcenter/html/js/ui/desktop.js), [bootstrap.lua](../src/dce-controlcenter/bootstrap/bootstrap.lua), [client/init.lua](../src/dce-controlcenter/client/init.lua), and [controlcenter.lua](../src/dce-controlcenter/server/services/controlcenter.lua).
- Session end sends application shutdown and releases focus through the existing `FocusManager`; resource stop has an emergency focus release. See [session-manager-client.lua](../src/dce-controlcenter/session/session-manager-client.lua) and [focus-manager.lua](../src/dce-controlcenter/session/focus-manager.lua).
- The application surface is centered, bounded, viewport-aware, and contains its header, navigation, content, status bar, notifications, and modal overlay. See [style.css](../src/dce-controlcenter/html/css/style.css).
- Duplicate dock handlers are guarded by `DCE.Dock._initialized`; duplicate close posts are guarded by `DCE.Desktop._closeRequested`; the server reuses an active player session instead of creating a concurrent one. See [dock.js](../src/dce-controlcenter/html/js/ui/dock.js), [desktop.js](../src/dce-controlcenter/html/js/ui/desktop.js), and [session-manager.lua](../src/dce-controlcenter/server/session-manager.lua).

## Automated Tests

- `node --check` passed for all 26 JavaScript files under `src/dce-controlcenter/html/js`.
- Scoped `git diff --check` passed for the bounded-surface correction and UX certification report.
- Existing `dce-test-suite` phases cover SDK, plugin, Event Bus, scheduler, registry, failure, memory, startup, documentation, and platform concerns. See [dce-test-suite](../src/dce-test-suite).

There is no automated FiveM/CEF Control Center UI suite. In particular, the repository has no automated test for NUI rendering, click behavior, focus release, close/reopen cycling, or browser-console cleanliness.

## Manual Tests

### Completed

- Opened the Control Center with `/dce`.
- Confirmed bounded, centered application sizing with visible game-world margins.
- Confirmed Header and Close-control accessibility.
- Navigated Home, World, Organizations, Evidence, Economy, and the remaining implemented pages.
- Confirmed honest unavailable/empty subsystem presentation.

### Required Before Final READY Sign-Off

- Close via header Close, then reopen with `/dce`.
- Close via ESC, then reopen with `/dce`.
- Close via `/dceclose`, then reopen with `/dce`.
- Run at least ten open, navigate, close, and reopen cycles while observing focus and UI state.
- Check 1920x1080, 2560x1440 when available, and the smallest supported resolution for clipping, overflow, and Close/navigation accessibility.
- Inspect the FiveM client and NUI console during those tests for uncaught exceptions, callback failures, or repeated warnings.

## Navigation and Controls

| Control or destination | Certification | Evidence |
|---|---|---|
| Home | PASS | Live navigation verified; `Desktop.navigate('home')` renders the source-known status view. |
| World | PASS with expected limitation | Live navigation verified; renderer shows loading, unavailable, error, or empty state according to the current response. |
| Organizations | PASS with expected limitation | Live navigation verified; renderer shows loading, unavailable, error, or empty state according to the current response. |
| Scenarios | PASS with expected limitation | Renderer provides an explicit unavailable state. |
| Dispatch | PASS with expected limitation | Renderer provides an explicit unavailable state. |
| Evidence | PASS with expected limitation | Live navigation verified; renderer provides an explicit unavailable state. |
| Economy | PASS with expected limitation | Live navigation verified; renderer provides an explicit unavailable state. |
| Intelligence | PASS with expected limitation | Renderer provides an explicit unavailable state. |
| Home quick actions | PASS | Both route to existing World and Organizations destinations. |
| Close | PASS, reopen test pending | Calls the existing `dce-cc:nui:close` callback. |
| ESC | PASS, live close test pending | Dismisses an open command palette or modal overlay first; otherwise calls the existing `dce-cc:nui:escape` callback. |
| `/dceclose` | PASS, reopen test pending | Registered client command routes to the existing server close event. |

No visible primary control was found to be intentionally inert. The previous unsupported Organization creation control is not present.

## Truthful Data States

The current implementation can truthfully distinguish the following only where a page requests data:

| Page | Loading | Empty | Unavailable | Error |
|---|---|---|---|---|
| World | Yes | Yes, when a successful response contains no locations or territories | Yes, when a response lacks the expected data | Yes, when its NUI request rejects |
| Organizations | Yes | Yes, when a successful response contains no organizations or members | Yes, when a response lacks the expected data | Yes, when its NUI request rejects |
| Scenarios, Dispatch, Evidence, Economy, Intelligence | No live provider | Not distinguishable | Yes | Not distinguishable without a provider |

The absence of live subsystem data is an expected limitation and is not a Control Center failure.

## Blockers

None identified.

## Major UX Issues

None identified from the supplied live observations and source audit.

## Minor Issues

- Opening World or Organizations requests NUI callbacks that are intentionally not implemented. The failures are caught and shown as unavailable/error UI, but `DCE.NUI.post()` logs a browser-console error for each failed request. This is expected data-provider diagnostic noise, not an uncaught application error.
- [event-forwarder.lua](../src/dce-controlcenter/client/nui/event-forwarder.lua) retains a `SetTimeout` retry when Core is not ready. This is outside the tested presentation flow and is a pre-existing FiveM compatibility concern. It should be tracked separately; no evidence connects it to a current Control Center usability failure.
- The existing command palette has no registered Control Center commands. It is not a visible primary navigation dependency.

## Expected Limitations

- World locations and territories are unavailable because their NUI callbacks are not implemented.
- Organization and member data are unavailable because their NUI callbacks are not implemented.
- Scenario, Dispatch, Evidence, Economy, and Intelligence pages have no live V1 data-provider contract.
- Runtime health data is not supplied to Home.
- Analytics, Server Monitor, and Developer Tools remain outside primary navigation because their current output is incomplete, diagnostic-only, or placeholder-backed.

No fake records, counts, statistics, or sample data were introduced for this certification.

## Regression Coverage

The current regression protection is static rather than behavioral:

- JavaScript syntax checking covers all 26 Control Center frontend scripts.
- `DCE.Dock._initialized` guards duplicate navigation listener registration.
- `DCE.Desktop._closeRequested` guards duplicate UI close submissions and resets when the desktop reopens.
- Server-side active-session reuse prevents concurrent active sessions for one player.
- `FocusManager.EmergencyRelease()` releases NUI focus on resource stop.

There is no automated regression test that simulates Control Center open/close or NUI focus in FiveM. The required ten-cycle live test should be captured as the baseline until such a harness exists.

## Final Recommendation

**Proceed to V1 integration/certification with attention.**

The Control Center itself has no identified blocker, retains a bounded usable surface, has functioning navigation and close routes, and represents unavailable subsystems honestly. Complete the listed close/reopen, repeated-cycle, resolution, and console checks before changing the result from `ATTENTION` to `READY`. Do not block this Control Center certification on subsystem data implementation.