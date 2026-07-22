# Event Model — Sprint 1.9 Freeze

**Version:** 1.0.0
**Status:** FROZEN

## Event Contract Structure

Every event includes:

| Field | Description |
|-------|-------------|
| Owner | Which service owns this event |
| Producers | Which modules emit this event |
| Version | eventVersion integer for contract validation |
| Lifecycle | "active" \| "future_reserved" \| "deprecated" \| "obsolete" |
| Priority | 0=critical, 1=high, 2=normal, 3=low |
| Reliability | "at-most-once" \| "at-least-once" \| "exactly-once" |
| RequiredFields | Expected payload schema (dot notation) |
| Description | Human-readable description |

## Canonical Events

### Active Events

| Event | Owner | Version | Priority | Reliability |
|-------|-------|---------|----------|-------------|
| core:initialized | dce-core | 1 | 0 (critical) | exactly-once |
| lifecycle:service:stateChanged | dce-core | 1 | 1 (high) | at-least-once |
| lifecycle:resource:stateChanged | dce-core | 1 | 1 (high) | at-least-once |

### Future Reserved Events

| Event | Owner | Version | Priority | Reliability |
|-------|-------|---------|----------|-------------|
| sdk:organization:registered | dce-core | 1 | 2 (normal) | at-most-once |
| sdk:adapter:registered | dce-core | 1 | 2 (normal) | at-most-once |
| sdk:behavior:registered | dce-core | 1 | 2 (normal) | at-most-once |
| sdk:escalation:registered | dce-core | 1 | 2 (normal) | at-most-once |

## Automatic Detection

The EventRegistry automatically detects:
- **Duplicate events** — same name defined twice
- **Payload drift** — payload doesn't match contract
- **Unknown emitters** — event emitted by non-contract producer
- **Orphan consumers** — subscriber exists for undefined event
- **Version conflicts** — eventVersion mismatch

## Rules

1. Future Reserved SDK events remain Future Reserved
2. Do NOT fabricate subscribers to silence diagnostics
3. Every event must have a defined contract before emission
4. Payload validation is performed at Emit() time