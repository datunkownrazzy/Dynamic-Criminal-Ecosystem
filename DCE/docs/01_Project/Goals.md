# DCE Goals

**Status:** Accepted
**Version:** 1.0
**Owner:** Datunkownrazzy

---

Vision explains the destination. This document sets checkpoints — what "done" looks like for v1.0, what's explicitly deferred, and what would count as failure. Goals should be revisited at the end of each milestone.

---

## v1.0 Goals ("Living Criminal World")

By the end of v1.0, DCE should deliver:

1. **A background simulation that runs without players present.**
   Organizations accrue money, adjust territory influence, and change heat/state over time using Layer 0 statistical simulation — measurable via the admin dashboard, not just asserted.

2. **At least one fully working CAD/MDT integration.**
   A real adapter (e.g., ERS Dispatch) that receives generated calls, receives call updates as an incident escalates, and can be swapped without touching core code — proving the adapter pattern actually works, not just that it's designed well on paper.

3. **Event escalation that plays out over real time.**
   At least one full example (e.g., drug deal → robbery → shots fired → pursuit) implemented end-to-end through the Event Director, with configurable probabilities at each stage.

4. **Evidence that leads somewhere.**
   Evidence generated at a scene should be inspectable and at minimum linkable to a suspect/vehicle — the full investigation graph doesn't need to be complete, but the core "does evidence do anything" question must be answered yes.

5. **Persistence across restarts.**
   Organization state, territory ownership, and heat must survive a server restart. This is a hard requirement, not a stretch goal — a simulation that resets isn't living.

6. **A working plugin path.**
   At least one non-trivial example plugin (e.g., a second organization archetype, or a second dispatch adapter) built purely through the SDK, with no edits to DCE core, proving the boundary actually holds.

7. **Baseline admin visibility.**
   An admin can see, at minimum: current organizations and their key stats, active incidents, and basic performance metrics (tick cost). Full analytics dashboards and the World Chronicle are not required for v1.0 but the data plumbing for them should exist.

## Explicitly Deferred (Not v1.0)

These are real parts of the long-term vision, but attempting them in v1.0 risks the project never shipping anything:

- Full leadership hierarchy and internal gang politics (succession, splintering, defection)
- Full supply-chain economy simulation (lab → warehouse → dealer → laundering, fully modeled)
- Civilian personality/trust modeling beyond basic reaction behaviors (flee/call/hide)
- Multiple simultaneous CAD/MDT adapters shipped out of the box
- Visual drag-and-drop Scenario Composer (v1.0 can have configurable escalation via data files; the GUI editor is later)
- World Chronicle / in-game news feed
- Cross-server / cluster support
- Categorized heat (Police/Media/Federal/Gang/Civilian Fear) — v1.0 can ship with a single heat value per organization; splitting it is a v1.5+ concern

Deferring these is not a statement that they don't matter — it's a statement that v1.0 needs to prove the core loop works before the framework earns the right to get more elaborate.

## Non-Goals

Things DCE is deliberately not trying to do, at any version:

- Replace a dispatch/CAD system. DCE generates and updates calls; it integrates with dispatch resources, it doesn't try to become one.
- Provide combat, animation, or ped-model content. DCE is a decision/simulation layer, not an asset pack.
- Guarantee identical behavior across all servers. Configurability is a goal; two DCE servers behaving very differently because they're configured differently is a success, not a bug.

## What Failure Looks Like

Concrete signs the project has drifted from its goals, worth checking against periodically:

- A server owner needs to edit core Lua files to get the behavior they want (violates data-driven principle).
- Adding a second CAD/MDT adapter requires changes to non-integration code (adapter pattern isn't holding).
- The simulation can't run acceptably with zero players online without spawning NPCs (Layer 0 isn't actually lightweight).
- A plugin author has to ask "how do I do X" and the answer is "you can't without editing core" (SDK surface is incomplete).
- Nobody can explain why a given event happened without reading the code (Event Director scoring isn't legible/debuggable).
