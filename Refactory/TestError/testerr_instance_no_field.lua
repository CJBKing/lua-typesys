package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

local new = typesys.new
local delete = typesys.delete

XXX = typesys.def.XXX{}

function XXX:__ctor()
	local x = self.x -- 错误：x不存在，不能获取
	self.x = x + 1	 -- 错误：x不存在，不能写入
end

local obj = new(XXX)
obj = nil


