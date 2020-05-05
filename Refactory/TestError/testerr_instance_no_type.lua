package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

local new = typesys.new
local delete = typesys.delete

XXX = {}

local obj = new(XXX) -- 错误：没有用typesys.def定义XXX类型
obj = nil


