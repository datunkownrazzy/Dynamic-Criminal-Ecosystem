# DCE-0003: Plugin Manifest Specification

**Status:** Accepted
**Version:** 1.0
**Owner:** Datunkownrazzy
**Dependencies:** DCE-0001 (Service Registry), DCE-0002 (Event Bus)

---

## Purpose

Every DCE plugin declares a manifest describing what it is, what it needs, and what it provides. This lets DCE validate dependency compatibility before loading a plugin, gives server owners visibility into what's installed, and gives the (future) DCE Marketplace a machine-readable format to work from.

A "plugin" in this spec means any resource that extends DCE using only the public SDK (`dce-sdk`) — a new Organization archetype, a new dispatch/MDT Adapter, a new Scenario pack, a new Behavior, etc. Per `Architecture_Overview.md`, there is no special-cased "plugin mode" in core; a plugin is simply a resource that plays by these rules.

---

## Manifest Format

Declared as a Lua table at the top of the plugin's main file (or a dedicated `manifest.lua`):

```lua
Plugin = {
    Name = "South American Cartels",
    Id = "dce-plugin-cartels-sa",         -- unique, stable identifier; used in logs and dependency refs
    Version = "1.0.0",                     -- semver

    Author = "YourNameHere",
    Description = "Adds a cartel organization archetype with convoy and smuggling behaviors.",

    Requires = {
        "dce-core",
        "dce-ai",
    },

    Provides = {
        "Organization",       -- category tags, see "Provides Categories" below
        "Behaviors",
        "Scenario Pack",
    },

    DCE = {
        Min = "1.4.0",         -- minimum compatible DCE core version
        Max = "2.x",            -- maximum compatible DCE core version (supports range syntax)
    },
}
```

### Required Fields

| Field | Type | Notes |
|---|---|---|
| `Name` | string | Human-readable display name |
| `Id` | string | Stable, unique, machine-readable. Should match the FiveM resource folder name by convention. |
| `Version` | string | Semver (`MAJOR.MINOR.PATCH`) |
| `Requires` | array of strings | Other resource `Id`s this plugin needs present and started |
| `Provides` | array of strings | Category tags describing what this plugin adds (see below) |
| `DCE.Min` | string | Minimum DCE core version this plugin is known to work with |

### Optional Fields
 
 | Field | Type | Notes |
 |---|---|---|
 | `Author` | string | |
 | `Description` | string | Shown in admin tooling |
 | `DCE.Max` | string | Maximum known-compatible version; omit if unknown/unbounded |
 | `Homepage` / `Repository` | string | For marketplace listing purposes, later |
 
 ### Performance Metadata (Optional)
 
 | Field | Type | Notes |
 |---|---|---|
 | `DCE.EstimatedCPU` | number (ms) | Estimated CPU time per tick the plugin will consume |
 | `DCE.EstimatedMemory` | number (bytes) | Estimated memory usage |
 | `DCE.TickRequirement` | string | `high`, `medium`, or `low` - expected update frequency |
 
 ---

## Provides Categories

Use these standard tags so admin tooling and the (future) marketplace can categorize plugins consistently. Custom tags are allowed but should be additive, not a replacement for a matching standard tag:

- `Organization` — adds a new criminal organization archetype
- `Behaviors` — adds new AI Director behaviors/activities
- `Scenario Pack` — adds new Event Escalation definitions
- `Dispatch Adapter` — adds a CAD/dispatch integration
- `MDT Adapter` — adds an MDT integration
- `Evidence Adapter` — adds an evidence-system integration
- `Vehicles` / `Weapons` — adds content referenced by other categories
- `UI` — adds admin/analytics tooling

---

## Validation on Load

At startup, DCE core (specifically the Plugin Manager component within `dce-core`/`dce-sdk`) checks each plugin's manifest before letting it activate:

1. **Dependency presence.** Every entry in `Requires` must correspond to a resource that is started. If not, the plugin does not load, and a clear warning is logged naming the missing dependency — never a silent partial load.
2. **Version compatibility.** The running DCE core version must fall within `DCE.Min`/`DCE.Max`. If it doesn't, the plugin does not load, and the log states the version mismatch explicitly.
3. **Id uniqueness.** If two started resources declare the same `Id`, both are rejected and a conflict is logged — this should never be silently resolved by "last one wins."

A plugin that fails validation must not partially register services or subscribe to events. Validation happens before the plugin's `Register`/`Subscribe`/`Activate` phases (per `Lifecycle_and_Dependency_Injection.md`) run at all.

---

## What a Manifest Does Not Do

- It does not grant special permissions — a plugin still only has access to whatever `dce-sdk` exposes publicly. The manifest is metadata, not a capability grant.
- It does not replace the `Requires` dependency being resolved through the normal Service Registry / Lifecycle patterns at runtime — the manifest check is a pre-flight gate, not a substitute for handling `nil` services gracefully as described in `Lifecycle_and_Dependency_Injection.md`. A dependency could still stop mid-session after passing its initial check.

---

## Example: Minimal Valid Manifest

```lua
Plugin = {
    Name = "Custom Dispatch Adapter",
    Id = "dce-plugin-my-dispatch",
    Version = "0.1.0",
    Requires = { "dce-core", "dce-dispatch" },
    Provides = { "Dispatch Adapter" },
    DCE = { Min = "1.0.0" },
}
```

---

## Open Question (flag for an ADR if resolved)

Whether manifest validation errors should be merely logged (current behavior above) or should also surface in the in-game admin dashboard (`dce-ui`) as an actionable notification. Likely "both, eventually" — logging is the v1.0 requirement; the dashboard surface can follow once `dce-ui` exists.
