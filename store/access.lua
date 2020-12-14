--
-- Created by IntelliJ IDEA.
-- User: hjl
-- Date: 2019/9/24
-- Time: 15:36
-- To change this template use File | Settings | File Templates.
--

-- IP黑名单拦截
local function ip_access(cache)
    local ip = _COMMON.get_client_ip()
    if (ip == nil or ip == "0.0.0.0") then
        return
    end
    local ip_model = require "models.ip_model"
    local cache_key = 'nginx_lua_access_config:ip_block_list'
    local is_block = ip_model.intercept(cache, cache_key, ip)
    if is_block then
        _COMMON.response('{"code":187,"msg":"Execute access forbidden","data":""}', 403);
    end
end

-- url降级&&限流
local function url_access(cache)
    local url = ngx.var.uri
    if url == nil then
        return
    end
    local len = #url
    if len < 1 then
        return
    end
    -- 兼容'/'结尾的请求判断
    if len > 1 then
        local end_str = string.sub(url, len, len)
        if (end_str ~= nil and end_str == '/') then
            url = string.sub(url, 1, len - 1)
        end
    end
    local cache_key = 'nginx_lua_access_config:url_limit'
    local url_model = require "models.url_model"
    local is_degrade, is_limit = url_model.request_access(cache, cache_key, url)
    if is_degrade then
        _COMMON.response('{"code":188,"msg":"The service is temporarily unavailable","data":""}');
    end
    if is_limit then
        _COMMON.response('{"code":189,"msg":"Server is too busy","data":""}');
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
        _COMMON.writeLog("redis " .. redis_host .. ":" .. redis_port .. " " .. err)
        return
    end

    --IP黑名单拦截
    -- ip_access(cache)

    -- url降级||限流
    url_access(cache)

end

-- 输出catch信息到日志
local function xTryCatchGetErrorInfo(err)
    _COMMON.writeLog(err .. debug.traceback())
end

--以try/catch方式运行
xpcall(run, xTryCatchGetErrorInfo);
