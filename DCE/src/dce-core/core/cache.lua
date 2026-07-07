-- DCE Cache Service
-- Configurable caching with TTL, size limits, and invalidation.
-- Spec: ADR-0015

local Cache = {}
local caches = {}      -- cacheName -> cache definition
local logger
local cachedConfig = {}

--- Initialize the cache service with a reference to the logger.
function Cache.Init(log)
    logger = log
    cachedConfig = _G.Config or {}
end

--- Log a message through the logger if available.
local function log(level, module, message, ...)
    if logger then
        logger.Log(module, level, message, ...)
    end
end

--- Create a new cache with configuration
---@param cacheName string Unique cache identifier
---@param options table Configuration { ttl, maxSize, evictionPolicy }
function Cache.Create(cacheName, options)
    if not cacheName or type(cacheName) ~= "string" then
        log("error", "core", "Cache.Create: cacheName must be a string")
        return nil
    end
    
    options = options or {}
    
    if caches[cacheName] then
        log("warn", "core", "Cache.Create: cache '%s' already exists, returning existing", cacheName)
        return caches[cacheName]
    end
    
    caches[cacheName] = {
        data = {},
        ttl = options.ttl or 300,          -- 5 minutes default
        maxSize = options.maxSize or 1000,  -- 1000 entries default
        evictionPolicy = options.evictionPolicy or "lru", -- lru|fifo|random
        hits = 0,
        misses = 0,
        evictions = 0,
        lastAccess = {},
    }
    
    log("info", "core", "Cache created: %s (ttl=%ds, maxSize=%d)", cacheName, caches[cacheName].ttl, caches[cacheName].maxSize)
    return caches[cacheName]
end

--- Set a value in the cache
---@param cacheName string
---@param key string
---@param value any
---@return boolean success
function Cache.Set(cacheName, key, value)
    local cache = caches[cacheName]
    if not cache then
        log("warn", "core", "Cache.Set: cache '%s' does not exist", cacheName)
        return false
    end
    
    -- Check if we need to evict
    if cache.maxSize and cache.maxSize > 0 then
        local count = 0
        for _ in pairs(cache.data) do count = count + 1 end
        
        if count >= cache.maxSize then
            Cache._evict(cacheName)
        end
    end
    
    cache.data[key] = {
        value = value,
        timestamp = os.time(),
        expiresAt = os.time() + (cache.ttl or 300),
    }
    cache.lastAccess[key] = os.time()
    
    return true
end

--- Get a value from the cache
---@param cacheName string
---@param key string
---@return any|nil value
function Cache.Get(cacheName, key)
    local cache = caches[cacheName]
    if not cache then
        return nil
    end
    
    local entry = cache.data[key]
    if not entry then
        cache.misses = cache.misses + 1
        return nil
    end
    
    -- Check TTL expiration
    if entry.expiresAt and os.time() > entry.expiresAt then
        Cache.Remove(cacheName, key)
        cache.misses = cache.misses + 1
        return nil
    end
    
    cache.hits = cache.hits + 1
    cache.lastAccess[key] = os.time()
    return entry.value
end

--- Check if key exists and is not expired
---@param cacheName string
---@param key string
---@return boolean
function Cache.Has(cacheName, key)
    local cache = caches[cacheName]
    if not cache then
        return false
    end
    
    local entry = cache.data[key]
    if not entry then
        return false
    end
    
    if entry.expiresAt and os.time() > entry.expiresAt then
        Cache.Remove(cacheName, key)
        return false
    end
    
    return true
end

--- Remove a value from the cache
---@param cacheName string
---@param key string
function Cache.Remove(cacheName, key)
    local cache = caches[cacheName]
    if cache then
        cache.data[key] = nil
        cache.lastAccess[key] = nil
    end
end

--- Invalidate entries matching a pattern
---@param cacheName string
---@param pattern string Lua pattern to match keys
function Cache.InvalidatePattern(cacheName, pattern)
    local cache = caches[cacheName]
    if not cache then return end
    
    for key, _ in pairs(cache.data) do
        if string.match(key, pattern) then
            Cache.Remove(cacheName, key)
        end
    end
end

--- Invalidate all entries in a cache
---@param cacheName string
function Cache.Clear(cacheName)
    local cache = caches[cacheName]
    if cache then
        cache.data = {}
        cache.lastAccess = {}
        cache.hits = 0
        cache.misses = 0
        cache.evictions = 0
    end
end

--- Get cache statistics
---@param cacheName string
---@return table
function Cache.GetStats(cacheName)
    local cache = caches[cacheName]
    if not cache then
        return { hits = 0, misses = 0, evictions = 0, size = 0, maxSize = 0 }
    end
    
    local size = 0
    for _ in pairs(cache.data) do size = size + 1 end
    
    return {
        hits = cache.hits,
        misses = cache.misses,
        evictions = cache.evictions,
        size = size,
        maxSize = cache.maxSize,
        ttl = cache.ttl,
    }
end

--- Internal eviction logic
function Cache._evict(cacheName)
    local cache = caches[cacheName]
    if not cache or cache.evictionPolicy == "none" then return end
    
    local keyToEvict
    local oldest = math.huge
    local firstKey
    
    for key, entry in pairs(cache.data) do
        if not firstKey then firstKey = key end
        
        if cache.evictionPolicy == "lru" then
            local accessTime = cache.lastAccess[key] or entry.timestamp
            if accessTime < oldest then
                oldest = accessTime
                keyToEvict = key
            end
        elseif cache.evictionPolicy == "fifo" then
            if entry.timestamp < oldest then
                oldest = entry.timestamp
                keyToEvict = key
            end
        end
    end
    
    keyToEvict = keyToEvict or firstKey
    if keyToEvict then
        Cache.Remove(cacheName, keyToEvict)
        cache.evictions = cache.evictions + 1
    end
end

--- Clean up expired entries (call periodically)
---@param cacheName string|nil If nil, clean all caches
function Cache.ExpireEntries(cacheName)
    local now = os.time()
    
    if cacheName then
        local cache = caches[cacheName]
        if cache then
            for key, entry in pairs(cache.data) do
                if entry.expiresAt and now > entry.expiresAt then
                    Cache.Remove(cacheName, key)
                end
            end
        end
    else
        for cname, cache in pairs(caches) do
            for key, entry in pairs(cache.data) do
                if entry.expiresAt and now > entry.expiresAt then
                    Cache.Remove(cname, key)
                end
            end
        end
    end
end

--- Get cache configuration
---@return table
function Cache.GetConfig()
    return _G.Config or {}
end

--- Shutdown the cache service
function Cache.Shutdown()
    for cname, _ in pairs(caches) do
        Cache.Clear(cname)
    end
    caches = {}
    log("info", "core", "Cache service shutdown complete")
end

_G.DCECache = Cache