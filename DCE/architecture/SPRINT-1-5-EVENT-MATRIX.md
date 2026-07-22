# Sprint 1.5 — Event Matrix

**Date:** 2026-07-17
**Status:** ALL EVENTS CLASSIFIED

---

## Classification Key

| Classification | Meaning |
|---------------|---------|
| ACTIVE | Currently emitted and consumed by active subscribers |
| PASSIVE | Emitted as informational, no mandatory consumer |
| INTERNAL | Emitted and consumed within the same service/resource |
| FIRE_AND_FORGET | Intentionally no subscriber; informational/logging only |
| DEPRECATED | Still emitted but should be removed in next version |
| REMOVE | Emitted but unreachable or never consumed; safe to remove |

---

## Core Events (dce-core)

| Event | Emitter | Subscribers | Purpose | Classification | Runtime Frequency |
|-------|---------|-------------|---------|---------------|-------------------|
| `core:initialized` | init.lua:349 | EventBus listeners | Signals core startup complete | ACTIVE | Once per startup |
| `service:registered:*` | registry.lua:58 | EventBus listeners | Reports new service registration | PASSIVE | Per service registration |
| `service:unregistered:*` | registry.lua:116 | EventBus listeners | Reports service removal | PASSIVE | Per service unregistration |
| `eventbus:handler:error` | eventbus.lua:102 | EventBus listeners | Reports handler execution errors | ACTIVE | Per handler error |
| `sdk:organization:registered` | init.lua:234 | Organization service | Signals SDK org registration | ACTIVE | Per SDK org registration |
| `sdk:adapter:registered` | init.lua:252-300 | Adapter manager | Signals SDK adapter registration | ACTIVE | Per adapter registration |
| `sdk:behavior:registered` | init.lua:309 | Scenario engine | Signals SDK behavior registration | ACTIVE | Per behavior registration |
| `sdk:escalation:registered` | init.lua:327 | Scenario engine | Signals SDK escalation registration | ACTIVE | Per escalation registration |

---

## Session Events (dce-controlcenter)

| Event | Emitter | Subscribers | Purpose | Classification | Runtime Frequency |
|-------|---------|-------------|---------|---------------|-------------------|
| `session:created` | session-manager.lua:68 | EventBus listeners | Reports new session creation | ACTIVE | Per /dce command |
| `session:started` | session-manager.lua:92 | EventBus listeners | Reports session activation | ACTIVE | Per session start |
| `session:closed` | session-manager.lua:127 | EventBus listeners | Reports session closure | ACTIVE | Per session close |
| `session:ended` | session-manager.lua:146 | EventBus listeners | Reports session destruction | ACTIVE | Per session end |
| `controlcenter:resource:stopping` | server/init.lua:97 | EventBus listeners | Signals resource shutdown | FIRE_AND_FORGET | Once per resource stop |
| `controlcenter:focus:acquired` | focus-manager.lua:46 | EventBus listeners | Reports focus acquisition | ACTIVE | Per focus change |
| `controlcenter:focus:released` | focus-manager.lua:46 | EventBus listeners | Reports focus release | ACTIVE | Per focus change |

---

## Forwarded Events (via EventForwarder)

| Event | Emitter | Subscribers | Purpose | Classification | Runtime Frequency |
|-------|---------|-------------|---------|---------------|-------------------|
| `operation:state_changed` (forwarded) | EventBridge | NUI JS | Real-time operation updates | PASSIVE | Per state change |
| `intelligence:updated` (forwarded) | EventBridge | NUI JS | Real-time intelligence updates | PASSIVE | Per update |
| `heat:changed` (forwarded) | EventBridge | NUI JS | Real-time heat updates | PASSIVE | Per change |
| `territory:changed` (forwarded) | EventBridge | NUI JS | Real-time territory updates | PASSIVE | Per change |
| `economy:updated` (forwarded) | EventBridge | NUI JS | Real-time economy updates | PASSIVE | Per update |
| `world:state_changed` (forwarded) | EventBridge | NUI JS | Real-time world state updates | PASSIVE | Per state change |

**Note:** These six events are registered in `event-forwarder.lua:29-36` but no domain service currently emits them with matching names. They are forwarded preemptively for future use.

---

## NUI Messages (Lua→JS)

