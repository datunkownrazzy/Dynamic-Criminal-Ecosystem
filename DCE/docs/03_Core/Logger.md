# DCE Logger

**Status:** Accepted
**Version:** 1.0
**Owner:** Datunkownrazzy
**Dependencies:** DCE Core Overview, Glossary

---

## Purpose

A shared logging interface so output across every DCE module — core, world simulation, AI, dispatch, evidence, plugins — is consistent in format, filterable by severity and by module, and usable for actually diagnosing problems on a live server. This replaces ad hoc `print()` calls scattered across resources with no consistent shape.

---

## Design

### Basic Usage

```lua
DCE:Log("Territory", "info", "Rancho ownership changed to Families")
DCE:Log("Dispatch", "warn", "No adapter loaded — falling back to native dispatch")
DCE:Log("AI", "error", "Organization 'ballas' has no registered personality profile")
```

Signature: `DCE:Log(source, level, message, context)`

- `source` — the module/service name emitting the log (matches Service Registry naming where applicable), so output can be filtered per-system.
- `level` — one of `debug`, `info`, `warn`, `error` (see Levels below).
- `message` — plain text, human-readable, using DCE terminology from `Glossary.md`.
- `context` (optional) — a table of structured extra data (e.g., `{ organizationId = "families", territoryId = "rancho" }`), kept separate from the message string so it can be inspected programmatically (e.g., by the developer console) rather than parsed out of text.

### Levels

| Level | Use for |
|---|---|
| `debug` | Verbose detail useful only while actively developing/debugging a specific system. Off by default. |
| `info` | Normal, expected state changes worth a record (territory changed hands, plugin loaded successfully). |
| `warn` | Something unexpected but non-fatal — a missing optional service, a fallback being used, a config value out of range that was clamped. |
| `error` | Something that prevented a module or feature from working as intended — failed validation, a required dependency missing at a point where it's actually required. |

### Filtering

Server owners configure minimum log level globally and, optionally, per-source override:

```lua
Config.Logging = {
    DefaultLevel = "info",
    Overrides = {
        AI = "debug",       -- verbose output just for AI while tuning behavior
        Dispatch = "warn",  -- quiet down a noisy module
    },
}
```

This follows the layered config approach from `Configuration_Philosophy.md` — a sensible global default, overridable per-module without editing every module's own config.

### Format

Console output should be consistent and greppable:

```
[DCE:Territory] [INFO] Rancho ownership changed to Families
[DCE:Dispatch] [WARN] No adapter loaded — falling back to native dispatch
```

Structured `context` data, if present, should be available to a developer console lookup (`dce.debug log <id>`, referenced in `Architecture_Overview.md`) rather than always dumped inline into the console, to keep default output readable.

---

## What Should Never Go Through `print()` Directly

Once `dce-core`'s Logger is available, no DCE module should call raw `print()` — doing so bypasses filtering, source tagging, and the future admin log viewer entirely. This should be called out explicitly in code review (see the checklist in `Coding_Standards.md`).

## Relationship to the Event Bus

Logging is not a substitute for emitting Events (`DCE-0002`) and vice versa:
- **Log** something because a human needs to be able to read about it later, for debugging or auditing.
- **Emit** something because another system needs to programmatically react to it.

Many occurrences warrant both — e.g., a territory ownership change should both emit `territory:ownership:changed` (for Dispatch/Analytics/etc. to react to) and log an `info` line (for a human reading server console/logs to notice). Neither replaces the other.

---

## API Surface

```lua
DCE:Log(source, level, message, context)

DCE:SetLogLevel(source, level)   -- runtime override, e.g. via admin command
DCE:GetLogLevel(source) -> level
```

## Consequences

- Requires every module to adopt `DCE:Log` instead of `print` consistently — worth enforcing early, since retrofitting logging conventions across a large codebase later is tedious and error-prone.
- Structured `context` data adds a small amount of overhead per call versus a bare string — acceptable given logging is not expected to run at Layer-0-tick frequency; if a module finds itself logging every tick, that's more likely a Scheduler/metrics concern (`Scheduler.md`) than a Logger one.
