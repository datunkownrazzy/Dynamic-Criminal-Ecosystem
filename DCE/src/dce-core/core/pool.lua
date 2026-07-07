-- DCE Object Pooling Service
-- Pool reusable objects to minimize allocations.
-- Spec: ADR-0015

local Pool = {}
local pools = {}        -- poolName -> { available = {}, inUse = {}, createFn, resetFn, maxSize }
local logger
local cachedConfig = {}

--- Initialize the pool service with a reference to the logger.
function Pool.Init(log)
    logger = log
    cachedConfig = _G.Config or {}
end

--- Log a message through the logger if available.
local function log(level, module, message, ...)
    if logger then
        logger.Log(module, level, message, ...)
    end
end

--- Create a new object pool
---@param poolName string Unique pool identifier (e.g., "npc", "vehicle", "evidence")
---@param createFn function Function to create new objects
---@param resetFn function Function to reset objects when returned to pool
---@param options table Configuration { initialSize, maxSize, growIncrement }
function Pool.Create(poolName, createFn, resetFn, options)
    if not poolName or type(poolName) ~= "string" then
        log("error", "core", "Pool.Create: poolName must be a string")
        return nil
    end
    
    if not createFn or type(createFn) ~= "function" then
        log("error", "core", "Pool.Create: createFn must be a function")
        return nil
    end
    
    options = options or {}
    
    if pools[poolName] then
        log("warn", "core", "Pool.Create: pool '%s' already exists", poolName)
        return pools[poolName]
    end
    
    pools[poolName] = {
        available = {},
        inUse = {},
        createFn = createFn,
        resetFn = resetFn,
        maxSize = options.maxSize or 100,
        growIncrement = options.growIncrement or 10,
        initialSize = options.initialSize or 0,
        totalCreated = 0,
        totalReused = 0,
    }
    
    -- Pre-populate the pool
    if options.initialSize and options.initialSize > 0 then
        for i = 1, options.initialSize do
            local obj = createFn()
            table.insert(pools[poolName].available, obj)
            pools[poolName].totalCreated = pools[poolName].totalCreated + 1
        end
    end
    
    log("info", "core", "Pool created: %s (initial=%d, max=%d)", poolName, options.initialSize or 0, options.maxSize or 100)
    return pools[poolName]
end

--- Acquire an object from a pool
---@param poolName string
---@return any|nil The pooled object
function Pool.Acquire(poolName)
    local pool = pools[poolName]
    if not pool then
        log("warn", "core", "Pool.Acquire: pool '%s' does not exist", poolName)
        return nil
    end
    
    local obj = table.remove(pool.available)
    
    if obj then
        pool.inUse[obj] = true
        pool.totalReused = pool.totalReused + 1
        return obj
    end
    
    -- Need to create a new object
    if pool.totalCreated < pool.maxSize then
        obj = pool.createFn()
        pool.inUse[obj] = true
        pool.totalCreated = pool.totalCreated + 1
        return obj
    end
    
    log("warn", "core", "Pool.Acquire: pool '%s' at max capacity (%d)", poolName, pool.maxSize)
    return nil
end

--- Return an object to the pool
---@param poolName string
---@param obj any The object to return
function Pool.Release(poolName, obj)
    local pool = pools[poolName]
    if not pool then return end
    
    pool.inUse[obj] = nil
    
    -- Reset the object if a reset function is provided
    if pool.resetFn then
        local success, err = pcall(pool.resetFn, obj)
        if not success then
            log("error", "core", "Pool.Release: resetFn failed for object in '%s': %s", poolName, tostring(err))
        end
    end
    
    -- Only return to pool if under max size
    if pool.totalCreated <= pool.maxSize then
        table.insert(pool.available, obj)
    else
        -- Pool is over max, let GC handle it
    end
end

--- Get pool statistics
---@param poolName string
---@return table
function Pool.GetStats(poolName)
    local pool = pools[poolName]
    if not pool then
        return { available = 0, inUse = 0, totalCreated = 0, totalReused = 0, maxSize = 0 }
    end
    
    local inUseCount = 0
    for _ in pairs(pool.inUse) do inUseCount = inUseCount + 1 end
    
    return {
        available = #pool.available,
        inUse = inUseCount,
        totalCreated = pool.totalCreated,
        totalReused = pool.totalReused,
        maxSize = pool.maxSize,
    }
end

--- Get pool configuration
---@param poolName string
---@return table|nil
function Pool.GetConfig(poolName)
    local pool = pools[poolName]
    if not pool then return nil end
    
    return {
        maxSize = pool.maxSize,
        growIncrement = pool.growIncrement,
    }
end

--- Configure pool settings at runtime
---@param poolName string
---@param options table { maxSize, growIncrement }
function Pool.Configure(poolName, options)
    local pool = pools[poolName]
    if not pool then return false end
    
    if options.maxSize then
        pool.maxSize = options.maxSize
    end
    if options.growIncrement then
        pool.growIncrement = options.growIncrement
    end
    
    return true
end

--- Clear a pool (remove all available objects)
---@param poolName string
function Pool.Clear(poolName)
    local pool = pools[poolName]
    if pool then
        pool.available = {}
        -- Note: We don't clear inUse objects - they need to be released first
    end
end

--- Shutdown the pool service
function Pool.Shutdown()
    for poolName, pool in pairs(pools) do
        Pool.Clear(poolName)
        pool.inUse = {}
    end
    pools = {}
    log("info", "core", "Pool service shutdown complete")
end

--- Create predefined pools for common DCE objects
function Pool.InitializeDefaultPools()
    -- NPC Pool
    Pool.Create("npc", 
        function() 
            return { type = "npc", id = nil, state = "idle", position = nil } 
        end,
        function(obj)
            obj.id = nil
            obj.state = "idle"
            obj.position = nil
        end,
        { initialSize = 10, maxSize = 50 }
    )
    
    -- Vehicle Pool
    Pool.Create("vehicle",
        function()
            return { type = "vehicle", model = nil, plate = nil, position = nil }
        end,
        function(obj)
            obj.model = nil
            obj.plate = nil
            obj.position = nil
        end,
        { initialSize = 5, maxSize = 30 }
    )
    
    -- Evidence Pool
    Pool.Create("evidence",
        function()
            return { type = "evidence", id = nil, itemId = nil, chain = {}, status = "active" }
        end,
        function(obj)
            obj.id = nil
            obj.itemId = nil
            obj.chain = {}
            obj.status = "active"
        end,
        { initialSize = 20, maxSize = 100 }
    )
    
    -- Incident/Scenario Pool
    Pool.Create("incident",
        function()
            return { type = "incident", id = nil, state = "pending", stage = nil, priority = "medium" }
        end,
        function(obj)
            obj.id = nil
            obj.state = "pending"
            obj.stage = nil
            obj.priority = "medium"
        end,
        { initialSize = 10, maxSize = 50 }
    )
    
    -- Dispatch Call Pool
    Pool.Create("dispatch_call",
        function()
            return { type = "dispatch_call", callId = nil, status = "pending", priority = "medium" }
        end,
        function(obj)
            obj.callId = nil
            obj.status = "pending"
            obj.priority = "medium"
        end,
        { initialSize = 5, maxSize = 30 }
    )
    
    log("info", "core", "Default pools initialized")
end

_G.DCEPool = Pool