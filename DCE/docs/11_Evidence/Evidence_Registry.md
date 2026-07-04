# Evidence Registry

**Status:** Draft
**Version:** 1.0
**Owner:** Datunkownrazzy
**Applies To:** Evidence Service, Evidence Factory, Inventory Adapters, Investigation Engine, MDT, Dispatch

---

## Purpose

The Evidence Registry is the authoritative record of all evidence in DCE. It replaces evidence-as-item-name patterns with a registry-backed model in which evidence exists as a stable record owned by the Evidence Service, while inventories and other integrations merely present or relay that record.

This architecture preserves DCE's service-ownership model: the Evidence Service owns the evidence state, adapters translate the data, and investigations consume the evidence through the owning service.

The registry is the single source of truth for:

- evidence identity,
- lifecycle state,
- chain of custody,
- confidence and reliability,
- relationships between evidence nodes,
- investigation linkage, and
- persistence.

---

## Architectural Principles

1. The Evidence Service owns evidence data.
2. The Evidence Registry is the authority for evidence state.
3. Inventory systems are adapters, not data owners.
4. MDT and investigations read from the Evidence Service.
5. Dispatch may generate leads or incidents, but it never owns evidence.
6. Scenarios may generate evidence candidates, but they do not persist evidence records directly.
7. Evidence should be modeled as part of an investigation graph, not as isolated items.

---

## Evidence Lifecycle

Every evidence record moves through a lifecycle that is managed by the Evidence Service:

1. **Generated**
   - A Scenario, event, or investigation action produces an evidence candidate.
   - The Evidence Factory prepares the candidate for registration.

2. **Registered**
   - The Evidence Registry assigns a unique EvidenceID.
   - Core metadata, ownership, and initial confidence are recorded.

3. **Collected**
   - The evidence is acquired, tagged, or physically linked to a case or scene.
   - Chain-of-custody entries are appended.

4. **Analyzed**
   - Analysts or systems evaluate reliability, freshness, and interpretation.
   - Verification status may change as corroboration is added.

5. **Linked**
   - The evidence is connected to other evidence, persons, vehicles, properties, scenarios, cases, or dispatch calls.
   - This creates the investigation graph.

6. **Persisted**
   - The registry record is written to durable storage.
   - Inventory or external system views are derived from the registry rather than stored independently.

7. **Archived or Discarded**
   - The evidence may remain part of historical case data or be removed from active investigation workflows.
   - Disposition is tracked in the registry.

---

## Evidence Identity

Each evidence item receives a stable, unique identifier.

### Identity Rules

- EvidenceID is assigned by the Evidence Registry.
- EvidenceID must remain stable across inventory re-rendering and investigation refreshes.
- EvidenceID should be opaque to inventory systems.
- The registry may expose a human-readable reference code for integrations, but the registry record remains authoritative.

Example:

- EvidenceID: EVID-004928
- Reference Code: 7Q4-A2

The identifier is not derived from the item name, location, or inventory slot.

---

## Ownership and Write Authority

### Authoritative Owner

The Evidence Service owns the registry record and is the only module that may mutate core evidence state.

### Write Ownership

The following systems may participate in evidence workflows, but only the Evidence Service owns the registry write path:

- Evidence Factory: creates evidence candidates and submits them for registration
- Evidence Registry: stores and updates the authoritative record
- Investigation Engine: requests updates, analysis results, and evidence relationships
- Inventory Adapter: reflects evidence state to an external inventory system

### Read Ownership

The following systems consume evidence state through the Evidence Service or its exposed interface:

- MDT
- Investigation Engine
- Dispatch dashboards
- Admin tools
- Inventory adapters

Inventory systems never become write owners of evidence state.

---

## Chain of Custody

Every evidence record maintains a custody history that documents the movement or handling of the item.

Each custody event should capture:

- actor or system responsible,
- collection or transfer action,
- timestamp,
- location or scene reference,
- storage destination,
- disposition or handoff status.

The chain of custody is append-only from the perspective of the registry. It supports auditability and evidentiary integrity.

---

## Confidence and Reliability

Evidence should never imply certainty by itself. Every registry record should carry a confidence profile:

- Confidence: degree of support for the observed fact
- Reliability: source quality and trustworthiness
- Freshness: age or recency of the evidence
- Verification Status: unverified, partially verified, corroborated, or rejected

Example:

