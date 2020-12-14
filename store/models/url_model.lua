--
-- Created by IntelliJ IDEA.
-- User: hjl
-- Date: 2019/9/2
-- Time: 16:24
-- To change this template use File | Settings | File Templates.
-- IP处理

local _class = {}

-- 获取接口配置：
-- {"degrade":{"percent":0.5},"limit":{"rate":0,"burst":0}}
-- {"degrade":{"percent":0},"limit":{"rate":10,"burst":10}}
-- {"degrade":{"percent":0},"limit":{"rate":0,"burst":0},"params_limit":{"coding":{"params_config":{"request_method":"POST","request_params":"coding"},"limit_config":{"degrade":{"percent":0},"limit":{"rate":10,"burst":10}}}}}
_class.request_access = function(cache, cache_key, url)
    local is_degrade = false
    local is_limit = false
    if (cache == nil) then
        _COMMON.writeLog("function url_model.request_access params.cache error")
        return is_degrade, is_limit
    end
    if (cache_key == nil) then
        _COMMON.writeLog("function url_model.request_access params.cache_key error")
        return is_degrade, is_limit
    end
    if (url == nil) then
        _COMMON.writeLog("function url_model.request_access params.url error")
        return is_degrade, is_limit
    end
    local url_access_config_data = cache:hget(cache_key, url)
    if (url_access_config_data == nil or url_access_config_data == ngx.null or url_access_config_data == '' or url_access_config_data == false) then
        return is_degrade, is_limit
    end
    local url_access_config_data_type = type(url_access_config_data)
    if (url_access_config_data_type == nil or url_access_config_data_type ~= 'string') then
        _COMMON.writeLog("function url_model.request_access params.url_access_config_data_type error")
        return is_degrade, is_limit
    end
    url_access_config_data = json.decode(url_access_config_data)
    url_access_config_data_type = type(url_access_config_data)
    if (url_access_config_data_type == nil or url_access_config_data_type ~= 'table') then
        _COMMON.writeLog("function url_model.request_access params.url_access_config_data_type error")
        return is_degrade, is_limit
    end
    local request_key = url
    local degrade_model = require "models.request_access.degrade_model"
    local limit_model = require "models.request_access.limit_model"
    local lua_shared_dict = "my_limit_req_store" -- 申请的内存块名称
    -- 接口降级判断
    if url_access_config_data['degrade'] ~= nil then
        is_degrade = degrade_model.request_degrade(request_key, url_access_config_data['degrade'])
    end
    -- 接口限流判断
    if url_access_config_data['limit'] ~= nil then
        is_limit = limit_model.request_limit(lua_shared_dict, request_key, url_access_config_data['limit'])
    end
    if (is_degrade or is_limit) then
        return is_degrade, is_limit
    end
    if url_access_config_data['params_limit'] == nil then
        return is_degrade, is_limit
    end
    -- 指定参数配置
    for k, v in pairs(url_access_config_data['params_limit']) do
        if (v['params_config']['request_params'] ~= nil and v['params_config']['request_method'] ~= nil and v['limit_config'] ~= nil) then

            local request_method = v['params_config']['request_method']
            request_method = string.lower(request_method)
            if (request_method ~= 'post') then
                request_method = 'get'
            end
            local request_params_set = true
            local request_params_str = '?'
            for r_k, r_v in pairs(_COMMON.split(v['params_config']['request_params'], ":")) do
                local args = '';
                if request_method == 'post' then
                    ngx.req.read_body()
                    args = ngx.req.get_post_args()
                else
                    args = ngx.req.get_uri_args()
                end
                if (args[r_v] == nil or args[r_v] == '' or args[r_v] == 'undefined' or args[r_v] == 0) then
                    request_params_set = false;
                    break
                end
                request_params_str = request_params_str .. r_v .. "=" .. args[r_v] .. "&"
            end
            if (request_params_set == false) then
                break
            end
            local request_key = string.sub(url .. request_params_str, 1, -2)
            -- 接口降级判断
            if v['limit_config']['degrade'] ~= nil then
                is_degrade = degrade_model.request_degrade(request_key, v['limit_config']['degrade'])
            end
            -- 接口限流判断
            if v['limit_config']['limit'] ~= nil then
                is_limit = limit_model.request_limit(lua_shared_dict, request_key, v['limit_config']['limit'])
            end
            if (is_degrade or is_limit) then
                break
            end
        end
    end
    return is_degrade, is_limit
end

return _class;