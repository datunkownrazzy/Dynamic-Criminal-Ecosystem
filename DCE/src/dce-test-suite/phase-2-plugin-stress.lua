-- DCE Sprint 1.10 — Phase 2: Plugin Lifecycle Validation
-- Verify: registration, listing, duplication rejection, cleanup.
--
-- CANONICAL SDK ACCESS:
-- Uses exports['dce-core']:GetDCEAPI() to obtain the DCE table.
-- _G.DCE is NOT part of the public platform contract.
--
-- Sprint 1.11.11: Reconciled to canonical PluginManager API.
-- The "PluginArchitecture" service does NOT exist. Canonical service name:
-- "PluginManager" with methods Register/Unregister/Get/List/Count/Clear.
-- The obsolete Transition/ResolveDependencies/Validate/ListCapabilities/
-- DiscoverByCapability lifecycle-state methods do NOT exist in the runtime.

local Phase2 = {}
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
-- Test Plugin Manifests
-- ============================================================================

local function createPluginManifest(name, deps, capabilities, sdkVersion)
    return {
        name = name,
        version = "1.0.0",
        description = "Stress test plugin: " .. name,
        author = "DCE Validation Team",
        sdkVersion = sdkVersion or "1.0.0",
        capabilities = capabilities or {},
        dependencies = deps or {},
    }
end

-- ============================================================================
-- Phase 2 Runner
-- ============================================================================

function Phase2.Run()
    print("^3[DCE Phase 2] Plugin Lifecycle Validation^0")
    local result = H().NewPhaseResult("Phase 2: Plugin Lifecycle Validation")

    local dce = GetDCE()
    if not dce then
        H().RecordFailure(result, "Cannot obtain DCE via exports['dce-core']:GetDCEAPI()")
        return H().FinalizePhaseResult(result)
    end

    -- Get PluginManager via SDK services (canonical service name)
    local PA = dce:GetService("PluginManager")

    if not PA then
        H().RecordSkipped(result, "PluginManager not available via DCE.GetService")
        return H().FinalizePhaseResult(result)
    end

    -- ====================================
    -- Test 1: Plugin Registration & Listing
    -- ====================================

    -- Register multiple plugins via canonical SDK
    local plugins = {
        createPluginManifest("dce-test-alpha"),
        createPluginManifest("dce-test-bravo"),
        createPluginManifest("dce-test-charlie"),
        createPluginManifest("dce-test-delta"),
    }

    for _, p in ipairs(plugins) do
        local ok, err = dce:RegisterPlugin(p)
        H().RecordSuccess(result, H().Assert(ok == true or ok == nil,
            "Register plugin '" .. p.name .. "': " .. tostring(err or "ok")))
    end

    -- List registered plugins via canonical PluginManager
    local pluginList = PA:List()
    H().RecordSuccess(result, H().Assert(pluginList ~= nil, "PA:List() returns table"))
    if pluginList then
        local count = #pluginList
        H().RecordSuccess(result, H().Assert(count > 0,
            "PA:List() has " .. count .. " plugins"))
    end

    -- ====================================
    -- Test 2: Duplicate Rejection & Get
    -- ====================================

    -- Duplicate registration must be rejected
    local dupOk = dce:RegisterPlugin(plugins[1])
    H().RecordSuccess(result, H().Assert(dupOk == false,
        "Duplicate plugin registration rejected"))

    -- Get returns the registered manifest
    local alpha = PA:Get("dce-test-alpha")
    H().RecordSuccess(result, H().Assert(alpha ~= nil, "PA:Get('dce-test-alpha')"))
    if alpha then
        H().RecordSuccess(result, H().Assert(alpha.version == "1.0.0",
            "Plugin manifest version preserved"))
    end

    -- Count reflects registration
    local count = PA:Count()
    H().RecordSuccess(result, H().Assert(count >= 4, "PA:Count() >= 4: " .. tostring(count)))

    -- ====================================
    -- Test 3: Unregister
    -- ====================================

    local unregOk = PA:Unregister("dce-test-delta")
    H().RecordSuccess(result, H().Assert(unregOk == true, "PA:Unregister('dce-test-delta')"))
    local afterUnreg = PA:Get("dce-test-delta")
    H().RecordSuccess(result, H().Assert(afterUnreg == nil,
        "Unregistered plugin no longer present"))

    -- ====================================
    -- Test 4: Repeated Register/Clear Cycle (Stress)
    -- ====================================

    local cycles = 10
    for i = 1, cycles do
        local pluginName = "dce-test-cycle-" .. i
        local p = createPluginManifest(pluginName)
        local ok, _ = dce:RegisterPlugin(p)
        H().RecordSuccess(result, H().Assert(ok == true,
            "Register plugin '" .. pluginName .. "'"))
    end

    PA:Clear()
    local afterClear = PA:List()
    H().RecordSuccess(result, H().Assert(#(afterClear or {}) == 0,
        "PA:Clear() results in empty list"))

    -- ====================================
    -- Test 5: Full Reset & Verify Clean State
    -- ====================================

    -- Re-register and verify
    local reOk = dce:RegisterPlugin(createPluginManifest("dce-test-reset"))
    H().RecordSuccess(result, H().Assert(reOk == true,
        "Post-clear registration works"))

    local state = PA:Get("dce-test-reset")
    H().RecordSuccess(result, H().Assert(state ~= nil,
        "Post-clear Get works"))

    PA:Clear()

    return H().FinalizePhaseResult(result)
end

_G.DCEPhase2 = Phase2
return Phase2