- Shipping Manifest
- Confidence: 42%
- Reliability: Moderate
- Freshness: Recent
- Verification Status: Pending corroboration

Investigations should require multiple, cross-linked evidence items before reaching a high-confidence conclusion.

---

## Evidence Relationships and the Evidence Graph

Evidence is not an isolated object. The registry builds an investigation graph by linking evidence to other entities.

### Supported Relationship Types

Evidence may connect to:

- Organizations
- NPCs or agents
- Vehicles
- Properties
- Scenarios
- Cases
- Dispatch calls
- Other evidence records

Example graph:

Phone → Vehicle → Warehouse → Lieutenant → Organization

This graph supports emergent investigation paths rather than a deterministic progression such as Prospect → Soldier → Lieutenant → Boss.

Evidence can reveal:

- a warehouse,
- a phone number,
- a vehicle,
- a suspect, or
- nothing useful at all,

and some evidence may be intentionally misleading.

---

## Evidence Categories

Evidence should be classified by type so that handling, storage, reliability, and analysis rules can be defined consistently.

| Category | Examples | Collection Method | Storage | Reliability | Decay | Analysis Requirements |
|---|---|---|---|---|---|---|
| Physical | DNA, blood, fingerprints, shell casings | Collection at scene, packaging, sealing | Forensics storage, secure evidence locker | High when collected correctly | Moderate to high | Lab analysis, chain of custody verification |
| Digital | Phones, radios, laptops, USB drives | Seizure, imaging, export | Secure digital storage, access-controlled vault | Variable by source | Low to moderate | Device extraction, metadata review |
| Financial | Ledgers, shipping manifests, receipts, bank transfers | Seizure or export | Secure archive, financial records store | Moderate to high | Low | Correlation, provenance review |
| Intelligence | Surveillance photos, informant notes, graffiti, maps | Collection from human or sensor source | Controlled intelligence vault | Variable | Moderate | Contextual validation, source evaluation |
| Communication | Burner phones, radio logs, messages | Capture or seizure | Secure communications archive | Moderate | Low to moderate | Metadata extraction, timeline correlation |

Each category should define its own handling expectations, but the registry remains the common owner of the evidence record.

---

## Investigation Linkage

Evidence is attached to investigations through a registry relationship rather than through inventory naming.

### Investigation Link Rules

- A single evidence record may belong to one or more active investigations.
- Investigations may surface evidence through queries against the registry.
- Evidence may contribute to multiple leads simultaneously.
- The registry stores the linkage and the relevant case context.

This allows long-running investigations, multiple organizations, and persistent worlds to remain consistent without relying on inventory item text.

---

## Persistence

The registry is the durable persistence boundary for evidence.

Persistence responsibilities include:

- storing evidence metadata,
- storing relationship links,
- preserving chain-of-custody history,
- storing confidence and verification state,
- retaining investigation associations,
- and supporting rehydration after restart.

Inventory state is not itself persisted as the canonical evidence record. Instead, the inventory reflects the registry record after rehydration.

---

## Registry Responsibilities

The Evidence Registry is responsible for:

- creating and assigning EvidenceID values,
- validating evidence shape and required metadata,
- managing lifecycle transitions,
- recording ownership and custody events,
- maintaining relationship links,
- exposing evidence queries for investigations and MDT,
- and preserving evidence state across restart and recovery.

The registry is the only component that should be considered authoritative for evidence state.

---

## Service Interactions

The Evidence Registry participates in DCE through the Service Registry and Event Bus.

### Primary Interactions

- Scenario Engine emits evidence generation requests.
- Evidence Factory prepares evidence candidates.
- Evidence Service registers and updates evidence records.
- Inventory Adapter renders registry-backed evidence into inventory items.
- Investigation Engine queries and links evidence.
- MDT reads evidence records for case presentation.

### Interaction Rule

The Evidence Service is the only module that mutates evidence state. Other systems may request changes, observe data, or subscribe to evidence-related events, but they do not own the evidence record itself.

---

## Read vs Write Ownership

| Concern | Owner |
|---|---|
| Evidence identity and metadata | Evidence Service |
| Chain of custody | Evidence Service |
| Confidence and verification state | Evidence Service |
| Relationship graph | Evidence Service |
| Inventory display | Inventory Adapter |
| MDT presentation | MDT / Investigation consumer |
| Scenario generation | Scenario Engine |

This boundary prevents integration-specific assumptions from becoming the source of truth.
