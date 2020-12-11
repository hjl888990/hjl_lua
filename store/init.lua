--
-- Created by IntelliJ IDEA.
-- User: hjl
-- Date: 2019/9/18
-- Time: 17:27
-- To change this template use File | Settings | File Templates.
--
_COMMON = require "common" -- 公用函数引入
json = require "resty.json" -- json模块引入
LOG_FILE_PATH = '/tmp/nginx_lua.log' -- 自定义日志存放地址