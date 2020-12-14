local _COMMON = {}

-- 调试输出
_COMMON.debug = function(content)
    if (content == nil) then
        content = 'success'
    end
    if type(content) ~= 'string' then
        content = json.encode(content)
    end
    ngx.header.content_type = "application/json;charset=utf8"
    ngx.print(content)
    ngx.exit(200);
end

-- 返回结果给客户端
_COMMON.response = function(content, code)
    if (code == '' or code == 'undefined' or code == nil) then
        code = 200
    end
    ngx.header.content_type = "application/json;charset=utf8"
    ngx.status = code
    ngx.print(content)
    ngx.exit(code);
end

--获取客户端ip
_COMMON.get_client_ip = function()
    local headers = ngx.req.get_headers()
    local ip = headers["X-REAL-IP"] or headers["X_FORWARDED_FOR"] or ngx.var.remote_addr or "0.0.0.0"
    return ip
end

--[[
    日志函数
    level: 默认为 ngx.ERR
    取值范围：ngx.STDERR,ngx.EMERG,ngx.ALERT,ngx.CRIT,ngx.ERR,ngx.WARN,ngx.NOTICE,ngx.INFO,ngx.DEBUG
    请配合nginx.conf中error_log的日志级别使用
]]
_COMMON.log = function(content, level)
    if (content == '' or content == 'undefined' or content == nil) then
        return
    end
    if type(content) ~= 'string' then
        content = json.encode(content)
    end
    if (level == nil) then
        level = ngx.ERR;
    end
    ngx.log(level, content)
end

-- 字符串切割成数组
_COMMON.split = function(str, delim)
    if type(delim) ~= "string" or string.len(delim) <= 0 then
        return
    end
    local start = 1
    local tab = {}
    while true do
        local pos = string.find(str, delim, start, true)
        if not pos then
            break
        end
        table.insert(tab, string.sub(str, start, pos - 1))
        start = pos + string.len(delim)
    end
    table.insert(tab, string.sub(str, start))
    return tab
end


-- 一维数组存在value判断
_COMMON.in_array = function(value, tbl)
    for k, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- 自定义日志输出
_COMMON.writeLog = function(content, tag, level)
    if (content == nil) then
        return
    end
    if (LOG_FILE_PATH == nil) then
        _COMMON.log(content);
        return
    end
    if (tag == nil) then
        tag = "application"
    end
    if (level == nil) then
        level = "error"
    end
    local msg = "[" .. _COMMON.get_client_ip() .. "][" .. os.date("%Y-%m-%d %X", os.time()) .. "][" .. level .. "][" .. tag .. "]" .. content .. "\n"
    file = io.open(LOG_FILE_PATH, "a+")
    file:write(msg)
    file:flush()
    file:close()
end

return _COMMON
