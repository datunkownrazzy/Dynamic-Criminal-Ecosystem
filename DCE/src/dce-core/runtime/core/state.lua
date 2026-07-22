-- DCE Runtime State
-- Centralized runtime state object.
-- Every diagnostic subsystem consumes the same shared state.
-- No module may own or duplicate runtime state.

local RuntimeState = {
    -- Core identity
    id = nil, -- set on creation via tostring()
    initialized = false,
    creationTime = nil,

    -- Services cache
    services = nil, -- Registered services (set by init)

    -- Exports cache
    exports = nil, -- Registered exports (set by init)

    -- Resources cache
    resources = nil, -- Resource states (set by init)

    -- Events cache
    events = nil, -- Event registrations (set by init)

    -- Boot Timeline
    bootTimeline = {
        start = nil,
        stages = {},
        stageOrder = {},
        initialized = false,
    },

    -- Diagnostic Logger entries
    diagnostics = {
        entries = {},
        warnings = {},
        errors = {},
        assertionFailures = {},
        sections = {},
        activeSection = nil,
        sectionDepth = 0,
        initialized = false,
    },

    -- Service Validator
    serviceValidator = {
        results = {
            services = {},
            exports = {},
            api = {},
            dependencies = {},
            events = {},
        },
        initialized = false,
    },

    -- CC Diagnostics
    ccDiagnostics = {
        transitions = {},
        state = {
            currentStage = nil,
            started = false,
            completed = false,
            failed = false,
            failure = nil,
            startTime = nil,
        },
        initialized = false,
    },

    -- Report Generator
    report = {
        generated = false,
        lastReport = nil,
        initialized = false,
    },

    -- Commands
    commands = {
        registered = false,
        initialized = false,
    },

    -- Module Loader tracking
    moduleLoader = {
        moduleCount = 0,
        passed = 0,
        failed = 0,
        modules = {},
        totalTimeMs = 0,
    },

    -- Contract Validator (Sprint 1.6B)
    contractValidator = {
        results = {
            exportInventory = {},
            exportResolution = {},
            apiInventory = {},
            consumerVerification = {},
            apiContract = {},
            runtimeConsistency = {},
            crossResource = {},
            apiDrift = {},
            exportReport = {},
            apiReport = {},
        },
        initialized = false,
    },

    -- Contract Verifier (Sprint 1.7)
    contractVerifier = {
        results = {
            phase1_apiContract = {},
            phase2_provenanceAudit = {},
            phase3_exportContract = {},
            phase4_consumerVerification = {},
            phase5_serviceContract = {},
            phase6_eventContract = {},
            phase7_interfaceVerification = {},
            phase8_classVerification = {},
            phase9_dependencyContract = {},
            phase10_runtimeContract = {},
            phase11_architecturalDrift = {},
            phase12_runtimeReport = {},
        },
        initialized = false,
    },

    -- Warnings/Errors accumulator
    warnings = {},
    errors = {},
}

-- Public API

function RuntimeState.Init()
    RuntimeState.creationTime = GetGameTimer and GetGameTimer() or (os.clock and os.clock() * 1000 or os.time() * 1000)
    RuntimeState.initialized = true
    RuntimeState.id = tostring({}) -- unique identity via table reference
    return RuntimeState
end

function RuntimeState.IsReady()
    return RuntimeState.initialized
end

function RuntimeState.GetId()
    return RuntimeState.id
end

function RuntimeState.GetElapsed()
    local now = GetGameTimer and GetGameTimer() or (os.clock and os.clock() * 1000 or os.time() * 1000)
    if RuntimeState.creationTime then
        return now - RuntimeState.creationTime
    end
    return 0
end

--- Reset all state (for restart scenarios)
function RuntimeState.Reset()
    RuntimeState.bootTimeline = {
        start = nil,
        stages = {},
        stageOrder = {},
        initialized = false,
    }
    RuntimeState.diagnostics = {
        entries = {},
        warnings = {},
        errors = {},
        assertionFailures = {},
        sections = {},
        activeSection = nil,
        sectionDepth = 0,
        initialized = false,
    }
    RuntimeState.serviceValidator = {
        results = {
            services = {},
            exports = {},
            api = {},
            dependencies = {},
            events = {},
        },
        initialized = false,
    }
    RuntimeState.ccDiagnostics = {
        transitions = {},
        state = {
            currentStage = nil,
            started = false,
            completed = false,
            failed = false,
            failure = nil,
            startTime = nil,
        },
        initialized = false,
    }
    RuntimeState.report = {
        generated = false,
        lastReport = nil,
        initialized = false,
    }
    RuntimeState.commands = {
        registered = false,
        initialized = false,
    }
    RuntimeState.moduleLoader = {
        moduleCount = 0,
        passed = 0,
        failed = 0,
        modules = {},
        totalTimeMs = 0,
    }
    RuntimeState.warnings = {}
    RuntimeState.errors = {}
    RuntimeState.services = nil
    RuntimeState.exports = nil
    RuntimeState.resources = nil
    RuntimeState.events = nil
    RuntimeState.creationTime = GetGameTimer and GetGameTimer() or (os.clock and os.clock() * 1000 or os.time() * 1000)
end

_G.DCERuntimeState = RuntimeState
return RuntimeState