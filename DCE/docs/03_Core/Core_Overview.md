# DCE Core Overview

**Status:** Accepted
**Version:** 1.0
**Owner:** Datunkownrazzy
**Dependencies:** DCE-0001, DCE-0002

---

## Purpose

`dce-core` is the one resource every other DCE resource depends on. It provides the foundational mechanisms — Service Registry, Event Bus, Scheduler, Logger, Config loader — that everything else is built on top of. Nothing simulation-specific (no organizations, no territories, no dispatch logic) lives here. If a piece of code has any opinion about *crime*, it doesn't belong in core.

This document is the map for Phase 3; each component below has (or will have) its own detailed spec.

---

## What Lives in Core

| Component | Responsibility | Spec |
|---|---|---|
| Service Registry | Modules find each other by name | `specifications/DCE-0001-Service-Registry.md` |
| Event Bus | Modules publish/subscribe to state changes | `specifications/DCE-0002-Event-Bus.md` |
| Scheduler | Centralized, config-aware tick/interval management | `docs/03_Core/Scheduler.md` |
| Logger | Consistent, leveled logging across all modules | `docs/03_Core/Logger.md` |
| Config Loader | Loads, validates, and layers config per `Configuration_Philosophy.md` | `docs/03_Core/Configuration.md` |
| Plugin Manager | Validates manifests, gates plugin activation | `specifications/DCE-0003-Plugin-Manifest.md` |

## What Does Not Live in Core

- Anything organization/territory/dispatch/evidence-specific — those are `dce-world`, `dce-ai`, `dce-dispatch`, `dce-evidence`, etc.
- Anything UI-related — that's `dce-ui`/`dce-admin`.
- Anything tied to a specific third-party CAD/MDT — that's `dce-integrations` and its adapters.

Keeping core this narrow is deliberate: every other resource depends on core, so anything added here increases the "blast radius" of a bug or a breaking change across the entire framework. When in doubt, put new functionality in a more specific resource, not core.

---

## Why a Shared Scheduler and Logger (and not just `Wait()` and `print()` everywhere)

FiveM's raw `CreateThread`/`Wait` and `print` are available to every module already, so it's fair to ask why core needs to wrap them.

- **Scheduler:** Without a shared scheduler, every module manages its own `CreateThread` loops with independently hardcoded (or independently configured) intervals, making it hard to answer "what's actually running right now and how often" — which directly undermines the performance monitoring goals in `Architecture_Overview.md` and `Goals.md`. A shared Scheduler gives every tick a name, a configured interval, and a place to measure cost.
- **Logger:** Raw `print` output is hard to filter, has no consistent format, and can't be selectively silenced per module or per severity. A shared Logger gives every module consistent, leveled, filterable output — which matters a lot once a dozen resources are all running simultaneously and something needs debugging in production.

Both are thin wrappers, not heavy frameworks — the goal is consistency, not novelty.

---

## Startup Order Within Core Itself

Core's own internal pieces have a strict load order (this is the one place a fixed order is acceptable, since it's a single resource, not cross-resource):

1. Logger (nothing else can usefully report problems without it)
2. Config Loader (Scheduler and others need config values)
3. Service Registry
4. Event Bus
5. Scheduler
6. Plugin Manager

Everything outside `dce-core` follows the flexible, order-tolerant pattern in `Lifecycle_and_Dependency_Injection.md` instead.

---

## Global Namespace

Core exposes a single global table, `DCE`, as the entry point for everything described above:

```lua
DCE:RegisterService(...)   -- DCE-0001
DCE:GetService(...)        -- DCE-0001
DCE:Emit(...)              -- DCE-0002
DCE:On(...)                -- DCE-0002
DCE:Schedule(...)          -- Scheduler
DCE:Log(...)               -- Logger
DCE:GetConfig(...)         -- Config Loader
```

No DCE module should introduce a second global table for framework-level concerns — everything foundational goes through `DCE`. Module-specific globals (if genuinely needed) should be namespaced clearly (e.g., avoid generic names like `Territory` as a bare global; prefer accessing it via `DCE:GetService("Territory")`).
