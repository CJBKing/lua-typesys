package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

local new = typesys.new
local delete = typesys.delete

XXX = {}
YYY = typesys.def.YYY{}

local a_1 = new(typesys.array, type(0)) -- 正确的做法
local a_2 = new(typesys.array, 0)		-- 错误：元素类型得是type(0)
local a_3 = new(typesys.array, XXX)		-- 错误：元素类型得是typesys.def定义的类型
local a_4 = new(typesys.array, YYY)		-- 正确的做法
a_1 = nil
a_2 = nil
a_3 = nil
a_4 = nil


