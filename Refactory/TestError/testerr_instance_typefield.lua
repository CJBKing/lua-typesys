package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

local new = typesys.new
local delete = typesys.delete

XXX = typesys.def.XXX{}
XXX.x = 1

function XXX:__ctor()
	self.x = 2	-- 错误：x是类型的字段，被所有对象共享读取，不是对象的字段，所以不能写入
end

local obj = new(XXX)
obj = nil


