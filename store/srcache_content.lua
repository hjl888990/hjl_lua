--
-- Created by IntelliJ IDEA.
-- User: hjl
-- Date: 2019/9/25
-- Time: 15:46
-- To change this template use File | Settings | File Templates.
--
-- srcache缓存功能
local resty_redis = require "resty.redis" -- redis模块引入
local resty_lock = require "resty.lock"
local shared_srcache_data = ngx.shared.srcache_data
local srcache_lock = "srcache_lock"
local url_srcache_hash_key = 'url_srcache_cache:';

local fetchCache = function(key)
    local cache = resty_redis.new()
    cache:set_timeout(1000) --超时时间
    local redis_host = "127.0.0.1"
    local redis_port = "6379"
    local ok, err = cache.connect(cache, redis_host, redis_port)
    if not ok then
        _COMMON.log("redis[" .. redis_host .. ":" .. redis_port .. "] errorMsg:" .. err)
        return nil
    end

    local res, err = cache:get(key)
    -- redis缓存未过期
    if res and res ~= ngx.null then
        return res, err
    end

    -- redis缓存不存在或过期
    -- step 2: 锁定一个请求更新redis缓存
    local lock, err = resty_lock:new(srcache_lock, { exptime = 30, timeout = 5 })
    if not lock then
        _COMMON.log("failed to create lock: " .. err)
        local shared_res, shared_err = shared_srcache_data:get(key)
        return shared_res, shared_err
    end

    local elapsed, err = lock:lock(key)
    if not elapsed then
        _COMMON.log("failed to acquire the lock: " .. err)
        local shared_res, shared_err = shared_srcache_data:get(key)
        return shared_res, shared_err
    end

    -- lock successfully acquired!

    -- step 3: 高并发情况下，上次请求可能已经更新了redis与共享内存，需要再次检测redis的缓存数据
    local redis_res, redis_err = cache:get(key)
    -- redis缓存未过期
    if redis_res and redis_err ~= ngx.null then
        local ok, err = lock:unlock()
        if not ok then
            _COMMON.log("failed to unlock: " .. err)
        end
        cache:close()
        return redis_res, redis_err
    end

    -- redis缓存过期，请求会到后端服务更新redis缓存
    _COMMON.log("doris[#BizLog# redisSrcacheNeedUpdate ]", ngx.NOTICE)
    local ok, err = lock:unlock()
    if not ok then
        _COMMON.log("failed to unlock: " .. err)
    end
    return nil, redis_err
end

-- srcache_store
local storeCache = function(key, value, ttl)
    -- step 1: 存储缓存数据到redis
    local cache = resty_redis.new()
    cache:set_timeout(1000) --超时时间
    local redis_host = "127.0.0.1"
    local redis_port = "6379"
    local ok, err = cache.connect(cache, redis_host, redis_port)
    if not ok then
        _COMMON.log("redis[" .. redis_host .. ":" .. redis_port .. "] errorMsg:" .. err)
        return nil
    end

    local res, err = cache:setnx(key, value)
    if not res or res == 0 then
        return res, err
    end

    local res, err = cache:expire(key, ttl)
    if not res then
        cache:del(key)
        return nil, err
    end
    cache:close()
    return res, err
end


local run = function()
    local method = ngx.req.get_method()
    local key = ngx.var.arg_key
    key = url_srcache_hash_key .. key

    if method == "GET" then
        local res, err = fetchCache(key)
        if not res then
            if err then
                ngx.log(ngx.ERR, err)
            end
            _COMMON.log("doris[#BizLog# srcacheFetchFailed ]", ngx.NOTICE)
            ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
        end
        _COMMON.log("doris[#BizLog# srcacheFetchSuccess ]", ngx.NOTICE)
        ngx.print(res)
    elseif method == "PUT" then
        local value = ngx.req.get_body_data()

        -- 处理请求失败的json结果 {"code":0,"msg":"param error:business_type is null","data":[]}
        local reg = '^.*({"ret".*}).*$'
        local new_value = string.gsub(value, reg, '%1')
        if new_value ~= value then
            local res, err = json.decode(new_value)
            -- code等于1才保存到srcache
            if res and res.code then
                if tonumber(res.code) ~= 1 then
                    ngx.exit(ngx.HTTP_OK)
                end
            end
        end
        local ttl = ngx.var.arg_ttl
        local res, err = storeCache(key, value, ttl)
        if not res then
            if err then
                _COMMON.log(err);
            end
            _COMMON.log("doris[#BizLog# srcacheStoreFailed ]", ngx.NOTICE)
            ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
        end
        _COMMON.log("doris[#BizLog# srcacheStoreSuccess ]", ngx.NOTICE)
    else
        ngx.exit(ngx.HTTP_NOT_ALLOWED)
    end
end

run()


