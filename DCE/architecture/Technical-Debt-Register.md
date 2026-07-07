# Technical Debt Register
**DCE Foundation Audit - Sprint 001**

## Audit Findings (Post-Certification Pass)

| ID | Issue | Category | Priority | Status | Resolution |
|----|-------|----------|--------|--------|----------|
| TD-001 | DCE.On cross-resource in dce-evidence | Architecture | Critical | **FIXED** | Migrated to EventBus bridge pattern per ADR-0020 |
| TD-002 | Hardcoded tasks=0 in GetServicesList | API | Medium | **FIXED** | Integrated with Scheduler for accurate task counts |
| TD-003 | GetTasksList calls non-existent Registry.ListTasks | API | Medium | **FIXED** | Changed to direct Scheduler query |
| TD-004 | CoreRegistry missing ListTasks exposure | API | Low | **FIXED** | Admin service now queries Scheduler directly |
| TD-005 | ESC key handler missing in NUI | Control Center | Medium | **FIXED** | Added keydown handler in framework.js and nui.lua |
| TD-006 | Location Manager not implemented | Architecture | High | **FIXED** | Created provider-based Location Manager (ADR-0021) |
| TD-010 | Service lifecycle documentation missing | Documentation | Done | **FIXED** | Created Resource_Lifecycle.md |
| TD-011 | Type system documentation missing | Documentation | Done | **FIXED** | Created Type_System.md |
| TD-012 | Adapter system documentation missing | Documentation | Done | **FIXED** | Created Adapter_System.md |
| TD-013 | Configuration reference missing | Documentation | Done | **FIXED** | Created Configuration.md |
| TD-014 | API reference incomplete | Documentation | Done | **FIXED** | Updated API_REFERENCE.md |
| TD-015 | Event catalog incomplete | Documentation | Done | **FIXED** | Updated Event_Catalog_v1.md with location domain |
| TD-016 | Performance docs missing | Documentation | Done | **FIXED** | Created Performance.md |
| TD-017 | README cross-reference typos | Documentation | Done | **FIXED** | Fixed Architecture/Arcitecture and GUIDE/GUDIE |
| TD-018 | Location Manager missing Shutdown | Architecture | Done | **FIXED** | Added Shutdown method and unregister in dce-world/init.lua |
| TD-019 | World/AI/Events service docs missing | Documentation | Done | **FIXED** | Created World_Service.md, AIDirector_Service.md, ScenarioEngine_Service.md, Location_Manager.md |

## Documentation Improvements Made

### Files Created (11)

1. `DCE/docs/02_Architecture/Resource_Lifecycle.md` - Resource startup/shutdown documentation
2. `DCE/docs/03_Core/Type_System.md` - Type system architecture guide
3. `DCE/docs/03_Core/Configuration.md` - Master configuration reference
4. `DCE/docs/01_Project/API_REFERENCE.md` - Complete API documentation
5. `DCE/docs/16_Integrations/Adapter_System.md` - Adapter implementation guide
6. `DCE/docs/03_Core/Performance.md` - Performance architecture guide
7. `DCE/architecture/ADR-0012-Resource-Lifecycle.md` - Resource lifecycle ADR
8. `DCE/architecture/ADR-0013-FiveM-Compatibility.md` - FiveM compatibility ADR
9. `DCE/docs/19_Development/Documentation_Coverage_Report.md` - This report
10. `DCE/src/dce-world/models/location.lua` - Location data model
11. `DCE/src/dce-world/services/location-manager.lua` - Location Manager service
12. `DCE/src/types/services/location-manager.lua` - Location Manager type declarations
13. `DCE/architecture/ADR-0021-Location-Manager.md` - Location Manager ADR

### Files Updated (4)

1. `README.md` - Fixed documentation path typos
2. `DCE/architecture/Event_Catalog_v1.md` - Added location domain events
3. `DCE/architecture/ADR-0020-Export-Marshalling-Fix.md` - Added migration guide
4. `DCE/architecture/Technical-Debt-Register.md` - Updated for Sprint 001 resolutions

### Files Modified (4)

1. `DCE/src/dce-evidence/init.lua` - Fixed DCE.On cross-resource violation
2. `DCE/src/dce-admin/services/admin.lua` - Fixed task list APIs
3. `DCE/src/dce-admin/client/nui.lua` - Added ESC key handler
4. `DCE/src/dce-admin/html/js/framework.js` - Added keyboard event handling
5. `DCE/src/dce-world/init.lua` - Integrated Location Manager service

## Outstanding Documentation Tasks

### Priority 1 (v1.1)

- [x] Add service documentation for dce-world, dce-ai, dce-events
- [ ] Add inline design rationale comments in implementation files

### Priority 2 (v1.2)

- [ ] Create Investigation service documentation
- [ ] Create MDT adapter documentation
- [ ] Add configuration schema validation documentation

### Priority 3 (v2.0)

- [ ] World Chronicle documentation
- [ ] Cross-server sync documentation
- [ ] Federal/political pressure system documentation

## Verification Checklist

### Event Catalog Compliance

| Event | Status |
|-------|--------|
| evidence:item:created | ✅ Added to catalog |
| dispatch:call:updated | ✅ Added to catalog |
| dispatch:call:resolved | ✅ Added to catalog |
| scenario:created | ✅ Added to catalog |
| scenario:completed | ✅ Added to catalog |
| world:time:changed | ✅ Added to catalog |
| world:weather:changed | ✅ Added to catalog |

### Configuration Documentation

| Config Section | Status |
|----------------|--------|
| Core Logger | ✅ Documented |
| Core Scheduler | ✅ Documented |
| Core Registry | ✅ Documented |
| Core Plugin Manager | ✅ Documented |
| Performance Budgets | ✅ Documented |
| Admin Settings | ✅ Documented |
| World Settings | ✅ Documented |
| Dispatch Integration | ✅ Documented |
| Evidence Integration | ✅ Documented |
| AI Frequencies | ✅ Documented |

### API Documentation

| API Surface | Status |
|-------------|--------|
| DCE Global Functions | ✅ Fully documented |
| Core Services (Logger, EventBus, etc.) | ✅ Fully documented |
| Domain Services | ✅ Fully documented |
| SDK Functions | ✅ Documented |
| Export Functions | ✅ Documented |

### ADR Coverage

| Decision | ADR Status |
|----------|------------|
| Resource Lifecycle | ✅ Created |
| FiveM Compatibility | ✅ Created |
| Service Registry | ✅ ADR-0001 exists |
| Event Bus | ✅ ADR-0010 exists |
| Plugin Architecture | ✅ ADR-0006 exists |
| Performance Framework | ✅ ADR-0015 exists |
| Export Marshalling | ✅ ADR-0020 exists |

## Next Sprint Recommendations

1. **Create service documentation for remaining modules** (world, ai, events)
2. **Add configuration validation** (schema-based)
3. **Create testing guide** for developers
4. **Update inline comments** in core modules