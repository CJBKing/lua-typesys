package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

local new = typesys.new
local delete = typesys.delete

local a = new(typesys.array, type(0))
a[1] = ""	-- 错误：数组元素类型为number，不能赋值string
a = nil


