local redis_client = require "redis_client"

--- ==== Cofig ====
local REDIS_HOST = "127.0.0.1"
local REDIS_PORT = 6379

local TIMEOUT_MS = 100
local FAIL_THRESHOLD = 3
local OPEN_COOLDOWN_SEC = 5
local HALF_OPEN_MAX_PROBES = 1

-- Policy: allow traffic if Redis is down?
local FAIL_OPEN = true  -- set false to fail closed

-- ==== Shared state ====
local cb = ngx.shared.redis_cb
local stats = ngx.shared.cb_stats


local function now ()
    return ngx.now()
end

local function incr(k)
    stats:incr(k, 1, 0)
end

local function fallback(reason)
    ngx.header["X-CB-Fallback"] = reason or "fallback"
    if FAIL_OPEN then
        ngx.header["X-Result"] = "allowed_without_redis"
        ngx.say("OK (fallback: allowed)")
        return ngx.exit(ngx.HTTP_OK)
    end

    ngx.status = ngx.HTTP_SERVICE_UNAVAILABLE
    ngx.say("Service unavailable (redis dependency)")
    return ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
end

local function set_state(s)
    cb:set("state", s)
end

local function get_state()
    return cb:get("state") or "closed"
end

local function record_success()
    cb:set("fails", 0)
    set_state("closed")
    cb:set("opened_at", 0)
    cb:set("half_open_probes", 0)
end

local function record_failure()
    local fails = (cb:get("fails") or 0) + 1
    cb:set("fails", fails)

    if fails >= FAIL_THRESHOLD then
        set_state("open")
        cb:set("opened_at", now())
        cb:set("half_open_probes", 0)
    end

    return fails
end

local function cooldown_elapsed()
    local opened_at = cb:get("opened_at") or 0
    return (now() - opened_at) >= OPEN_COOLDOWN_SEC
end

local function try_half_open_probe()
    local probes = cb:incr("half_open_probes", 1, 0)
    return probes <= HALF_OPEN_MAX_PROBES
end

-- ==== Request start ====
incr("calls")

local state = get_state()
ngx.header["X-CB-State"] = state
ngx.header["X-CB-Fails"] = cb:get("fails") or 0

-- ==== OPEN =====
if state == "open" then
    incr("cb_open")
    if not cooldown_elapsed() then
        return fallback("open")
    end

    set_state("half_open")
    state = "half_open"
end

-- ==== HALF-OPEN =====
if state == "half_open" then
    ngx.header["X-CB-State"] = "half_open"
    if not try_half_open_probe() then
        return fallback("half_open_no_probe")
    end

    local ok, err = redis_client.ping(REDIS_HOST, REDIS_PORT, TIMEOUT_MS)
    if ok then
        incr("redis_ok")
        record_success()
        ngx.header["X-Redis"] = "pong"
        ngx.say("OK (recovered)")
        return ngx.exit(ngx.HTTP_OK)
    end
    incr("redis_fail")
    set_state("open")
    cb:set("opened_at", now())
    ngx.header["X-Redis-Err"] = err
    return fallback("half_open_failed")
end

-- ==== CLOSED =====
local ok, err = redis_client.ping(REDIS_HOST, REDIS_PORT, TIMEOUT_MS)
if ok then
    incr("redis_ok")
    record_success()
    ngx.header["X-Redis"] = "pong"
    ngx.say("OK")
    return ngx.exit(ngx.HTTP_OK)
end


-- failure in CLOSED
incr("redis_fail")
local fails = record_failure()
ngx.header["X-Redis-Err"] = err
ngx.header["X-CB-Fails"] = fails

return fallback("closed_failed")
