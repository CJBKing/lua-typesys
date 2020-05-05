package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

local new = typesys.new
local delete = typesys.delete

YYY = typesys.def.YYY{}

XXX = typesys.def.XXX{
	y = YYY,
	weak_yy = YYY,
}

function XXX:foo(z)
	self.y = z.y -- 错误：z.y被z持有着，不能赋值给XXX的强引用字段y
	self.yy = z.y -- 正确的做法：赋值给弱引用字段yy
end

ZZZ = typesys.def.ZZZ{
	y = YYY
}

function ZZZ:__ctor()
	self.y = new(YYY)
end

local obj_1 = new(XXX)
local obj_2 = new(ZZZ)

obj_1:foo(obj_2)

obj_1 = nil
obj_2 = nil


