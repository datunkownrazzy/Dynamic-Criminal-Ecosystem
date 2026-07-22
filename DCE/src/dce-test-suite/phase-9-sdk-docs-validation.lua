-- DCE Sprint 1.10 — Phase 9: SDK Documentation Validation
-- Build every mock resource using only the published SDK documentation.
-- If implementation requires reading Core source code, the documentation is incomplete.
-- This phase verifies that the SDK docs in sdk/public-api.md are sufficient.
--
-- CANONICAL SDK ACCESS:
-- Uses exports['dce-core']:GetDCEAPI() to obtain the DCE table.
-- _G.DCE is NOT part of the public platform contract.

local Phase9 = {}
local function H() return _G.DCETestHarness end

-- ============================================================================
-- Canonical SDK Reference
-- ============================================================================

local DCE = nil
local function GetDCE()
    if DCE then return DCE end
    local ok, result = pcall(function()
        return exports['dce-core']:GetDCEAPI()
    end)
    if ok and type(result) == "table" then
        DCE = result
    end
    return DCE
end

-- ============================================================================
-- Phase 9 Runner
-- ============================================================================

function Phase9.Run()
    print("^3[DCE Phase 9] SDK Documentation Validation^0")
    local result = H().NewPhaseResult("Phase 9: SDK Documentation Validation")

    local dce = GetDCE()
    if not dce then
        H().RecordFailure(result, "Cannot obtain DCE via exports['dce-core']:GetDCEAPI()")
        return H().FinalizePhaseResult(result)
    end

    -- ====================================
    -- Test 1: SDK API Surface Completeness
    -- ====================================

    -- These are the APIs documented in sdk/public-api.md
    -- Verify every documented API exists on the DCE table

    local documentedAPIs = {
        -- Service Registry
        {"DCE.GetService", "function"},
        {"DCE.RegisterService", "function"},
        {"DCE.HasService", "function"},
        {"DCE.GetServiceOrThrow", "function"},
        {"DCE.UnregisterService", "function"},

        -- Event Bus
        {"DCE.On", "function"},
        {"DCE.Once", "function"},
        {"DCE.Off", "function"},
        {"DCE.Emit", "function"},

        -- Scheduler
        {"DCE.Schedule", "function"},
        {"DCE.ScheduleNow", "function"},

        -- Plugin
        {"DCE.RegisterPlugin", "function"},

        -- Config
        {"DCE.LoadConfig", "function"},
        {"DCE.ValidateConfig", "function"},

        -- Logger
        {"DCE.Log", "function"},
        {"DCE.GetVersion", "function"},

        -- SDK Registration (Future Reserved)
        {"DCE.RegisterOrganization", "function"},
        {"DCE.RegisterDispatchAdapter", "function"},
        {"DCE.RegisterEvidenceAdapter", "function"},
        {"DCE.RegisterMDTAdapter", "function"},
        {"DCE.RegisterBehavior", "function"},
        {"DCE.RegisterEscalationChain", "function"},

        -- Exports (canonical)
        {"GetDCEAPI via exports['dce-core']", "function"},
    }

    local allExist = true
    local missing = {}
    for _, api in ipairs(documentedAPIs) do
        local name, expectedType = api[1], api[2]
        local value

        if name == "GetDCEAPI via exports['dce-core']" then
            -- Verify the canonical export exists
            local ok, val = pcall(function()
                return exports['dce-core']:GetDCEAPI()
            end)
            value = ok and val
        else
            -- Split by dots: DCE.GetService -> DCE, GetService
            local parts = {}
            for part in name:gmatch("[^.]+") do
                table.insert(parts, part)
            end
            if #parts == 2 and parts[1] == "DCE" then
                value = dce[parts[2]]
            end
        end

        local exists = value ~= nil
        local correctType = expectedType == "any" or type(value) == expectedType

        if not exists then
            allExist = false
            table.insert(missing, name .. " (missing)")
        elseif not correctType then
            allExist = false
            table.insert(missing, name .. " (wrong type: " .. type(value) .. ", expected " .. expectedType .. ")")
        end
    end

    H().RecordSuccess(result, H().Assert(allExist,
        "All documented SDK APIs exist via canonical SDK: " .. (#missing == 0 and "yes" or "missing: " .. table.concat(missing, ", "))))

    -- ====================================
    -- Test 2: SDK API Behavior Matches Documentation
    -- ====================================

    -- DCE.GetService returns table|nil
    local svc = dce.GetService("CoreRegistry")
    H().RecordSuccess(result, H().Assert(svc == nil or type(svc) == "table",
        "DCE.GetService returns table|nil: got " .. type(svc)))

    -- DCE.RegisterService returns boolean
    local regOk = dce.RegisterService("test:docs:validate", { Name = "test" })
    H().RecordSuccess(result, H().Assert(type(regOk) == "boolean",
        "DCE.RegisterService returns boolean: got " .. type(regOk)))
    dce.UnregisterService("test:docs:validate")

    -- DCE.HasService returns boolean
    local has = dce.HasService("CoreRegistry")
    H().RecordSuccess(result, H().Assert(type(has) == "boolean",
        "DCE.HasService returns boolean: got " .. type(has)))

    -- DCE.On returns string|nil
    local id = dce.On("test:docs:on", function() end)
    H().RecordSuccess(result, H().Assert(id == nil or type(id) == "string" or type(id) == "number",
        "DCE.On returns string|number|nil: got " .. type(id)))
    if id then dce.Off("test:docs:on", id) end

    -- DCE.Once returns string|nil
    local onceId = dce.Once("test:docs:once", function() end)
    H().RecordSuccess(result, H().Assert(onceId == nil or type(onceId) == "string" or type(onceId) == "number",
        "DCE.Once returns string|number|nil: got " .. type(onceId)))
    if onceId then dce.Off("test:docs:once", onceId) end

    -- DCE.Schedule returns boolean
    local schedOk = dce.Schedule("test:docs:sched", 1000, function() end)
    H().RecordSuccess(result, H().Assert(type(schedOk) == "boolean",
        "DCE.Schedule returns boolean: got " .. type(schedOk)))
    local scheduler = dce.GetService("Scheduler")
    if scheduler and scheduler.Unschedule then scheduler.Unschedule("test:docs:sched") end

    -- DCE.GetVersion returns string
    local ver = dce.GetVersion()
    H().RecordSuccess(result, H().Assert(type(ver) == "string",
        "DCE.GetVersion returns string: got " .. type(ver)))

    -- ====================================
    -- Test 3: Mock Resource Construction (Documentation-Only)
    -- ====================================

    -- Build mock resources using ONLY the documented SDK APIs
    -- No Core internals accessed

    -- Mock Plugin (uses DCE.RegisterPlugin)
    local mockPlugin = {
        name = "dce-docs-test-plugin",
        version = "1.0.0",
        description = "Built from SDK docs only",
        author = "DCE Validation Team",
        sdkVersion = "1.0.0",
        capabilities = {"docs-validation"},
    }
    local pluginOk = dce.RegisterPlugin(mockPlugin)
    H().RecordSuccess(result, H().Assert(pluginOk == true or pluginOk == nil,
        "Mock plugin built from SDK docs: " .. tostring(pluginOk)))

    -- Mock Organization (uses DCE.RegisterOrganization)
    local orgOk = dce.RegisterOrganization({
        id = "dce-docs-test-org",
        name = "Docs Test Org",
        type = "validation",
    })
    H().RecordSuccess(result, H().Assert(orgOk == true,
        "Mock organization built from SDK docs"))

    -- Mock Dispatch Adapter (uses DCE.RegisterDispatchAdapter)
    local dispatchOk = dce.RegisterDispatchAdapter({
        Name = "dce-docs-test-dispatch",
        Version = "1.0.0",
    })
    H().RecordSuccess(result, H().Assert(dispatchOk == true,
        "Mock dispatch adapter built from SDK docs"))

    -- Mock Evidence Adapter (uses DCE.RegisterEvidenceAdapter)
    local evidenceOk = dce.RegisterEvidenceAdapter({
        Name = "dce-docs-test-evidence",
        Version = "1.0.0",
    })
    H().RecordSuccess(result, H().Assert(evidenceOk == true,
        "Mock evidence adapter built from SDK docs"))

    -- Mock MDT Adapter (uses DCE.RegisterMDTAdapter)
    local mdtOk = dce.RegisterMDTAdapter({
        Name = "dce-docs-test-mdt",
        Version = "1.0.0",
    })
    H().RecordSuccess(result, H().Assert(mdtOk == true,
        "Mock MDT adapter built from SDK docs"))

    -- Mock Behavior (uses DCE.RegisterBehavior)
    local behaviorOk = dce.RegisterBehavior({
        type = "docs-test-behavior",
        priority = 1,
    })
    H().RecordSuccess(result, H().Assert(behaviorOk == true,
        "Mock behavior built from SDK docs"))

    -- Mock Escalation Chain (uses DCE.RegisterEscalationChain)
    local escOk = dce.RegisterEscalationChain({
        id = "dce-docs-test-escalation",
        steps = {"step1", "step2"},
    })
    H().RecordSuccess(result, H().Assert(escOk == true,
        "Mock escalation chain built from SDK docs"))

    -- ====================================
    -- Test 4: Event Subscription via SDK Only
    -- ====================================

    local eventReceived = false
    local subId = dce.On("test:docs:event", function()
        eventReceived = true
    end)
    H().RecordSuccess(result, H().AssertNotNil(subId,
        "Event subscription via SDK docs"))

    dce.Emit("test:docs:event", {
        eventVersion = 1,
        timestamp = os.time(),
        source = "dce-test-suite",
        payload = { test = true },
    })
    H().RecordSuccess(result, H().Assert(eventReceived,
        "Event emission via SDK docs"))

    if subId then dce.Off("test:docs:event", subId) end

    -- ====================================
    -- Test 5: Service Registration via SDK Only
    -- ====================================

    local testSvc = {
        Name = "dce-docs-test-service",
        GetData = function() return "test-data" end,
    }
    local svcOk = dce.RegisterService("DCEPhase9TestService", testSvc)
    H().RecordSuccess(result, H().Assert(svcOk == true,
        "Service registration via SDK docs"))

    local retrieved = dce.GetService("DCEPhase9TestService")
    H().RecordSuccess(result, H().AssertNotNil(retrieved,
        "Service retrieval via SDK docs"))
    if retrieved then
        H().RecordSuccess(result, H().Assert(retrieved.Name == "dce-docs-test-service",
            "Service data accessible via SDK docs"))
    end

    dce.UnregisterService("DCEPhase9TestService")

    -- ====================================
    -- Test 6: Export Usage via SDK Only
    -- ====================================

    -- Verify canonical SDK entry point works
    local canonicalDCE = GetDCE()
    H().RecordSuccess(result, H().AssertNotNil(canonicalDCE,
        "exports['dce-core']:GetDCEAPI() returns DCE table"))
    if canonicalDCE then
        H().RecordSuccess(result, H().Assert(canonicalDCE == dce,
            "Canonical DCE is same as API reference"))
    end

    -- ====================================
    -- Test 7: Frozen APIs (Historical) Verification
    -- ====================================

    -- These APIs are documented as FROZEN/HISTORICAL and should NOT exist on DCE
    local frozenAPIs = {
        "GetRegistry",
        "GetLogger",
        "Cancel",
        "ListServices",
        "ListEvents",
        "ListTasks",
    }

    local frozenFound = 0
    for _, name in ipairs(frozenAPIs) do
        if dce[name] ~= nil then
            frozenFound = frozenFound + 1
        end
    end
    H().RecordSuccess(result, H().Assert(frozenFound == 0,
        "No frozen APIs implemented on DCE: " .. frozenFound .. " found"))

    -- ====================================
    -- Test 8: CoreRegistry API Surface
    -- ====================================

    local coreReg = dce.GetService("CoreRegistry")
    if coreReg then
        local documentedRegistryAPIs = {
            "ListServices",
            "ListPlugins",
            "ListTasks",
            "ListEvents",
            "GetDCEVersion",
        }
        local allRegAPIs = true
        for _, apiName in ipairs(documentedRegistryAPIs) do
            if type(coreReg[apiName]) ~= "function" then
                allRegAPIs = false
            end
        end
        H().RecordSuccess(result, H().Assert(allRegAPIs,
            "CoreRegistry has all documented APIs"))
    end

    return H().FinalizePhaseResult(result)
end

_G.DCEPhase9 = Phase9
return Phase9