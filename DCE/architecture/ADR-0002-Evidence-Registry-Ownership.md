# ADR-0002: Evidence Ownership Moves to the Evidence Service and Registry

**Status:** Accepted  
**Date:** 2026-07-04  
**Owner:** Architecture  
**Related:** Evidence Service, Evidence Registry, Inventory Adapters, Investigation Engine, MDT

---

## Context

The prior evidence model encoded investigation context into dynamically generated inventory item names. That approach made the inventory representation the effective source of truth. It worked for simple inventory displays, but it did not scale to persistent investigations, multiple organizations, long-running worlds, or adapter replacement.

DCE's architectural rules require a single owner for each domain of state. Evidence is a stateful investigative domain and therefore needs a clear authoritative owner rather than an integration-specific representation.

The problem was to define a model that:

- preserves service ownership,
- supports long-lived investigations,
- remains integration-agnostic,
- allows different inventory systems to be replaced without changing evidence semantics,
- and keeps evidence state separate from presentation.

---

## Decision

Adopt an Evidence Registry architecture in which:

- the Evidence Service is the authoritative owner of evidence state,
- the Evidence Registry is the single source of truth for evidence records,
- inventory systems are adapters that present evidence but do not own it,
- MDT and investigations read evidence through the Evidence Service,
- and scenarios may generate evidence candidates without directly persisting evidence state.

Evidence will be identified by a stable EvidenceID and linked into an investigation graph with confidence, custody, and verification metadata.

---

## Rationale

This model is consistent with DCE's architectural principles:

- it gives evidence a single authoritative owner,
- it prevents inventory systems from becoming the source of truth,
- it supports persistence and restart recovery,
- it keeps third-party integrations replaceable,
- and it separates evidence data from presentation concerns.

It also aligns the design with the existing DCE service boundary model: services own state, adapters translate data, and consumers read from the owning service.

---

## Consequences

### Positive

- Evidence becomes durable, queryable, and independent of inventory naming.
- The architecture scales to investigations that span multiple systems and long time horizons.
- Inventory integrations remain replaceable without changing the evidence model.
- The Evidence Service becomes the central owner for lifecycle, custody, relationships, and confidence.

### Negative

- The older naming-based evidence approach is no longer valid for new design work.
- Inventory adapters must now resolve evidence through the Evidence Service instead of treating item names as authoritative.
- Documentation and integration contracts must be updated to reflect the new boundary.

### Mitigations

- Maintain the registry contract as the canonical evidence reference.
- Use adapter-specific display labels only as presentation views.
- Keep evidence ownership and mutation rules explicit in the service contracts and architecture docs.
