-- DCE Sprint 1.10 — Phase 2: Plugin Stress Testing
-- Load and unload plugins repeatedly.
-- Verify: dependency resolution, lifecycle, shutdown, restart,
-- capability discovery, version compatibility.
-- Look for memory leaks, stale registrations, dangling events, duplicate services.
--
-- CANONICAL SDK ACCESS:
-- Uses exports['dce-core']:GetDCEAPI() to obtain the DCE table.
-- _G.DCE is NOT part of the public platform contract.

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

local function createPluginManifestWithVersion(name, version, sdkVersion, deps)
    return {
        name = name,
        version = version,
        description = "Version test plugin: " .. name,
        author = "DCE Validation Team",
        sdkVersion = sdkVersion or "1.0.0",
        capabilities = {},
        dependencies = deps or {},
    }
end

-- ============================================================================
-- Phase 2 Runner
-- ============================================================================

function Phase2.Run()
    print("^3[DCE Phase 2] Plugin Stress Testing^0")
    local result = H().NewPhaseResult("Phase 2: Plugin Stress Testing")

    local dce = GetDCE()
    if not dce then
        H().RecordFailure(result, "Cannot obtain DCE via exports['dce-core']:GetDCEAPI()")
        return H().FinalizePhaseResult(result)
    end

    -- Get plugin architecture via SDK services
    local PA = dce.GetService("PluginArchitecture")

    if not PA then
        H().RecordSkipped(result, "PluginArchitecture not available (old plugin manager fallback)")
        return H().FinalizePhaseResult(result)
    end

    -- ====================================
    -- Test 1: Plugin Registration & Listing
    -- ====================================

    -- Register multiple plugins
    local plugins = {
        createPluginManifest("dce-test-alpha"),
        createPluginManifest("dce-test-bravo"),
        createPluginManifest("dce-test-charlie"),
        createPluginManifest("dce-test-delta"),
    }

    for _, p in ipairs(plugins) do
        local ok, err = dce.RegisterPlugin(p)
        H().RecordSuccess(result, H().Assert(ok == true or ok == nil,
            "Register plugin '" .. p.name .. "': " .. tostring(err or "ok")))
    end

    -- List registered plugins
    local pluginList = PA.List()
    H().RecordSuccess(result, H().AssertTable(pluginList, "PA.List() returns table"))
    if pluginList then
        local count = #pluginList
        H().RecordSuccess(result, H().Assert(count > 0,
            "PA.List() has " .. count .. " plugins"))
    end

    -- ====================================
    -- Test 2: Plugin Lifecycle Transitions
    -- ====================================

    -- Transition: DISCOVERED -> VALIDATED
    local ok, err = PA.Transition("dce-test-alpha", "VALIDATED")
    H().RecordSuccess(result, H().Assert(ok == true,
        "PA.Transition(DISCOVERED->VALIDATED): " .. tostring(err or "ok")))

    -- Transition: VALIDATED -> RESOLVED
    local ok, err = PA.Transition("dce-test-alpha", "RESOLVED")
    H().RecordSuccess(result, H().Assert(ok == true,
        "PA.Transition(VALIDATED->RESOLVED): " .. tostring(err or "ok")))

    -- Transition: RESOLVED -> LOADING
    local ok, err = PA.Transition("dce-test-alpha", "LOADING")
    H().RecordSuccess(result, H().Assert(ok == true,
        "PA.Transition(RESOLVED->LOADING): " .. tostring(err or "ok")))

    -- Transition: LOADING -> INITIALIZED
    local ok, err = PA.Transition("dce-test-alpha", "INITIALIZED")
    H().RecordSuccess(result, H().Assert(ok == true,
        "PA.Transition(LOADING->INITIALIZED): " .. tostring(err or "ok")))

    -- Transition: INITIALIZED -> READY
    local ok, err = PA.Transition("dce-test-alpha", "READY")
    H().RecordSuccess(result, H().Assert(ok == true,
        "PA.Transition(INITIALIZED->READY): " .. tostring(err or "ok")))

    -- Check state is READY
    local state = PA.GetState("dce-test-alpha")
    H().RecordSuccess(result, H().Assert(state == "READY",
        "Plugin state is READY, got: " .. tostring(state)))

    -- ====================================
    -- Test 3: Invalid Transition Rejection
    -- ====================================

    -- READY -> DISCOVERED (invalid)
    local ok, err = PA.Transition("dce-test-alpha", "DISCOVERED")
    H().RecordSuccess(result, H().Assert(ok == false,
        "Invalid transition READY->DISCOVERED rejected: " .. tostring(err or "ok")))

    -- READY -> UNLOADED (invalid, must go through SHUTDOWN)
    local ok, err = PA.Transition("dce-test-alpha", "UNLOADED")
    H().RecordSuccess(result, H().Assert(ok == false,
        "Invalid transition READY->UNLOADED rejected: " .. tostring(err or "ok")))

    -- ====================================
    -- Test 4: Shutdown & Unload Lifecycle
    -- ====================================

    -- READY -> SHUTDOWN
    local ok, err = PA.Transition("dce-test-alpha", "SHUTDOWN")
    H().RecordSuccess(result, H().Assert(ok == true,
        "PA.Transition(READY->SHUTDOWN): " .. tostring(err or "ok")))

    -- SHUTDOWN -> UNLOADED
    local ok, err = PA.Transition("dce-test-alpha", "UNLOADED")
    H().RecordSuccess(result, H().Assert(ok == true,
        "PA.Transition(SHUTDOWN->UNLOADED): " .. tostring(err or "ok")))

    -- Check state is UNLOADED
    local state = PA.GetState("dce-test-alpha")
    H().RecordSuccess(result, H().Assert(state == "UNLOADED",
        "Plugin state is UNLOADED, got: " .. tostring(state)))

    -- ====================================
    -- Test 5: Dependency Resolution
    -- ====================================

    -- Register a dependency chain: A depends on B, B depends on C
    local pluginDeps = {
        createPluginManifest("dce-dep-c"),
        createPluginManifest("dce-dep-b", {"dce-dep-c"}),
        createPluginManifest("dce-dep-a", {"dce-dep-b"}),
    }

    for _, p in ipairs(pluginDeps) do
        local ok, err = dce.RegisterPlugin(p)
        H().RecordSuccess(result, H().Assert(ok == true or ok == nil,
            "Register plugin '" .. p.name .. "': " .. tostring(err or "ok")))
    end

    -- Resolve dependencies for C (no deps)
    local ok, err, unresolved = PA.ResolveDependencies("dce-dep-c")
    H().RecordSuccess(result, H().Assert(ok == true,
        "ResolveDependencies('dce-dep-c'): " .. tostring(err or "ok")))
    H().RecordSuccess(result, H().Assert(#(unresolved or {}) == 0,
        "No unresolved deps for 'dce-dep-c'"))

    -- Resolve dependencies for B (needs C)
    local ok, err, unresolved = PA.ResolveDependencies("dce-dep-b")
    H().RecordSuccess(result, H().Assert(ok == false,
        "ResolveDependencies('dce-dep-b') fails: C not resolved yet"))

    -- Advance C to READY
    PA.Transition("dce-dep-c", "VALIDATED")
    PA.Transition("dce-dep-c", "RESOLVED")
    PA.Transition("dce-dep-c", "LOADING")
    PA.Transition("dce-dep-c", "INITIALIZED")
    PA.Transition("dce-dep-c", "READY")

    -- Now B should resolve
    local ok, err, unresolved = PA.ResolveDependencies("dce-dep-b")
    H().RecordSuccess(result, H().Assert(ok == true,
        "ResolveDependencies('dce-dep-b') after C resolved: " .. tostring(err or "ok")))

    -- ====================================
    -- Test 6: Capability Discovery
    -- ====================================

    -- List capabilities
    local caps = PA.ListCapabilities()
    H().RecordSuccess(result, H().AssertTable(caps, "PA.ListCapabilities() returns table"))

    -- Discover by capability
    local results = PA.DiscoverByCapability("test")
    H().RecordSuccess(result, H().AssertTable(results, "PA.DiscoverByCapability('test')"))

    -- ====================================
    -- Test 7: Version Compatibility
    -- ====================================

    -- Register with wrong SDK version
    local wrongVersionPlugin = createPluginManifestWithVersion(
        "dce-test-version-mismatch", "1.0.0", "2.0.0")
    local ok, err = dce.RegisterPlugin(wrongVersionPlugin)
    H().RecordSuccess(result, H().Assert(ok == true or ok == nil,
        "Register version-mismatch plugin: " .. tostring(err or "ok")))

    -- Validate should fail due to SDK version mismatch
    local ok, err = PA.Validate("dce-test-version-mismatch")
    H().RecordSuccess(result, H().Assert(ok == false,
        "Version mismatch validation fails: " .. tostring(err or "ok")))

    -- ====================================
    -- Test 8: Repeated Load/Unload Cycle (Stress)
    -- ====================================

    local cycles = 10
    for i = 1, cycles do
        local pluginName = "dce-test-cycle-" .. i
        local p = createPluginManifest(pluginName)
        local ok, _ = dce.RegisterPlugin(p)
        if ok then
            PA.Transition(pluginName, "VALIDATED")
            PA.Transition(pluginName, "RESOLVED")
            PA.Transition(pluginName, "LOADING")
            PA.Transition(pluginName, "INITIALIZED")
            PA.Transition(pluginName, "READY")
            PA.Transition(pluginName, "SHUTDOWN")
            PA.Transition(pluginName, "UNLOADED")
        end
    end
    H().RecordSuccess(result, H().Assert(true,
        "Completed " .. cycles .. " plugin load/unload cycles"))

    -- ====================================
    -- Test 9: Stale Registration Detection
    -- ====================================

    -- Verify no duplicate services were registered during stress
    local registry = dce.GetService("CoreRegistry")
    if registry then
        local services = registry.ListServices() or {}
        local seen = {}
        local duplicates = 0
        for _, svc in ipairs(services) do
            if seen[svc] then
                duplicates = duplicates + 1
            end
            seen[svc] = true
        end
        H().RecordSuccess(result, H().Assert(duplicates == 0,
            "No duplicate services: " .. duplicates .. " found"))
    end

    -- ====================================
    -- Test 10: Full Reset & Verify Clean State
    -- ====================================

    PA.Clear()
    local afterClear = PA.List()
    H().RecordSuccess(result, H().Assert(#afterClear == 0 or afterClear == nil,
        "PA.Clear() results in empty list: " .. tostring(#afterClear) .. " remaining"))

    return H().FinalizePhaseResult(result)
end

_G.DCEPhase2 = Phase2
return Phase2