# ADR-0003: Configurable Dispatch and Evidence Integrations with Standalone Fallback

**Status:** Accepted  
**Date:** 2026-07-04  
**Owner:** Architecture  
**Related:** Dispatch Service, Evidence Service, ERS, CAD/MDT integrations

---

## Context

DCE needs to support multiple deployment models:

- servers that run ERS (Emergency Response Simulator),
- servers that use another CAD/MDT or dispatch system,
- and standalone servers that should still function without any third-party integration.

The current dispatch implementation assumed a direct, built-in output path and did not provide a configurable integration seam. Evidence was similarly owned by DCE but had no pluggable adapter path. This made the systems less flexible and prevented server owners from choosing the experience that best fit their environment.

## Decision

Adopt a configuration-driven adapter model for dispatch and evidence integrations:

- Dispatch uses a configurable adapter selected from configuration.
- Evidence uses a configurable adapter selected from configuration.
- If ERS is present and configured, DCE will attempt to use its adapter export.
- If ERS is not present, DCE falls back to its own standalone behavior instead of failing.
- Server owners can choose between native standalone behavior, ERS, or a custom adapter implementation.

The configuration contract is as follows:

- Config.Dispatch.Integration.Mode
- Config.Dispatch.Integration.ResourceName
- Config.Dispatch.Integration.ExportName
- Config.Evidence.Integration.Mode
- Config.Evidence.Integration.ResourceName
- Config.Evidence.Integration.ExportName

The service layer remains the authoritative owner of state. External systems act as adapters and do not own DCE state.

## Rationale

This approach preserves the architectural rules:

- service ownership remains intact,
- adapters remain replaceable,
- DCE remains usable on standalone servers,
- and server owners can opt into ERS or another system without changing core gameplay logic.

It also keeps the design compatible with future investigation UIs or CAD/MDT menus because the integration point is explicit and not hard-coded to ERS.

## Consequences

### Positive

- DCE can run with ERS or without it.
- Server owners can configure their preferred dispatch/evidence backend.
- The architecture supports future custom menu integrations.
- Dispatch and evidence remain decoupled from any one external system.

### Negative

- External integrations must implement the expected adapter contract.
- Standalone fallback is intentionally simple and may not provide the same UX as a full CAD/MDT UI.

### Mitigations

- Keep adapter contracts small and explicit.
- Use the DCE event bus for state changes so integrations can react without direct coupling.
- Preserve the standalone path as a reliable default for servers without ERS.
