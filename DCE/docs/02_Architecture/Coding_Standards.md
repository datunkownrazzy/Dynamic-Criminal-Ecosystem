# DCE Coding Standards & AI Developer Guide

**Status:** Accepted
**Version:** 1.0
**Owner:** Datunkownrazzy
**Dependencies:** DCE-0001, DCE-0002, PROJECT_PRINCIPLES.md

---

## Purpose

This document exists so that any contributor — human or an AI coding assistant working from these docs — produces code that's consistent with the rest of DCE without needing to re-derive the architecture from first principles each time. If you (or an assistant) are about to write DCE code and haven't read `PROJECT_PRINCIPLES.md`, `Architecture_Overview.md`, `DCE-0001`, and `DCE-0002` first, stop and read those first — this guide assumes them.

---

## Before Writing Any Code, Ask:

1. **Does this belong in core, or in a plugin?**
   If it's a specific organization archetype, a specific CAD adapter, or a specific scenario pack, it's a plugin — even if it ships alongside core in the same repo initially. Core is the general mechanism; plugins are configurations/extensions of it.

2. **What Service(s) does this need, and what Service does it provide?**
   Write these down before writing implementation. If the answer to "what does this provide" is "nothing, other modules will just call its functions directly," that's a sign it should expose a registered Service instead.

3. **What Events does this need to emit?**
   Anything another system might plausibly want to react to should be emitted, even if nothing currently subscribes. See `DCE-0002` naming conventions.

4. **What's the Layer 0 cost?**
   If this runs for every organization/territory on the whole map, what does it cost per tick? If you don't know, profile it before assuming it's fine — see `PROJECT_PRINCIPLES.md` #7.

---

## File & Module Structure

Each DCE resource follows the phase structure from `Lifecycle_and_Dependency_Injection.md`:

```lua
-- 1. Declare
local Territory = {}
local territories = {}

-- 2. Register
DCE:RegisterService("Territory", Territory)

-- 3. Resolve (lazy or reactive, per Lifecycle doc)
local function GetEconomy()
    return DCE:GetService("Economy")
end

-- 4. Subscribe
DCE:On("organization:activity:started", function(payload) ... end)

-- 5. Activate
CreateThread(function()
    while true do
        -- tick logic
        Wait(Config.TerritoryTickInterval)
    end
end)
```

Avoid a single giant file per resource once a module grows past a few hundred lines — split by concern (e.g., `territory/state.lua`, `territory/lifecycle.lua`, `territory/service.lua`) but keep the Service's public table in one clearly named file so its interface is easy to find.

---

## Naming

- Services: PascalCase (`Dispatch`, `Territory`, `Economy`).
- Event names: `domain:subject:verb`, lowercase (see `DCE-0002`).
- Config keys: PascalCase to match Lua convention (`Config.TerritoryTickInterval`).
- Use DCE terminology from `Glossary.md` consistently — `Organization` not `Gang`, `Agent` not `NPC`, `Scenario` not `Crime`, `Incident` not `Callout`, in code, comments, and log output alike. This is not cosmetic — it keeps generated logs and debug output legible to anyone who's read the docs.

---

## Data-Driven Defaults

Per `PROJECT_PRINCIPLES.md` #2, avoid hardcoding tunable values. If a number affects behavior a server owner might reasonably want to change (probabilities, thresholds, tick intervals, weights), it belongs in a `Config` table or a data file, not inline in logic.

```lua
-- AVOID
if math.random(100) <= 65 then ...

-- PREFER
if math.random(100) <= Config.DrugSale.BaseSuccessChance then ...
```

This also applies to organization personality weights, escalation probabilities, and territory thresholds — these should load from data files under `/schemas/` examples, not be embedded as magic numbers in `dce-ai`.

---

## Error Handling

- Event Bus handlers must not throw uncaught errors that stop other handlers from running (`DCE-0002` requires the bus itself to catch these, but write handlers defensively regardless — don't rely solely on the bus's safety net).
- Service functions that can fail meaningfully (e.g., `Dispatch.CreateCall` when no adapter is loaded) should return a clear success/failure indicator rather than silently no-op-ing, so callers can log or handle it.
- Never assume a resolved Service or a payload field is non-nil just because it usually is. See `Lifecycle_and_Dependency_Injection.md` for handling services that may not exist yet.

---

## Comments & Self-Documentation

- Every emitted event and every registered Service function gets a comment stating its purpose and payload/parameter shape at the point of definition — this is what plugin authors will actually read, more than the specs, in practice.
- Non-obvious scoring/weighting logic (AI Director decisions especially) should include a comment explaining the intended behavior in plain language, not just the math — this is what makes the "why did this happen" question answerable later.

---

## Working With AI Coding Assistants on DCE

If you're an AI assistant (or a human directing one) implementing against these specs:

- **Do not invent new cross-module dependencies** not described in the relevant spec. If implementing a feature seems to require reaching into another module's internals, stop and flag it — the correct fix is almost always "register a Service and/or emit an Event," not "require the other resource's file directly."
- **Do not hardcode values that should be config.** If unsure whether something is a tunable, default to making it configurable — it's cheaper to remove an unused config option later than to hunt down hardcoded magic numbers across the codebase.
- **When a spec is ambiguous or seems wrong once you're implementing it, say so explicitly** rather than silently deciding an interpretation. Per `Philosophy.md`, specs are expected to need revision sometimes — but that revision should be visible and discussed, not silently absorbed into the implementation.
- **Check `PROJECT_PRINCIPLES.md` before proposing an "easier" implementation** that bypasses the Registry/Bus pattern for convenience. If a genuine exception is warranted, it needs an ADR (see `PROJECT_PRINCIPLES.md` → Exceptions), not a quiet workaround.
- **Match existing terminology** (`Glossary.md`) in new code, comments, commit messages, and generated documentation — don't reintroduce "gang," "NPC," "crime," or "callout" into new material.

---

## Review Checklist (use before merging anything into core)

- [ ] Does this module register any Services it should? Does it avoid providing functionality only through direct exports outside the Registry?
- [ ] Does this module emit events for state changes another system might care about?
- [ ] Are all tunable numbers pulled from Config/data rather than hardcoded?
- [ ] Does this handle a missing/not-yet-registered dependency without crashing (per `Lifecycle_and_Dependency_Injection.md`)?
- [ ] Does shutdown (`onResourceStop`) clean up registrations and subscriptions?
- [ ] Does this use DCE terminology consistently?
- [ ] If this bends a principle, is there an ADR for it?
