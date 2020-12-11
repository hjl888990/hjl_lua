--
-- Created by IntelliJ IDEA.
-- User: hjl
-- Date: 2019/9/2
-- Time: 16:24
-- To change this template use File | Settings | File Templates.
-- 降级

local _class = {}

--[[
    接口降级
    uri='/c/a'
    degrade_config= ["percent":0.01~1] (percent 降级比例)
--]]
_class.uri_degrade = function(uri, degrade_config)
    if uri == nil then
        _COMMON.log("uri_degrade[uri] is null")
        return false
    end
    if degrade_config == nil then
        _COMMON.log("uri_degrade[degrade_config] is null")
        return false
    end
    if degrade_config['percent'] == nil then
        _COMMON.log("uri_degrade[percent] is null")
        return false
    end
    local percent = tonumber(degrade_config['percent'])
    if percent == 0 or percent < 0.01 then
        return false
    end

    if percent >= 1 then
        return true
    end
    --设置时间种子[高并发下概率会有偏差]
    local randomseed_num = tonumber(tostring(os.time()):reverse():sub(1, 6)) + os.clock()
    math.randomseed(randomseed_num)
    local tmp_percent = math.random(1, 100)
    if tmp_percent <= percent * 100 then
        return true
    end
    return false
end

return _class;