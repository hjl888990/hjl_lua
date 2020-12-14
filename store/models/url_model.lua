--
-- Created by IntelliJ IDEA.
-- User: hjl
-- Date: 2019/9/2
-- Time: 16:24
-- To change this template use File | Settings | File Templates.
-- IP处理

local _class = {}

-- 获取接口配置：{"degrade":{"percent":0.5},"limit":{"rate":10,"burst":10}}
_class.request_access = function(cache, cache_key, url)
    local is_degrade = false
    local is_limit = false
    if (cache == nil) then
        _COMMON.writeLog("function url_model.request_access params error#cache#")
        return is_degrade, is_limit
    end
    if (cache_key == nil) then
        _COMMON.writeLog("function url_model.request_access params error#cache_key#")
        return is_degrade, is_limit
    end
    if (url == nil) then
        _COMMON.writeLog("function url_model.request_access params error#url#")
        return is_degrade, is_limit
    end
    local url_access_config_data = cache:hget(cache_key, url)
    if (url_access_config_data == nil or url_access_config_data == ngx.null or url_access_config_data == '' or url_access_config_data == false) then
        return is_degrade, is_limit
    end
    local url_access_config_data_type = type(url_access_config_data)
    if (url_access_config_data_type == nil or url_access_config_data_type ~= 'string') then
        _COMMON.writeLog("url_access_config_data_type error#" .. url .. "#")
        return is_degrade, is_limit
    end
    url_access_config_data = json.decode(url_access_config_data)
    url_access_config_data_type = type(url_access_config_data)
    if (url_access_config_data_type == nil or url_access_config_data_type ~= 'table') then
        _COMMON.writeLog("url_access_config_data_type error#" .. url .. "#")
        return is_degrade, is_limit
    end
    local request_key = url
    -- 接口降级判断
    if url_access_config_data['degrade'] ~= nil then
        local degrade_model = require "models.request_access.degrade_model"
        is_degrade = degrade_model.request_degrade(request_key, url_access_config_data['degrade'])
    end
    -- 接口限流判断
    if url_access_config_data['limit'] ~= nil then
        local limit_model = require "models.request_access.limit_model"
        local lua_shared_dict = "my_limit_req_store" -- 申请的内存块名称
        is_limit = limit_model.request_limit(lua_shared_dict, request_key, url_access_config_data['limit'])

    end
    return is_degrade, is_limit
end

return _class;