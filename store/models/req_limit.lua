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
     url 接口地址
     limit_config: ['rate'=>$rate,'burst'=>$burst]
--]]
_class.uri_limit_qps = function(lua_shared_dict, uri, limit_config)
    if uri == nil then
        _COMMON.log("uri_limit_qps[uri] is null")
        return false
    end
    if limit_config == nil then
        _COMMON.log("uri_limit_qps[limit_config] is null")
        return false
    end
    if limit_config['rate'] == nil then
        _COMMON.log("uri_limit_qps[rate] is null")
        return false
    end
    local rate = tonumber(limit_config['rate'])
    if rate <= 0 then
        _COMMON.log("uri_limit_qps[rate] is " .. rate)
        return false
    end
    if limit_config['burst'] == nil then
        limit_config['burst'] = 0
    end
    local burst = tonumber(limit_config['burst'])
    local limit_req = require "resty.limit.req"
    local lim, err = limit_req.new(lua_shared_dict, rate, burst)
    if not lim then
        _COMMON.log("failed to instantiate a resty.limit.req object: " .. err)
        return false
    end

    local delay, err = lim:incoming(uri, true)
    -- 触发限速逻辑
    if not delay then
        if err == "rejected" then
            return true
        else
            _COMMON.log("failed to limit req: " .. err)
            return false
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
end

return _class;