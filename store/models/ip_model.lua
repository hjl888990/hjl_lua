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
_class.intercept = function(cache, cache_key, ip)
    local is_block = false
    if (cache == nil) then
        _COMMON.writeLog("function ip_model.intercept params.cache error")
        return is_block
    end
    if (cache_key == nil) then
        _COMMON.writeLog("function ip_model.intercept params.cache_key error")
        return is_block
    end
    if (ip == nil) then
        _COMMON.writeLog("function ip_model.intercept params.ip error")
        return is_block
    end
    local cache_data = cache:hget(cache_key, ip) --获取限制信息
    if (cache_data == nil or cache_data == ngx.null or cache_data == '' or cache_data == false) then
        return is_block
    end
    cache_data = tonumber(cache_data) --类型转化
    if (cache_data == -1) then
        _COMMON.writeLog("ip no access allowed#" .. ip .. "#", "ip_intercept", "notice")
        is_block = true
        return is_block
    end
    local now_time = os.time() -- 当前时间戳
    if (cache_data >= now_time) then
        _COMMON.writeLog("ip no access allowed#" .. ip .. "#", "ip_intercept", "notice")
        is_block = true
        return is_block
    end
    cache:hdel(cache_key, ip) -- 移除限制
    return is_block
end

return _class;