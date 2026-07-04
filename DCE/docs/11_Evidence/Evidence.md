# Evidence Service

**Status:** Draft
**Version:** 1.0
**Owner:** Datunkownrazzy
**Dependencies:** Service Registry, Event Bus, Integration Manager, Investigation Engine

---

## Purpose

The Evidence Service is the authoritative owner of evidence state in DCE. It manages the Evidence Registry, evidence lifecycle, confidence scoring, chain of custody, evidence relationships, and persistence. It exposes evidence to investigations, MDT systems, and inventory integrations without allowing those integrations to become the source of truth.

This follows the DCE ownership rule that state belongs to exactly one Service and that adapters only translate data.

## Core Model

Evidence is modeled as a registry-backed record rather than as an inventory item payload. The Evidence Service owns the canonical record and exposes a stable interface for:

- creating evidence records,
- updating lifecycle state,
- recording custody events,
- linking evidence to investigations and entities,
- querying evidence by case, scenario, or entity,
- and surfacing evidence to inventory and MDT adapters.

## Evidence Registry

The Evidence Registry is the single source of truth for evidence. Every evidence item receives a unique EvidenceID, is stored with confidence and reliability metadata, and is linked into an investigation graph.

The registry is responsible for:

- identity and persistence,
- ownership and custody history,
- confidence and verification status,
- relationship mapping,
- and cross-system lookup.

More detail is documented in [Evidence_Registry.md](Evidence_Registry.md).

## Evidence Factory

Scenarios and simulation systems may generate evidence requests, but they do not persist evidence directly. The Evidence Factory prepares evidence candidates for registration and hands them to the Evidence Service.

This separates scenario generation from evidence ownership and prevents integration logic from becoming authoritative.

## Inventory Adapters

Inventory systems are presentation layers. They may display evidence, store an EvidenceID or reference code, and resolve a full evidence record when examined, but they do not own evidence state.

The adapter contract is documented in [Inventory_Integration.md](../16_Integrations/Inventory_Integration.md).

## Evidence Graph and Confidence

The Evidence Service maintains relationships between evidence and the entities that make investigations meaningful:

- organizations,
- NPCs and agents,
- vehicles,
- properties,
- scenarios,
- cases,
- dispatch calls,
- and other evidence records.

Each evidence object carries a confidence profile that reflects reliability, freshness, and verification status rather than guaranteeing a conclusion.

## Service Boundaries

The Evidence Service is the only module that mutates evidence state. Other systems may:

- request evidence creation,
- query evidence data,
- subscribe to evidence events,
- or render evidence to users.

They must not rewrite evidence state directly.

## Related Documents

- [Evidence_Registry.md](Evidence_Registry.md)
- [../16_Integrations/Inventory_Integration.md](../16_Integrations/Inventory_Integration.md)
- [../02_Architecture/Architecture_Overview.md](../02_Architecture/Architecture_Overview.md)