package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

local new = typesys.new
local delete = typesys.delete

local a = new(typesys.array, type(0))
local i = a[2] 	-- 错误：数组长度为0，不能访问下标2
a[2] = 2 		-- 错误：数组长度为0，不能直接对下标2赋值
a = nil


