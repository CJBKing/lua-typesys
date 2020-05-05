package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

local new = typesys.new
local delete = typesys.delete

XXX = typesys.def.XXX{
	a = 0,
}

local obj = new(XXX, true)
delete(obj)
local a = obj.a -- 错误：obj已经销毁了
obj.a = 1		-- 错误：obj已经销毁了
obj = nil


