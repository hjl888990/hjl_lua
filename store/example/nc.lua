--
-- Created by IntelliJ IDEA.
-- User: hjl
-- Date: 2019/9/2
-- Time: 16:21
-- To change this template use File | Settings | File Templates.
--
local function cache_init(cache, tag, time_out)
    res, err = cache:expire("start:" .. tag, time_out)
    res, err = cache:expire("count:" .. tag, time_out)
    return res;
end

local function run()
    local bind_time = 600 --code冻结时间
    local time_out = 10 --高频code统计时间频率(秒)
    local connect_count = 10 --高频code访问次数阈值
    local _COMMON = require "common" -- 公用函数引入

    local api_list = { "/decode/onlyCheckAuthed" } --检测接口
    local uri = ngx.var.uri --获取请求url，不包含参数
    local len = #uri
    if len < 1 then
        return
    end
    if len > 1 then -- 兼容'/'结尾的请求判断
    local end_str = string.sub(uri, len, len)
    if end_str == '/' then
        uri = string.sub(uri, 1, len - 1)
    end
    end
    local api_check = _COMMON.in_array(uri, api_list)
    if api_check == false then
        return
    end

    --ngx.req.read_body()--获取POST参数
    --local tag = ngx.req.get_post_args()['coding'] or 0 --获取POST参数
    local tag = ngx.req.get_uri_args()['coding'] or 0 --获取GET参数
    if (tag == '' or tag == 'undefined' or tag == 0) then
        return
    end

    --连接redis
    local redis = require "resty.redis.redis"
    local cache = redis.new()
    cache:set_timeout(1000) --超时时间
    local ok, err = cache.connect(cache, "127.0.0.1", "6379") -- 地址只能用ip
    if not ok then
        ngx.log(ngx.ERR, " redis[127.0.0.1:6379] ", err)
        cache:close()
        return
    end
    --[[
    local ok, err = cache:auth("sniAB3dsk3Xbss")
    if not ok then
        ngx.log(ngx.ERR, " redis[127.0.0.1:6380] ",err)
        cache:close()
        return
    end
    local ok, err = cache:select(90)
    if not ok then
        ngx.log(ngx.ERR, " redis[127.0.0.1:6380] ",err)
        cache:close()
        return
    end
    ]] --
    --判断是否被标记危险
    danger, err = cache:get("danger:" .. tag)
    if danger == "1" then
        cache:close()
        _COMMON.response('{"code":288,"msg":"","data":""}')
    end

    start, err = cache:get("start:" .. tag)
    count, err = cache:get("count:" .. tag)
    if start == ngx.null or os.time() - start > time_out then
        res, err = cache:set("start:" .. tag, os.time())
        res, err = cache:set("count:" .. tag, 1)
        cache_init(cache, tag, time_out)
    else
        count = count + 1
        res, err = cache:incr("count:" .. tag)
        if count >= connect_count then
            res, err = cache:set("danger:" .. tag, 1)
            res, err = cache:expire("danger:" .. tag, bind_time)
            res, err = cache:expire("start:" .. tag, bind_time)
            res, err = cache:expire("count:" .. tag, bind_time)
        end
    end
    cache:close()
end

run()