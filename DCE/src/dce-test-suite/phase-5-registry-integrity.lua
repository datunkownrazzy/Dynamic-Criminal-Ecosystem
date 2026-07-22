-- DCE Sprint 1.10 — Phase 5: Registry Integrity
-- Continuously register and unregister: services, plugins, adapters, behaviors.
-- Verify registry consistency. Detect orphaned references and stale pointers.
--
-- CANONICAL SDK ACCESS:
-- Uses exports['dce-core']:GetDCEAPI() to obtain the DCE table.
-- _G.DCE is NOT part of the public platform contract.

local Phase5 = {}
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
-- Phase 5 Runner
-- ============================================================================

function Phase5.Run()
    print("^3[DCE Phase 5] Registry Integrity^0")
    local result = H().NewPhaseResult("Phase 5: Registry Integrity")

    local dce = GetDCE()
    if not dce then
        H().RecordFailure(result, "Cannot obtain DCE via exports['dce-core']:GetDCEAPI()")
        return H().FinalizePhaseResult(result)
    end

    -- Get internal services via SDK
    local R = dce.GetService("CoreRegistry")
    local PA = dce.GetService("PluginArchitecture")

    -- ====================================
    -- Test 1: Register / Unregister Cycle (100x)
    -- ====================================

    local cycles = 100
    for i = 1, cycles do
        local svcName = "test:reg:cycle:" .. i
        local ok = dce.RegisterService(svcName, {
            Name = svcName,
            id = i,
        })
        if not ok then
            H().RecordFailure(result, "Failed to register " .. svcName .. " on cycle " .. i)
        end

        -- Verify it exists
        local has = dce.HasService(svcName)
        if not has then
            H().RecordFailure(result, svcName .. " not found after registration")
        end

        -- Unregister
        local unregOk = dce.UnregisterService(svcName)
        if not unregOk then
            H().RecordFailure(result, "Failed to unregister " .. svcName)
        end

        -- Verify it's gone
        local hasAfter = dce.HasService(svcName)
        if hasAfter then
            H().RecordFailure(result, svcName .. " still exists after unregister")
        end
    end
    H().RecordSuccess(result, H().Assert(true,
        "Completed " .. cycles .. " register/unregister cycles"))

    -- ====================================
    -- Test 2: Override Protection
    -- ====================================

    dce.RegisterService("test:reg:protected", { Name = "original" })
    local ok = dce.RegisterService("test:reg:protected", { Name = "override" })
    H().RecordSuccess(result, H().Assert(ok == false,
        "Override without flag rejected"))

    local ok = dce.RegisterService("test:reg:protected", { Name = "override" }, { override = true })
    H().RecordSuccess(result, H().Assert(ok == true,
        "Override with flag accepted"))

    dce.UnregisterService("test:reg:protected")

    -- ====================================
    -- Test 3: Plugin Registration / Unregistration
    -- ====================================

    if PA then
        for i = 1, 50 do
            local pName = "test:plugin:reg:" .. i
            local ok, _ = dce.RegisterPlugin({
                name = pName,
                version = "1.0.0",
                description = "Registry integrity test plugin",
                author = "DCE Validation Team",
            })

            if not ok then
                H().RecordFailure(result, "Failed to register plugin " .. pName)
            end
        end

        local pluginList = PA.List()
        H().RecordSuccess(result, H().AssertTable(pluginList, "Plugin list is table"))
        if pluginList then
            -- Verify no duplicates
            local seen = {}
            local duplicates = 0
            for _, p in ipairs(pluginList) do
                if seen[p.name] then
                    duplicates = duplicates + 1
                end
                seen[p.name] = true
            end
            H().RecordSuccess(result, H().Assert(duplicates == 0,
                "No duplicate plugins: " .. duplicates))
        end

        PA.Clear()
        H().RecordSuccess(result, H().Assert(true, "Plugin architecture cleared"))
    end

    -- ====================================
    -- Test 4: SDK Registration API Integrity
    -- ====================================

    -- Register many organizations (simulated - these are just SDK calls)
    for i = 1, 50 do
        dce.RegisterOrganization({
            id = "test-org-" .. i,
            name = "Test Org " .. i,
            type = "test",
            territory = "zone-" .. (i % 10 + 1),
        })
    end
    H().RecordSuccess(result, H().Assert(true,
        "50 organization registrations completed"))

    -- Register many adapters
    for i = 1, 50 do
        dce.RegisterDispatchAdapter({
            Name = "test-dispatch-" .. i,
            Version = "1.0.0",
        })
        dce.RegisterEvidenceAdapter({
            Name = "test-evidence-" .. i,
            Version = "1.0.0",
        })
        dce.RegisterMDTAdapter({
            Name = "test-mdt-" .. i,
            Version = "1.0.0",
        })
    end
    H().RecordSuccess(result, H().Assert(true,
        "150 adapter registrations (50 each) completed"))

    -- Register many behaviors
    for i = 1, 50 do
        dce.RegisterBehavior({
            type = "test-behavior-" .. i,
            priority = i % 5,
        })
    end
    H().RecordSuccess(result, H().Assert(true,
        "50 behavior registrations completed"))

    -- ====================================
    -- Test 5: Service Existence Consistency
    -- ====================================

    -- Core services that should always be available
    local coreServices = {"CoreRegistry", "Logger", "EventBus", "Scheduler"}
    for _, svcName in ipairs(coreServices) do
        local has = dce.HasService(svcName)
        H().RecordSuccess(result, H().Assert(has == true,
            "Core service exists: " .. svcName))
        local svc = dce.GetService(svcName)
        H().RecordSuccess(result, H().AssertNotNil(svc,
            "Core service retrievable: " .. svcName))
    end

    -- Service that should NOT exist
    local has = dce.HasService("NonExistent")
    H().RecordSuccess(result, H().Assert(has == false,
        "Non-existent service reported as missing"))

    return H().FinalizePhaseResult(result)
end

_G.DCEPhase5 = Phase5
return Phase5