package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

local new = typesys.new
local delete = typesys.delete

YYY = typesys.YYY{}

XXX = typesys.XXX {
	__pool_capacity = -1, 	-- 对象池容量，负数为无限
	__strong_pool = false,	-- 对象池是否使用强引用
	__super = typesys.YYY, 	-- 父类
	i = 0, 					-- 定义number型字段i
	str = "", 				-- 定义string型字段str
	b = false,				-- 定义boolean型字段b
	x = typesys.XXX,		-- 定义类型为A的字段x，此字段将强引用A类型对象，其生命周期由x托管
	weak_x1 = typesys.XXX,   -- 定义类型为A的字段x1，此字段将弱引用A类型对象，弱引用字段使用weak_前缀，请注意：字段名是不包含weak_前缀的
	
	_i = 0,					-- 定义number型私有字段_i
	_str = "", 				-- 定义string型私有字段_str
	_b = false,				-- 定义boolean型私有字段_b
	_x = typesys.XXX,		-- 定义类型为A的私有字段_x，此字段将强引用A类型对象，其生命周期由_x托管
	weak__x1 = typesys.XXX,   -- 定义类型为A的私有字段_x1，此字段将弱引用A类型对象，弱引用字段使用weak_前缀，请注意：字段名是不包含weak_前缀的

	c = typesys.__unmanaged,-- 定义非托管的字段c
}

function XXX:__ctor(...) print("XXX.ctor", ...) end -- 类实例化对象的构造函数，创建或重用时被调用
function XXX:__dtor(...) print("XXX.dtor", ...) end -- 类实例化对象的析构函数，销毁或回收时被调用

function XXX:foo(...) print("foo", ...) end 	-- 自定义实例化对象的函数

local obj = new(XXX)
obj:foo("hello")
delete(obj)