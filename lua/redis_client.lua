local redis = require "resty.redis"

local _M = {}

function _M.ping(host, port, timeout_ms)
    local red = redis:new()
    red:set_timeout(timeout_ms)

    local ok, err = red:connect(host, port)
    if not ok then
        return nil, "failed to connect: " .. (err or "unknown error")
    end
    
    local pong, perr = red:ping()
    if not pong then
        return nil, "failed to ping: " .. (perr or "unknown error")
    end

    red:set_keepalive(10000, 50)
    return true
end

return _M