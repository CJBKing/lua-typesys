package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

local new = typesys.new
local delete = typesys.delete

local a = new(typesys.map, type(0), type(""))
a:set(1, 1)			-- 错误：map元素类型为string，不能用number
a = nil


