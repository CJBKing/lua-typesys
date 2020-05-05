package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

local new = typesys.new
local delete = typesys.delete

XXX = {}
YYY = typesys.def.YYY{}

local a_1 = new(typesys.map, type(0), type("")) -- 正确的做法
local a_2 = new(typesys.map, 0, type(""))		-- 错误
local a_3 = new(typesys.map, XXX, type(""))		-- 错误
local a_4 = new(typesys.map, YYY, type(""))		-- 错误
a_1 = nil
a_2 = nil
a_3 = nil
a_4 = nil


