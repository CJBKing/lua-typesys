package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

local new = typesys.new
local delete = typesys.delete

XXX = typesys.def.XXX{
	i = 0,
	_i = 0
}

function XXX:__ctor(i1, i2)
	self.i = i1
	self._i = i2 -- 正确：在类实例对象的函数内可以访问
end

local obj = new(XXX, 1, 2)

local i1 = obj.i
local i2 = obj._i -- 错误：_i是私有字段，不能获取

obj.i = i1 + 1
obj._i = i2 + 1 -- 错误：_i是私有字段，不能写入

obj = nil


