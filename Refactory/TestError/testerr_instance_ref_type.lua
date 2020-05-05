package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

local new = typesys.new
local delete = typesys.delete

YYY = typesys.def.YYY{}
ZZZ = typesys.def.ZZZ{}

XXX = typesys.def.XXX{
	y = YYY,
	weak_yy = YYY,
}

function XXX:__ctor()
	self.y = new(ZZZ)	-- 错误：y是YYY类型
	self.yy = new(ZZZ)	-- 错误：yy是YYY类型
end

local obj = new(XXX)

obj = nil


