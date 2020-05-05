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
		local x = self.x
		self.x = nil
		delete(x) -- 错误：self.x = nil已经释放了x
	end
end

local obj = new(XXX, true)
obj:foo()
obj = nil


