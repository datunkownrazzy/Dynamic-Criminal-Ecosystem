local Phase12 = {}
local function H() return _G.DCETestHarness end

local DCE = nil

local function GetDCE()
    if DCE then return DCE end
    local ok, result = pcall(function()
        return exports['dce-core']:GetDCEAPI()
    end)
    if ok and type(result) == "table" then DCE = result end
    return DCE
end

function Phase12.Run()
    print("^3[DCE Phase 12] Hot Configuration^0")
    local result = H().NewPhaseResult("Phase 12: Hot Configuration")
    local dce = GetDCE()
    if not dce then
        H().RecordFailure(result, "Cannot obtain DCE via exports['dce-core']:GetDCEAPI()")
        return H().FinalizePhaseResult(result)
    end

    local configurationService = dce:GetService("ConfigurationService")
    H().RecordSuccess(result, H().AssertNotNil(configurationService, "ConfigurationService is registered"))
    if not configurationService then return H().FinalizePhaseResult(result) end

    local snapshot = { value = 1 }
    local revision = 1
    local registered = configurationService:RegisterTarget("test.configuration.target", {
        GetSnapshot = function() return { value = snapshot.value } end,
        GetRevision = function() return revision end,
        GetCapabilities = function() return { state = "available", actions = { "update" } } end,
        ValidateChange = function(_, operation, patch)
            if operation ~= "update" or type(patch.value) ~= "number" or patch.value < 0 or patch.value > 10 then
                return false, nil, "value must be a number from 0 to 10"
            end
            return true, { value = patch.value }
        end,
        ApplyChange = function(_, _, patch)
            snapshot.value = patch.value
            revision = revision + 1
            return true, { revision = revision, snapshot = { value = snapshot.value }, runtimeApplied = true, persisted = false }
        end,
    })
    H().RecordSuccess(result, H().Assert(registered == true, "Configuration target registration"))
    if not registered then return H().FinalizePhaseResult(result) end

    local eventPayload = nil
    local listenerId = dce:On("configuration:changed", function(payload) eventPayload = payload end)
    local function apply(request, allowed)
        return configurationService:Apply(1, request, function() return allowed end)
    end

    local denied = apply({ target = "test.configuration.target", targetId = "one", operation = "update", patch = { value = 2 } }, false)
    H().RecordSuccess(result, H().Assert(denied.code == "PERMISSION_DENIED", "Unauthorized change is denied"))

    local unsupported = apply({ target = "test.configuration.target", targetId = "one", operation = "delete", patch = {} }, true)
    H().RecordSuccess(result, H().Assert(unsupported.code == "UNSUPPORTED", "Undeclared operation is rejected"))

    local invalid = apply({ target = "test.configuration.target", targetId = "one", operation = "update", patch = { value = 11 } }, true)
    H().RecordSuccess(result, H().Assert(invalid.code == "VALIDATION_ERROR", "Invalid change is rejected"))

    local stale = apply({ target = "test.configuration.target", targetId = "one", operation = "update", expectedRevision = 0, patch = { value = 2 } }, true)
    H().RecordSuccess(result, H().Assert(stale.code == "STALE_REVISION", "Stale revision is rejected"))

    local applied = apply({ target = "test.configuration.target", targetId = "one", operation = "update", expectedRevision = 1, patch = { value = 2 } }, true)
    H().RecordSuccess(result, H().Assert(applied.code == "SUCCESS" and applied.runtimeApplied, "Valid change applies"))
    H().RecordSuccess(result, H().Assert(snapshot.value == 2 and applied.revision == 2, "Applied change returns authoritative revision"))
    H().RecordSuccess(result, H().Assert(eventPayload and eventPayload.payload and eventPayload.payload.target == "test.configuration.target", "Configuration event uses the standard envelope"))
    dce:Off("configuration:changed", listenerId)

    return H().FinalizePhaseResult(result)
end

_G.DCEPhase12 = Phase12
return Phase12