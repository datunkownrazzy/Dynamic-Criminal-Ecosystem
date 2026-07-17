# DCE v2 — Technical Debt Assessment

**Date:** 2026-07-10
**Phase:** 2
**Author:** Lead Software Architect

---

## Technical Debt Summary

| Category | Count | Priority |
|----------|-------|----------|
| Missing Implementation | 6 | High/Medium |
| Architecture Consistency | 3 | Low |
| **Total Technical Debt Items** | **9** | Documented |

---

## Missing Implementation Items

| # | Issue | Location | Priority | Estimate | Evidence |
|---|-------|----------|----------|----------|----------|
| 1 | WorldAdapter not implemented | types/adapters/world-adapter.lua | High | Medium | Interface defined, no service registers "WorldAdapter" |
| 2 | OrganizationAdapter not implemented | types/adapters/organization-adapter.lua | High | Medium | Interface defined, no service registers "OrganizationAdapter" |
| 3 | Plugin data endpoints missing | location-manager.lua, organization-editor.lua | High | Low | Plugin JS calls dcc-location:list but no server handler exists |
| 4 | Territory system missing | No territory service | Medium | High | No territory API anywhere, Event_Catalog references missing events |
| 5 | Economy system missing | ROADMAP.md defers to v2+ | Medium | High | No economy module, Event_Catalog references missing events |
| 6 | Investigation system missing | No investigation service | Medium | High | No investigation module, Event_Catalog references missing events |

---

## Architecture Consistency Items

| # | Issue | Location | Priority | Estimate |
|---|-------|----------|----------|----------|
| 7 | Inconsistent shutdown naming | All service files use Shutdown() | Low | Trivial - add Stop() alias |
| 8 | No standardized error return format | Mixed {success=bool} and nil | Low | Medium |
| 9 | Missing health endpoints | No service has GetHealth() | Low | Low |

---

## Technical Debt Categories

### Architecture Debt

| Item | Description | Impact |
|------|-------------|--------|
| WorldAdapter missing | Provider pattern incomplete | Location editing blocked |
| OrganizationAdapter missing | Provider pattern incomplete | Organization editing blocked |

### Feature Debt

| Item | Description | Impact |
|------|-------------|--------|
| Territory system | Deferred to v2+ | Territory visualization impossible |
| Economy system | Deferred | Economy dashboard impossible |
| Investigation system | Not implemented | Investigation UI impossible |

### API Debt

| Item | Description | Impact |
|------|-------------|--------|
| No admin API standardization | GetStatus/GetHealth missing | Inconsistent service management |
| No error format standard | Mixed return types | Inconsistent error handling |

---

## Risk Assessment

| Risk | Severity | Likelihood | Impact |
|------|----------|------------|--------|
| WorldAdapter unimplemented | High | Certain | Location editing completely blocked |
| OrganizationAdapter unimplemented | High | Certain | Organization editing completely blocked |
| Plugin endpoints missing | High | Certain | All plugin dashboards non-functional |
| Territory system missing | High | Certain | Territory visualization impossible |
| No admin API standardization | Medium | Certain | Health monitoring inconsistent |

---

## Recommended Remediation Order

| Priority | Task | Effort |
|----------|------|--------|
| 1 | Implement WorldAdapter | Medium |
| 2 | Implement OrganizationAdapter | Medium |
| 3 | Add plugin data endpoints | Low |
| 4 | Add admin APIs to services | Low |
| 5 | Implement Territory system | High (deferred) |
| 6 | Implement Economy system | High (deferred) |
| 7 | Add error format standardization | Medium |
| 8 | Add health endpoints | Low |
| 9 | Standardize shutdown naming | Trivial |