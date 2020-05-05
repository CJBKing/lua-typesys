package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

local new = typesys.new
local delete = typesys.delete

XXX = typesys.def.XXX{
	i = 1,
	s = "",
	b = false,
}

function XXX:__ctor()
	self.i = ""		 -- 错误：i是number类型
	self.s = true	 -- 错误：s是string类型
	self.b = 1		 -- 错误：i是boolean类型
end

local obj = new(XXX)
obj = nil


