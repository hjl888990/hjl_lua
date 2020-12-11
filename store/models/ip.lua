--
-- Created by IntelliJ IDEA.
-- User: hjl
-- Date: 2019/9/2
-- Time: 16:24
-- To change this template use File | Settings | File Templates.
-- IP处理

local _class = {}

--[[
    黑名单IP拦截
    hash存储对应ip的限制信息：-1 代表永久限制；其他代表限制截止时间戳
-- ]]
_class.intercept = function(cache, ip_block_list_hash_key)
    if cache == nil then
        _COMMON.log("ip intercept[cache] is null")
        return false
    end
    if ip_block_list_hash_key == nil then
        ip_block_list_hash_key = 'ip_block_list_config'
    end
    local headers = ngx.req.get_headers()
    local cli_ip = headers["X-REAL-IP"] or headers["X_FORWARDED_FOR"] or ngx.var.remote_addr or "0.0.0.0"
    if (cli_ip == "0.0.0.0") then
        return false
    end
    local block_cache_data = cache:hget(ip_block_list_hash_key, cli_ip) -- 缓存内存被限制访问的截止时间戳
    if block_cache_data == nil or block_cache_data == ngx.null or block_cache_data == '' or block_cache_data == false then
        return false
    end
    block_cache_data = tonumber(block_cache_data)
    if block_cache_data == -1 then
        return true, cli_ip
    end
    local now_time = os.time()
    if block_cache_data >= now_time then
        return true, cli_ip
    end
    cache:hdel(ip_block_list_hash_key, cli_ip)
    return false
end

return _class;