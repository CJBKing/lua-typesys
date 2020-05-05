package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

local new = typesys.new
local delete = typesys.delete

XXX = typesys.def.XXX{
	x = typesys.XXX,
}

function XXX:__ctor(b)
	if b then
		self.x = new(XXX)
	end
end

function XXX:foo()
	if self.x then
		delete(self.x) -- 错误：self.x仍然被self持有着
		-- self.x = nil -- 正确的做法
	end
end

local obj = new(XXX, true)
obj:foo()
obj = nil


