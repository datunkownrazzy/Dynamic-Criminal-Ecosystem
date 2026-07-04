# Inventory Integration

**Status:** Draft
**Version:** 1.0
**Owner:** Datunkownrazzy
**Applies To:** Inventory adapters, Evidence Service, MDT, Investigation tooling

---

## Purpose

Inventory systems are integrations. They present evidence to players and investigators, but they do not own evidence state. This document defines how evidence should be represented inside inventories while preserving the Evidence Registry as the authoritative source.

The design supports two inventory modes:

- metadata-capable inventories, and
- non-metadata inventories with a fallback reference code.

This keeps inventory systems as adapters rather than owners of evidence state.

- metadata-capable inventories, and
- non-metadata inventories with a fallback reference code.

---

## Architectural Rule

An inventory item is a view of evidence, not the evidence itself.

The inventory may display a label or reference, but the authoritative evidence record remains in the Evidence Registry and is served through the Evidence Service.

---

## Metadata-Capable Inventories

Some inventory systems can store per-item metadata.

### Representation

The inventory item stores:

- EvidenceID

The inventory display shows only a human-readable label such as:

- Shipping Manifest

When the item is examined, the adapter resolves the EvidenceID against the Evidence Service and retrieves the full registry record.

### Flow

1. Inventory adapter receives a registry-backed evidence item.
2. It stores the EvidenceID as metadata.
3. The display name remains a local presentation field.
4. Examination or inspection triggers a lookup in the Evidence Service.
5. The full evidence record is returned from the registry.

### Benefits

- no naming collision,
- stable identity across inventory changes,
- supports persistence and long-running investigations,
- keeps inventory systems replaceable.

---

## Non-Metadata Inventories

Some inventory systems cannot store structured metadata. In that case, the adapter must use a fallback naming convention that encodes a reference code without making the inventory item authoritative.

### Representation

The inventory item display uses a naming format such as:

- Shipping Manifest [7Q4-A2]

The bracketed reference code maps back to the Evidence Registry through the Evidence Service.

### Flow

1. The Evidence Service provides a reference code for the evidence record.
2. The adapter appends that code to the visible item label.
3. When the player examines the item, the adapter resolves the reference code back to the registry entry.
4. The full evidence record is retrieved from the Evidence Service.

### Important Constraint

The reference code is only an integration-level pointer. It is not the source of truth.

---

## Adapter Responsibilities

Inventory adapters are responsible for:

- presenting evidence in the user-facing inventory,
- preserving a stable reference to the EvidenceID or reference code,
- resolving inventory interactions back to the Evidence Service,
- and keeping inventory-specific representation separate from evidence ownership.

Inventory adapters must not:

- define evidence identity independently,
- store evidence lifecycle state,
- decide confidence or chain-of-custody status,
- or become the authoritative record for evidence.

---

## Supported Inventory Examples

### ERS

ERS-style inventories can use EvidenceID metadata where available. If metadata storage is limited, the adapter uses a fallback display code derived from the registry.

### ox_inventory

The adapter may store EvidenceID in item metadata or use a generated display label with a registry reference code.

### qb-inventory

The adapter should mirror the same pattern: inventory item presents the label, while evidence data is resolved from the Evidence Service.

### Standalone DCE Inventory

The DCE-native inventory should use the same contract and treat evidence as registry-derived state.

---

## Examination Model

When an item is examined, the adapter should not assume the inventory text itself contains the full meaning. Instead, it should resolve the evidence using the registry-backed contract.

### Examination Outcome

The inventory viewer may show:

- evidence summary,
- related investigation context,
- confidence and verification status,
- chain-of-custody notes,
- and relationship links.

These details are always sourced from the Evidence Service and the registry.

---

## Integration Boundaries

The inventory layer remains replaceable. A server owner may change from ERS to ox_inventory to a DCE-native inventory without changing the evidence ownership model.

This is achieved by keeping the evidence contract stable:

- inventory systems consume evidence through a standard adapter interface,
- the Evidence Service remains the authority,
- and the registry record is preserved across integration changes.
