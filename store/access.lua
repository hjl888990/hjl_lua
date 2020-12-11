--
-- Created by IntelliJ IDEA.
-- User: hjl
-- Date: 2019/9/24
-- Time: 15:36
-- To change this template use File | Settings | File Templates.
--

-- IP黑名单拦截
local function ip_access(cache)
    local ip = require "models.ip"
    local ip_block_list_hash_key = 'ip_block_list_config'
    local is_intercept, cli_ip = ip.intercept(cache, ip_block_list_hash_key)
    if is_intercept then
        _COMMON.log("the ip : " .. cli_ip .. " is intercept", ngx.NOTICE)
        _COMMON.response('{"code":187,"msg":"Execute access forbidden","data":""}', 403);
    end
end

-- url降级&&限流
local function url_access(cache)
    local uri = ngx.var.uri
    local len = #uri
    if len < 1 then
        return
    end
    -- 兼容'/'结尾的请求判断
    if len > 1 then
        local end_str = string.sub(uri, len, len)
        if end_str == '/' then
            uri = string.sub(uri, 1, len - 1)
        end
    end

    -- 获取接口配置：{"degrade":{"percent":0.5},"limit":{"rate":10,"burst":10}}
    local url_access_hash_key = 'url_access_config'
    local uri_config_str = cache:hget(url_access_hash_key, uri)
    if uri_config_str == nil or uri_config_str == ngx.null or uri_config_str == '' or uri_config_str == false then
        return
    end
    local url_config_type = type(uri_config_str)
    if url_config_type ~= 'string' then
        _COMMON.log(" url_access_config[" .. uri .. "] params error:" .. uri_config_str)
        return
    end
    local uri_config = json.decode(uri_config_str)
    url_config_type = type(uri_config)
    if url_config_type ~= 'table' then
        _COMMON.log(" url_access_config[" .. uri .. "] params error:" .. uri_config_str)
        return
    end
    -- 接口降级判断
    if uri_config['degrade'] ~= nil then
        local degrade = require "models.req_degrade"
        local is_degrade = degrade.uri_degrade(uri, uri_config['degrade'])
        if is_degrade then
            _COMMON.log("the uri : " .. uri .. " is degrade", ngx.NOTICE)
            _COMMON.response('{"code":188,"msg":"The service is temporarily unavailable","data":""}');
        end
    end
    -- 接口限流判断
    if uri_config['limit'] ~= nil then
        local limit = require "models.req_limit"
        local lua_shared_dict = "my_limit_req_store" -- 申请的内存块名称
        local is_limit = limit.uri_limit_qps(lua_shared_dict, uri, uri_config['limit'])
        if is_limit then
            _COMMON.log("the uri : " .. uri .. " is limit", ngx.NOTICE)
            _COMMON.response('{"code":189,"msg":"Server is too busy","data":""}',500);
        end
    end
end

-- 入口
local function run()
    local redis = require "resty.redis" -- redis模块引入
    local cache = redis.new()
    cache:set_timeout(1000) --超时时间
    local redis_host = "127.0.0.1"
    local redis_port = "6379"
    local ok, err = cache.connect(cache, redis_host, redis_port)
    if not ok then
        _COMMON.log("redis[" .. redis_host .. ":" .. redis_port .. "] errorMsg:" .. err)
        return
    end

    --IP黑名单拦截
    -- ip_access(cache)

    -- url降级||限流
    url_access(cache)
end

-- 输出catch信息到日志
local function xTryCatchGetErrorInfo(err)
    _COMMON.log(err .. debug.traceback())
end

--以try/catch方式运行
xpcall(run, xTryCatchGetErrorInfo);
