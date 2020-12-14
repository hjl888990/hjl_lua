--
-- Created by IntelliJ IDEA.
-- User: hjl
-- Date: 2019/9/2
-- Time: 16:24
-- To change this template use File | Settings | File Templates.
-- 限流

local _class = {}

--[[ 接口并发数限流控制
     lua_shared_dict nginx.http申请的内存块
     request_key 接口地址
     limit_config: ['rate'=>$rate,'burst'=>$burst]
--]]
_class.request_limit = function(lua_shared_dict, request_key, limit_config)
    local is_limit = false
    if lua_shared_dict == nil then
        _COMMON.writeLog("function limit_model.request_limit params.lua_shared_dict error")
        return is_limit
    end
    if request_key == nil then
        _COMMON.writeLog("function limit_model.request_limit params.request_key error")
        return is_limit
    end
    if limit_config == nil then
        _COMMON.writeLog("function limit_model.request_limit params.limit_config error")
        return is_limit
    end
    if limit_config['rate'] == nil then
        _COMMON.writeLog("function limit_model.request_limit params.limit_config.rate error")
        return is_limit
    end
    local rate = tonumber(limit_config['rate'])
    if rate <= 0 then
        return is_limit
    end
    if limit_config['burst'] == nil then
        limit_config['burst'] = 0
    end
    local burst = tonumber(limit_config['burst'])
    local limit_req = require "resty.limit.req"
    local lim, err = limit_req.new(lua_shared_dict, rate, burst)
    if not lim then
        _COMMON.writeLog("failed to instantiate a resty.limit.req object: " .. err)
        return is_limit
    end
    local delay, err = lim:incoming(request_key, true)
    -- 触发限速逻辑
    if not delay then
        if err == "rejected" then
            _COMMON.writeLog("request_key is limit#" .. request_key .. "#", "request_limit", "notice")
            is_limit = true
            return is_limit
        else
            _COMMON.writeLog("failed to limit req: " .. err)
            return is_limit
        end
    end
    if delay >= 0.001 then
        -- the 2nd return value holds  the number of excess requests
        -- per second for the specified key. for example, number 31
        -- means the current request rate is at 231 req/sec for the
        -- specified key.
        local excess = err

        -- the request exceeding the 200 req/sec but below 300 req/sec,
        -- so we intentionally delay it here a bit to conform to the
        -- 200 req/sec rate.
        ngx.sleep(delay)
    end

    return is_limit
end

return _class;