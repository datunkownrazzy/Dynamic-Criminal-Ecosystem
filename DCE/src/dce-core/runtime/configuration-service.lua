-- DCE Configuration Service
-- Coordinates server-authoritative changes; domain targets retain data ownership.
---@diagnostic disable: undefined-global

local ConfigurationService = {}

function ConfigurationService:New(eventBus, logger)
    local service = {}
    local targets = {}

    local function isCallable(value)
        return type(value) == "function"
            or (type(value) == "table" and getmetatable(value) and type(getmetatable(value).__call) == "function")
    end

    local function result(code, message, request, extra)
        local response = {
            code = code,
            message = message,
            target = request and request.target or nil,
            targetId = request and request.targetId or nil,
            runtimeApplied = false,
            persisted = false,
            restartRequired = false,
        }
        for key, value in pairs(extra or {}) do
            response[key] = value
        end
        return response
    end

    function service:RegisterTarget(name, target)
        if type(name) ~= "string" or type(target) ~= "table"
            or not isCallable(target.GetSnapshot)
            or not isCallable(target.GetRevision)
            or not isCallable(target.GetCapabilities)
            or not isCallable(target.ValidateChange)
            or not isCallable(target.ApplyChange) then
            return false, "Invalid configuration target contract"
        end
        if targets[name] then
            return false, "Configuration target already registered"
        end
        targets[name] = target
        return true
    end

    function service:GetCapabilities(name, targetId)
        local target = targets[name]
        if not target then
            return { state = "unavailable", actions = {} }
        end
        return target.GetCapabilities(targetId)
    end

    function service:ListTargets()
        local result = {}
        for name, target in pairs(targets) do
            local capabilities = target.GetCapabilities() or {}
            table.insert(result, {
                target = name,
                state = capabilities.state or "unavailable",
                actions = capabilities.actions or {},
                message = capabilities.message,
                restartRequired = capabilities.restartRequired == true,
            })
        end
        table.sort(result, function(left, right) return left.target < right.target end)
        return result
    end

    function service:Apply(source, request, authorize)
        if type(request) ~= "table" or type(request.target) ~= "string"
            or type(request.operation) ~= "string" or type(request.patch) ~= "table" then
            return result("VALIDATION_ERROR", "Invalid configuration request", request)
        end
        -- Callable contract (FiveM cross-resource FunctionRef safe): the authorize
        -- callback originates in the Control Center resource and crosses the export
        -- boundary into dce-core, where it arrives as a callable FunctionRef TABLE.
        -- Reuse this file's existing isCallable() gate. Add differential diagnostic
        -- to distinguish NOT_CALLABLE vs CALLBACK_FALSE vs CALLBACK_ERROR vs AUTHORIZED
        -- while preserving authorization semantics and the cached-authorized contract.
        local authorizeType = type(authorize)
        local mtAuthorize = getmetatable(authorize)
        local hasMetatable = (mtAuthorize ~= nil)
        local callType = hasMetatable and type(mtAuthorize.__call) or "nil"
        local callable = isCallable(authorize)

        print(("[CC-TRACE] AUTHORIZE_INSPECT source=%s target=%s operation=%s authorizeType=%s hasMetatable=%s callType=%s callable=%s")
            :format(tostring(source), tostring(request.target), tostring(request.operation),
                    authorizeType, tostring(hasMetatable), tostring(callType), tostring(callable)))

        if not callable then
            print(("[CC-TRACE] AUTHORIZE_DENIED reason=NOT_CALLABLE source=%s target=%s operation=%s authorizeType=%s")
                :format(tostring(source), tostring(request.target), tostring(request.operation), authorizeType))
            return result("PERMISSION_DENIED", "Permission denied", request)
        end

        -- Callable: attempt invocation
        local invokeOk, decision = pcall(authorize, source, request.target, request.operation)
        print(("[CC-TRACE] AUTHORIZE_INVOKE ok=%s decision=%s")
            :format(tostring(invokeOk), tostring(decision)))

        if not invokeOk then
            print(("[CC-TRACE] AUTHORIZE_INVOKE_ERROR error=%s source=%s target=%s")
                :format(tostring(decision), tostring(source), tostring(request.target)))
            print(("[CC-TRACE] AUTHORIZE_DENIED reason=CALLBACK_ERROR source=%s target=%s operation=%s")
                :format(tostring(source), tostring(request.target), tostring(request.operation)))
            return result("PERMISSION_DENIED", "Permission denied", request)
        end

        if not decision then
            print(("[CC-TRACE] AUTHORIZE_DENIED reason=CALLBACK_FALSE source=%s target=%s operation=%s decision=%s")
                :format(tostring(source), tostring(request.target), tostring(request.operation), tostring(decision)))
            return result("PERMISSION_DENIED", "Permission denied", request)
        end

        -- Authorized
        print(("[CC-TRACE] AUTHORIZE_OK source=%s target=%s")
            :format(tostring(source), tostring(request.target)))

        local target = targets[request.target]
        if not target then
            return result("UNAVAILABLE", "This configuration target is not available in V1.", request)
        end

        local capabilities = target.GetCapabilities(request.targetId) or {}
        if capabilities.state == "unavailable" then
            return result("UNAVAILABLE", capabilities.message or "Target is unavailable", request)
        end
        if capabilities.state == "unsupported" then
            return result("UNSUPPORTED", capabilities.message or "Target is unsupported", request)
        end
        if capabilities.restartRequired then
            return result("UNSUPPORTED", "Restart required; hot apply is not supported", request, {
                restartRequired = true,
            })
        end
        local operationSupported = false
        for _, action in ipairs(capabilities.actions or {}) do
            if action == request.operation then
                operationSupported = true
                break
            end
        end
        if not operationSupported then
            return result("UNSUPPORTED", "This configuration operation is not supported", request)
        end

        local current = target.GetSnapshot(request.targetId)
        local revision = target.GetRevision(request.targetId)
        if request.operation ~= "create" and not current then
            return result("NOT_FOUND", "Configuration target was not found", request)
        end
        if request.expectedRevision ~= nil and request.expectedRevision ~= revision then
            return result("STALE_REVISION", "Configuration changed; reload before applying", request, {
                revision = revision,
                snapshot = current,
            })
        end

        local valid, normalizedPatch, validationError = target.ValidateChange(
            request.targetId, request.operation, request.patch, current
        )
        if not valid then
            return result("VALIDATION_ERROR", validationError or "Configuration is invalid", request, {
                revision = revision,
                snapshot = current,
            })
        end

        local applied, appliedResult = target.ApplyChange(
            request.targetId, request.operation, normalizedPatch, current
        )
        if not applied then
            local code = type(appliedResult) == "table" and appliedResult.code or "RUNTIME_APPLY_ERROR"
            local message = type(appliedResult) == "table" and appliedResult.message or appliedResult
            return result(code or "RUNTIME_APPLY_ERROR", message or "Runtime apply failed", request, {
                revision = revision,
                snapshot = current,
            })
        end

        local response = result("SUCCESS", "Configuration applied", request, appliedResult)
        if eventBus then
            eventBus:Emit("configuration:changed", {
                eventName = "configuration:changed",
                eventVersion = 1,
                timestamp = GetGameTimer and GetGameTimer() or 0,
                source = "configuration-service",
                payload = response,
            })
        end
        return response
    end

    return service
end

DCE_INTERNAL = DCE_INTERNAL or {}
DCE_INTERNAL.ConfigurationService = ConfigurationService
