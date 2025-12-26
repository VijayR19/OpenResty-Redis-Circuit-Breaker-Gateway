local cjson = require "cjson.safe"
local cb = ngx.shared.redis_cb
local stats = ngx.shared.cb_stats


local state = cb:get("state") or "closed"
local fails = cb:get("fails") or 0
local opened_at = cb:get("opened_at") or 0

local body = {
    state = state,
    fails = fails,
    opened_at = opened_at,
    calls = stats:get("calls") or 0,
    redis_ok = stats:get("redis_ok") or 0,
    redis_fail = stats:get("redis_fail") or 0,
    cb_open = stats:get("cb_open") or 0,
    half_open = stats:get("half_open_probes") or 0,
}

ngx.say(cjson.encode(body))