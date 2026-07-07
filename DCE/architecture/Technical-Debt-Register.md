# Technical Debt Register
**DCE Foundation Audit - Sprint 001D**

## Outstanding Issues (Post-Audit)

| ID | Issue | Category | Priority | Status | Remediation |
|----|-------|----------|----------|--------|-----------|
| TD-001 | Investigation service not implemented | Feature | Low | Deferred | Planned for v1.5+ |
| TD-002 | MDT adapter not implemented | Adapter | Low | Deferred | Planned for v1.5+ |
| TD-003 | Analytics adapter not implemented | Adapter | Low | Deferred | Planned for v1.5+ |
| TD-004 | Scenario adapter not implemented | Adapter | Low | Deferred | Planned for v1.5+ |
| TD-005 | Cross-server sync not implemented | Feature | Low | Deferred | Planned for v2.0 |
| TD-006 | World Chronicle not implemented | Feature | Low | Deferred | Planned for v2.0 |

## Fixed in This Sprint

| ID | Issue | Fix Applied |
|----|-------|-------------|
| FIXED-001 | Missing native evidence adapter | Created `dce-evidence/adapters/native.lua` with all required methods |
| FIXED-002 | Evidence ERS adapter global name mismatch | ERS adapter sets `_G.DCEERSEvidenceAdapter`, fixed evidence service reference |
| FIXED-003 | Dispatch ERS adapter global name mismatch | ERS adapter sets `_G.DCEERSDispatchAdapter`, fixed dispatch init.lua reference |
| FIXED-004 | Dispatch native adapter global name mismatch | Fixed `_G.DCENativeAdapter` → `_G.DCENativeDispatchAdapter` in native.lua |
| FIXED-005 | Adapter types missing methods | Added `IsAvailable`, `GetDiagnostics`, `HealthCheck` to type definitions |
| FIXED-006 | Missing globals in .luarc.json | Added DCE, Config, and all module globals |

## Known Limitations

### Configuration Validation
- No runtime validation of configuration values
- Some config paths lack proper fallback defaults
- Hot reload for configs not fully implemented

### Performance Monitoring
- Profiler metrics collection present but not integrated with all services
- Scheduler task metrics available but not aggregated
- Event bus metrics not exposed for monitoring

### Event Catalog Compliance
- `evidence:item:created` vs catalog `evidence:item:recovered` - variant naming
- `dispatch:call:updated` and `dispatch:call:resolved` not in v1 catalog but needed for complete workflow

## Compatibility Shims

| Resource | Shim | Purpose |
|----------|------|---------|
| All Resources | `_G[name]` module exports | FiveM resource loading order safety |
| All Services | Defensive nil checks | Resource timing safety per ADR-0001 |
| Core API | `exports['dce-core']:GetDCEAPI()` | Resource-to-resource communication |

## Future Improvements (Post-v1.0)

### Priority 1 (v1.1)
1. Add configuration validation with schema checking
2. Implement investigation service for case management
3. Add MDT adapter for Sonoran CAD integration

### Priority 2 (v1.2)
1. Cross-server sync infrastructure
2. World Chronicle for historical tracking
3. Extended analytics adapter

### Priority 3 (v1.5+)
1. Federal/political pressure systems
2. Advanced scenario templates
3. Plugin hot-reload support