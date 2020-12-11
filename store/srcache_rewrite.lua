--
-- Created by IntelliJ IDEA.
-- User: hjl
-- Date: 2019/9/25
-- Time: 15:45
-- To change this template use File | Settings | File Templates.
--
local getKey = function()
    local redis = require "resty.redis" -- redis模块引入
    local cache = redis.new()
    cache:set_timeout(1000) --超时时间
    local redis_host = "127.0.0.1"
    local redis_port = "6379"
    local ok, err = cache.connect(cache, redis_host, redis_port)
    if not ok then
        _COMMON.log("redis[" .. redis_host .. ":" .. redis_port .. "] errorMsg:" .. err)
        return nil
    end
    local url_srcache_config_key = 'url_srcache_config';
    local uri = string.match(ngx.var.request_uri, "[^?]+")
    local len = #uri
    if len < 1 then
        return nil
    end
    -- 兼容'/'结尾的请求判断
    if len > 1 then
        local end_str = string.sub(uri, len, len)
        if end_str == '/' then
            uri = string.sub(uri, 1, len - 1)
        end
    end
    -- {"is_open":false,"ttl":100,"fields":{"id":1,"name":0}}
    local uri_config_str = cache:hget(url_srcache_config_key, uri)
    if uri_config_str == nil or uri_config_str == ngx.null or uri_config_str == '' or uri_config_str == false then
        return nil
    end
    local url_config_type = type(uri_config_str)
    if url_config_type ~= 'string' then
        _COMMON.log("url_srcache_hash_key[" .. uri .. "] params error:" .. uri_config_str)
        return nil
    end
    local uri_config = json.decode(uri_config_str)
    url_config_type = type(uri_config)
    if url_config_type ~= 'table' then
        _COMMON.log("url_srcache_hash_key[" .. uri .. "] params error:" .. uri_config_str)
        return nil
    end

    -- srcache未配置或者关闭
    if uri_config['is_open'] == nil or uri_config['is_open'] ~= true then
        return nil
    end
    local ttl = 600
    if ngx.var.ttl ~= nil then
        ttl = ngx.var.ttl
    end
    if uri_config['ttl'] ~= nil then
        ttl = tonumber(uri_config['ttl'])
    end
    local key = uri
    local fields = {}
    local args = ngx.req.get_uri_args() or {}
    if uri_config['fields'] ~= nil and type(uri_config['fields']) == 'table' then
        for field_name, is_request in pairs(uri_config['fields']) do
            local arg_str = '';
            for arg_name, arg_value in pairs(args) do
                if field_name == arg_name then
                    arg_str = arg_name .. "=" .. arg_value;
                    break
                end
            end
            --必选字段不存在，则不走srcache
            if is_request == 1 and arg_str == '' then
                return nil
            end
            if arg_str ~= '' then
                table.insert(fields, arg_str)
            end
        end
    end
    if #fields > 0 then
        key = key .. "?" .. table.concat(fields, '&')
    end
    key = ngx.md5(key)
    return key, ttl
end

-- 入口
local run = function()
    local key, ttl = getKey()
    if key then
        ngx.var.skip = 0 --开启srcache
        ngx.var.key = key
        if ttl then
            ngx.var.ttl = ttl
        end
    end
end

-- 输出catch信息到日志
local function xTryCatchGetErrorInfo(err)
    _COMMON.log(err .. debug.traceback())
end

--以try/catch方式运行
xpcall(run, xTryCatchGetErrorInfo);