| Action | Emitter (Lua) | Handler (JS) | Purpose | Classification |
|--------|--------------|--------------|---------|---------------|
| `bootstrap:ready` | bootstrap.lua:38, browser-manager.lua:19 | bootstrap.js | Notifies JS of NUI ready state | ACTIVE |
| `application:boot` | session-manager-client.lua:63 | bootstrap.js → app-manager.js | Triggers JS lazy initialization | ACTIVE |
| `application:restore-workspace` | session-manager-client.lua:80 | app-manager.js | Restores previous workspace state | PASSIVE |
| `application:activate` | bootstrap.lua:72 | app-manager.js | Activates desktop visibility | ACTIVE |
| `application:shutdown` | session-manager-client.lua:90 | app-manager.js | Triggers JS cleanup | ACTIVE |
| `lifecycle:cleanup` | browser-manager.lua:31 | lifecycle.js | Resets JS state | ACTIVE |
| `eventbus:event` | event-forwarder.lua:40 | plugin-host.js | Forwards EventBus events to JS plugins | PASSIVE |

---

## NUI Callbacks (JS→Lua)

| Callback | Emitter (JS) | Handler (Lua) | Purpose | Classification |
|----------|-------------|--------------|---------|---------------|
| `dce-cc:nui:loaded` | bootstrap.js:79 | bootstrap.lua:45 | Reports NUI DOM ready | ACTIVE |
| `dce-cc:nui:escape` | window-manager.js | bootstrap.lua:50 | Escape key pressed | ACTIVE |
| `dce-cc:nui:close` | window-manager.js | bootstrap.lua:55 | Close button clicked | ACTIVE |
| `dce-cc:application:booted` | app-manager.js:131 | bootstrap.lua:66 | JS boot sequence complete | ACTIVE |
| `dce-cc:session:started` | app-manager.js:164 | session-controller.lua:22 | UI visible confirmation | ACTIVE |
| `dce-cc:session:closed` | window-manager.js | session-controller.lua:27 | Session closed by UI | ACTIVE |
| `dce-cc:session:error` | app-manager.js:140 | session-controller.lua:32 | Error during session | ACTIVE |
| `dce-cc:window:allClosed` | window-manager.js | session-controller.lua:37 | All windows closed | PASSIVE |
| `dce-cc:workspace:save` | window-manager.js | session-controller.lua:41 | Save workspace state | PASSIVE |
| `dce-cc:eventbus:subscribe` | plugin-host.js | event-forwarder.lua:55 | JS requests event subscription | ACTIVE |

---

## FiveM Events

| Event | Direction | Purpose | Classification |
|-------|-----------|---------|---------------|
| `dce-cc:server:open` | Client→Server | Requests control center open | ACTIVE |
| `dce-cc:server:close` | Client→Server | Requests control center close | ACTIVE |
| `dce-cc:server:eventbus:subscribe` | Client→Server | Requests EventBus subscription bridge | ACTIVE |
| `dce-cc:client:session:start` | Server→Client | Triggers session start on client | ACTIVE |
| `dce-cc:client:session:reuse` | Server→Client | Triggers session reuse on client | ACTIVE |
| `dce-cc:client:session:end` | Server→Client | Triggers session end on client | ACTIVE |
| `dce-cc:client:eventbus` | Server→Client | Forwards EventBus events to client | ACTIVE |
| `dce-cc:session:close` | Client→Server | Client requests session close | ACTIVE |
| `dce-cc:session:ended` | Client→Server | Confirms session ended | ACTIVE |

---

## Event Classification Summary

| Classification | Count | Notes |
|---------------|-------|-------|
| ACTIVE | 22 | Core operational events with confirmed subscribers |
| PASSIVE | 8 | Informational emissions, may not have consumers |
| INTERNAL | 0 | All events cross module boundaries |
| FIRE_AND_FORGET | 1 | `controlcenter:resource:stopping` |
| DEPRECATED | 0 | No deprecated events |
| REMOVE | 0 | All events serve a purpose |

---

## Dead Event Path Analysis

| Path | Type | Assessment |
|------|------|------------|
| event-forwarder.lua:29-36 events | ACTIVE → PASSIVE | Events are subscribed but no current emitter produces them with matching names. Safe to keep as forward-compatible infrastructure. |
| `dce-cc:server:eventbus:subscribe` → TriggerClientEvent | ACTIVE | Functions correctly when EventBus.On is called. No dead path. |

**No unknown events remain.**