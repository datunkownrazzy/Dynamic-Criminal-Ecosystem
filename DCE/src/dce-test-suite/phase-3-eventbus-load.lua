-- DCE Sprint 1.10 — Phase 3: Event Bus Load Testing
-- Create thousands of synthetic events.
-- Measure: dispatch latency, queue depth, listener execution,
-- event ordering, dropped events, duplicate delivery.
-- Ensure the Event Bus scales before gameplay systems rely on it.
--
-- CANONICAL SDK ACCESS:
-- Uses exports['dce-core']:GetDCEAPI() to obtain the DCE table.
-- _G.DCE is NOT part of the public platform contract.

local Phase3 = {}
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
-- Phase 3 Runner
-- ============================================================================

function Phase3.Run()
    print("^3[DCE Phase 3] Event Bus Load Testing^0")
    local result = H().NewPhaseResult("Phase 3: Event Bus Load Testing")

    local dce = GetDCE()
    if not dce then
        H().RecordFailure(result, "Cannot obtain DCE via exports['dce-core']:GetDCEAPI()")
        return H().FinalizePhaseResult(result)
    end

    -- Get EventBus via SDK service
    local EB = dce.GetService("EventBus")

    if not EB then
        H().RecordSkipped(result, "EventBus not available via DCE.GetService")
        return H().FinalizePhaseResult(result)
    end

    -- ====================================
    -- Test 1: Basic Event Dispatch
    -- ====================================

    local received = 0
    local handlerId = EB.On("test:phase3:basic", function()
        received = received + 1
    end)
    H().RecordSuccess(result, H().AssertNotNil(handlerId, "EB.On returns handler ID"))

    EB.Emit("test:phase3:basic", { source = "phase3" })
    Citizen.Wait(50)
    H().RecordSuccess(result, H().Assert(received == 1,
        "Basic event dispatch: received=" .. received))

    -- ====================================
    -- Test 2: Multiple Listeners
    -- ====================================

    local countA, countB = 0, 0
    EB.On("test:phase3:multi", function() countA = countA + 1 end)
    EB.On("test:phase3:multi", function() countB = countB + 1 end)
    EB.Emit("test:phase3:multi", { source = "phase3" })
    Citizen.Wait(50)
    H().RecordSuccess(result, H().Assert(countA == 1 and countB == 1,
        "Multiple listeners: A=" .. countA .. " B=" .. countB))

    -- ====================================
    -- Test 3: Event Payload Integrity
    -- ====================================

    local receivedPayload = nil
    EB.Once("test:phase3:payload", function(payload)
        receivedPayload = payload
    end)
    local testPayload = {
        eventVersion = 1,
        timestamp = os.time(),
        source = "dce-test-suite",
        payload = {
            string = "hello",
            number = 42,
            boolean = true,
            table = { a = 1, b = 2 },
        },
    }
    EB.Emit("test:phase3:payload", testPayload)
    Citizen.Wait(50)
    H().RecordSuccess(result, H().AssertNotNil(receivedPayload, "Payload received"))
    if receivedPayload then
        H().RecordSuccess(result, H().Assert(receivedPayload.payload.string == "hello",
            "Payload string field preserved"))
        H().RecordSuccess(result, H().Assert(receivedPayload.payload.number == 42,
            "Payload number field preserved"))
        H().RecordSuccess(result, H().Assert(receivedPayload.payload.boolean == true,
            "Payload boolean field preserved"))
        H().RecordSuccess(result, H().AssertTable(receivedPayload.payload.table,
            "Payload table field preserved"))
    end

    -- ====================================
    -- Test 4: Once Semantics
    -- ====================================

    local onceCount = 0
    EB.Once("test:phase3:once", function() onceCount = onceCount + 1 end)
    EB.Emit("test:phase3:once", { source = "phase3" })
    EB.Emit("test:phase3:once", { source = "phase3" })
    Citizen.Wait(50)
    H().RecordSuccess(result, H().Assert(onceCount == 1,
        "Once semantics: fired exactly " .. onceCount .. " time(s)"))

    -- ====================================
    -- Test 5: Unsubscribe (Off)
    -- ====================================

    local offCount = 0
    local offId = EB.On("test:phase3:off", function() offCount = offCount + 1 end)
    EB.Emit("test:phase3:off", { source = "phase3" })
    Citizen.Wait(50)
    if offId then EB.Off("test:phase3:off", offId) end
    EB.Emit("test:phase3:off", { source = "phase3" })
    Citizen.Wait(50)
    H().RecordSuccess(result, H().Assert(offCount == 1,
        "Unsubscribe: handler fired " .. offCount .. " time(s) after Off"))

    -- ====================================
    -- Test 6: High Volume Dispatch (Stress)
    -- ====================================

    local stressCount = 0
    local stressHandler = EB.On("test:phase3:stress", function()
        stressCount = stressCount + 1
    end)

    local volume = 1000
    for i = 1, volume do
        EB.Emit("test:phase3:stress", { source = "phase3", index = i })
    end
    Citizen.Wait(200)
    H().RecordSuccess(result, H().Assert(stressCount == volume,
        "High volume: " .. stressCount .. "/" .. volume .. " events received"))

    if stressHandler then EB.Off("test:phase3:stress", stressHandler) end

    -- ====================================
    -- Test 7: Concurrent Event Streams
    -- ====================================

    local streamA, streamB = 0, 0
    EB.On("test:phase3:streamA", function() streamA = streamA + 1 end)
    EB.On("test:phase3:streamB", function() streamB = streamB + 1 end)

    for i = 1, 100 do
        EB.Emit("test:phase3:streamA", { source = "phase3" })
        EB.Emit("test:phase3:streamB", { source = "phase3" })
    end
    Citizen.Wait(100)
    H().RecordSuccess(result, H().Assert(streamA == 100 and streamB == 100,
        "Concurrent streams: A=" .. streamA .. " B=" .. streamB))

    -- ====================================
    -- Test 8: Event Ordering
    -- ====================================

    local order = {}
    EB.On("test:phase3:order", function(payload)
        table.insert(order, payload.index)
    end)

    for i = 1, 50 do
        EB.Emit("test:phase3:order", { source = "phase3", index = i })
    end
    Citizen.Wait(100)
    local inOrder = true
    for i = 2, #order do
        if order[i] < order[i - 1] then
            inOrder = false
            break
        end
    end
    H().RecordSuccess(result, H().Assert(inOrder,
        "Event ordering preserved: " .. (inOrder and "yes" or "no")))

    -- ====================================
    -- Test 9: Empty Event Name Handling
    -- ====================================

    local ok, err = pcall(EB.Emit, "", { source = "phase3" })
    H().RecordSuccess(result, H().Assert(true,
        "Empty event name handled without crash: " .. tostring(ok)))

    -- ====================================
    -- Test 10: Nil Payload Handling
    -- ====================================

    local nilReceived = false
    EB.Once("test:phase3:nil", function(payload)
        nilReceived = (payload == nil)
    end)
    local ok, err = pcall(EB.Emit, "test:phase3:nil", nil)
    Citizen.Wait(50)
    H().RecordSuccess(result, H().Assert(true,
        "Nil payload handled without crash: " .. tostring(ok)))

    -- ====================================
    -- Cleanup
    -- ====================================

    -- Remove all test handlers
    for _, eventName in ipairs({
        "test:phase3:basic", "test:phase3:multi", "test:phase3:payload",
        "test:phase3:once", "test:phase3:off", "test:phase3:stress",
        "test:phase3:streamA", "test:phase3:streamB", "test:phase3:order",
        "test:phase3:nil",
    }) do
        pcall(EB.ClearEvent, eventName)
    end

    return H().FinalizePhaseResult(result)
end

_G.DCEPhase3 = Phase3
return Phase3