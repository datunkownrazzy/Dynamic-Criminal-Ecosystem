# Evidence Naming Protocol

**Status:** Superseded
**Version:** 2.0
**Owner:** Datunkownrazzy
**Dependencies:** Evidence Registry, Inventory Adapters, Evidence Service

---

## Status

This document has been superseded by the Evidence Registry architecture. The older naming-based evidence approach is no longer valid for new design work and is retained only as a historical reference.

## Previous Approach

The earlier approach encoded investigation context into dynamically generated inventory item names. That pattern was useful for simple inventory displays, but it made the inventory item itself the source of truth. It does not scale to persistent investigations, multiple organizations, or long-running worlds.

## Replacement Model

Evidence should now be represented as a registry record owned by the Evidence Service. Inventory systems only display a label or reference to that record. The authoritative data lives in the Evidence Registry, not in the inventory item name.

## Related Documents

- [../11_Evidence/Evidence_Registry.md](../11_Evidence/Evidence_Registry.md)
- [../16_Integrations/Inventory_Integration.md](../16_Integrations/Inventory_Integration.md)
- [../11_Evidence/Evidence.md](../11_Evidence/Evidence.md)