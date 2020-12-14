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
    request='/c/a'
    degrade_config= ["percent":0.01~1] (percent 降级比例)
--]]
_class.request_degrade = function(request_key, degrade_config)
    local is_degrade = false
    if request_key == nil then
        _COMMON.writeLog("function degrade_model.request_degrade params.request_key error")
        return is_degrade
    end
    if degrade_config == nil then
        _COMMON.writeLog("function degrade_model.request_degrade params.degrade_config error")
        return is_degrade
    end
    if degrade_config['percent'] == nil then
        _COMMON.writeLog("function degrade_model.request_degrade params.percent error")
        return is_degrade
    end
    local percent = tonumber(degrade_config['percent'])
    if percent == 0 or percent < 0.01 then
        return is_degrade
    end

    if percent >= 1 then
        _COMMON.writeLog("request_key is degrade#" .. request_key .. "#", "request_degrade", "notice")
        is_degrade = true
        return is_degrade
    end
    --设置时间种子[高并发下概率会有偏差]
    local randomseed_num = tonumber(tostring(os.time()):reverse():sub(1, 6)) + os.clock()
    math.randomseed(randomseed_num)
    local tmp_percent = math.random(1, 100)
    if tmp_percent <= percent * 100 then
        _COMMON.writeLog("request_key is degrade#" .. request_key .. "#", "request_degrade", "notice")
        is_degrade = true
        return is_degrade
    end
    return is_degrade
end

return _class;