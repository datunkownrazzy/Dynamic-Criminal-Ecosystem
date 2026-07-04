# DCE Data Ownership Contract

**Status:** Draft
**Version:** 0.1
**Owner:** Datunkownrazzy
**Applies To:** World, AI, Dispatch, Evidence, Territory, Economy, and Investigation systems

---

## Purpose

This document defines which module owns each piece of simulation state and which modules may only read or request changes. It is the guardrail that prevents modules from bypassing the Service Registry and mutating each other's internal state.

A clear ownership model is essential for stability, debugging, and plugin compatibility.

---

## Ownership Principles

1. Each domain of state has exactly one authoritative owner.
2. Other modules may observe state through Services or Events.
3. Other modules may request changes through the owning Service or an explicit action interface.
4. No module may mutate another module's state directly.
5. State changes must be emitted through the Event Bus when other systems may need to react.

---

## Ownership Matrix

| Domain | Authoritative Owner | Read Access | Write Access | Change Request Pattern |
|---|---|---|---|---|
| World state and simulation context | `dce-world` | Any module | Only `dce-world` | Event or service request |
| Organization state and decision memory | `dce-ai` | Any module | Only `dce-ai` | Service request or event |
| Territory state and lifecycle | `dce-territories` | Any module | Only `dce-territories` | Service request or event |
| Evidence state and decay | `dce-evidence` | Any module | Only `dce-evidence` | Service request or event |
| Dispatch state and call lifecycle | `dce-dispatch` | Any module | Only `dce-dispatch` | Service request or event |
| Economy state and financial flow | `dce-economy` | Any module | Only `dce-economy` | Service request or event |
| Procurement orders and purchase lifecycle | `dce-economy` | Any module | Only `dce-economy` | Service request or event |
| Investigation context and case graph | `dce-investigations` | Any module | Only `dce-investigations` | Service request or event |

---

## Ownership Rules by Concern

### World state

The World service owns static and dynamic simulation context such as time, weather, region context, and broad environmental state. Other modules may read it but should not mutate it directly.

### Organization state

The AI service owns Organization goals, Heat, Intelligence, and planning state. Dispatch and Evidence may consume that state, but they must not rewrite it directly.

### Territory state

Territory ownership, control, and lifecycle details are owned by the Territories service. Other modules may read territory state and request changes through the Territories Service.

### Evidence state

Evidence records, linkages, confidence metadata, custody history, and persistence are owned by the Evidence Service. Other systems may reference evidence, request registration or updates, or render evidence in integrations, but they may not alter evidence state except through the owning Service or its documented request interface.

### Dispatch state

Dispatch calls, status transitions, and integration handoff are owned by the Dispatch service. Other systems may create or update requests only through its documented interface.

### Economy state

Organization finances, procurement state, and economic modeling are owned by the Economy service. The Economy service owns the authoritative ledger and budget state; other modules may query it or request changes through its Service interface but must not write directly into its state tables.

This is the authoritative ownership model for finance-related state. Organizations may expose runtime fields such as `money` for observation and compatibility, but the Economy service remains the authoritative owner of the financial ledger and derived budget state.

---

## Change Request Pattern

When a module needs another module to change state, it should use one of these patterns:

1. **Service request**: call the owning Service's explicit action method.
2. **Event request**: emit a request-style event that the owner handles.
3. **Read-only observation**: read the state through a getter or query service.

The owning module is always responsible for validating the change and applying it to its own state.

---

## Enforcement

The framework should treat direct cross-module state mutation as a violation of the architecture. Any implementation that reaches into another module's tables or bypasses its Service interface should be treated as a design defect.

This contract is the foundation for predictable plugin behavior and stable future refactors.
