
--[[

定义一个类型：
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

function XXX:_ctor(...) end -- 类实例化对象的构造函数，创建或重用时被调用
function XXX:_dtor(...) end -- 类实例化对象的析构函数，销毁或回收时被调用

function XXX:foo(...) end 	-- 自定义实例化对象的函数

实例化对象访问自身的类型：
self._type

调用父类函数：
XXX.__super._ctor(self, ...)
XXX.__super._dtor(self, ...)
XXX.__super.foo(self, ...)
或
self._type.__super._ctor(self, ...)
self._type.__super._dtor(self, ...)
self._type.__super.foo(self, ...)

注意：
__双下划线前缀由系统保留，自定义请勿使用
_下划线前水为私有字段，私有字段，私有函数，只能由实例化对象自身进行调用

--]]

local assert = assert
local print = print

typesys = {__unmanaged = {}}

-- 各类metatable
local _weak_pool_mt = {__mode = "kv"} 	-- 用于弱引用的对象池
local _type_def_mt = {} 				-- 用于类型定义语法糖
local _type_mt = {} 					-- 用于类型
local _obj_mt = {} 						-- 用于实例对象

-- 系统用到的辅助table
local _type_info_map = {} -- 类型信息映射表，type为键，info为值

local function _copyTable(to, from)
	for k, v in pairs(from) do
		to[k] = v
	end
end
local function _getTypeName(t)
	return t.__type_name
end

_type_mt.__index = function(t, k)
	return rawget(t, k)
end

_type_mt.__newindex = function(t, k, v)
	return rawset(t, k, v)
end

-- 类型定义语法糖，用于实现typesys.XXX {}语法
-- 此语法可以将{}作为proto传递给__call函数
_type_def_mt.__call = function(t, proto)
	assert(nil == _type_info_map[t], "<类型定义错误> 重复定义类型：".._getTypeName(t))

	print("\n------定义类型开始：", _getTypeName(t), "--------")

	local info = {
		pool_capacity = -1,
		strong_pool = false,
		super = nil,
		pool = {}, -- 对象池
		-- 各类型字段查询表
		num = {},
		str = {},
		bool = {},
		ref = {},
		w_ref = {},
		unmanaged = {},
	}

	if nil ~= proto.__super then
		local super = proto.__super
		info.super = super
		local super_info = _type_info_map[super]
		assert(nil ~= super_info, "<类型定义错误> 父类未定义")

		-- 将父类的字段查询表拷贝过来
		_copyTable(info.num, super_info.num)
		_copyTable(info.str, super_info.str)
		_copyTable(info.bool, super_info.bool)
		_copyTable(info.ref, super_info.ref)
		_copyTable(info.w_ref, super_info.w_ref)
		_copyTable(info.unmanaged, super_info.unmanaged)

		t.__super = super
		local mt = {}
		_copyTable(mt, _type_mt)
		mt.__index = super
		setmetatable(t, mt)
	else
		setmetatable(t, _type_mt)
	end

	-- 解析协议
	for field_name, v in pairs(proto) do
		assert(type(field_name) == "string", "<类型定义错误> 字段名不是字符串类型")

		if "__pool_capacity" == field_name then
			assert("number" == type(v), "<类型定义错误> __pool_capacity的值不是number类型")
			print("对象池容量：", v)
			info.pool_capacity = v
		elseif "__strong_pool" == field_name then
			assert("boolean" == type(v), "<类型定义错误> __strong_pool的值不是boolean类型")
			print("对象池是否使用强引用：", v)
			info.strong_pool = v
		elseif "__super" == field_name then
		else
			assert("__" ~= string.sub(field_name, 1, 2), "<类型定义错误> “__”为系统保留前缀，不允许使用："..field_name)
			if typesys.__unmanaged == v then
				print("非托管字段：", field_name)
				info.unmanaged[field_name] = false -- false作为slot占位
			else
				local vt = type(v)
				if "number" == vt then
					info.num[field_name] = v
					print("number类型字段：", field_name, "缺省值：", v)
				elseif "string" == vt then
					info.str[field_name] = v
					print("string类型字段：", field_name, "缺省值：", v)
				elseif "boolean" == vt  then
					info.bool[field_name] = v
					print("boolean类型字段：", field_name, "缺省值：", v)
				elseif vt == "table" and nil ~= typesys[_getTypeName(v)] then
					-- 引用类型
					local weak_field_name = field_name:match("^weak_(.+)")
					if weak_field_name then
						assert(nil == proto[weak_field_name], "<类型定义错误> 弱引用字段与其他字段重名："..field_name)
						
						field_name = weak_field_name
						info.w_ref[field_name] = v
						print("弱引用类型字段：", field_name, "=", _getTypeName(v))
					else
						assert(nil == info.w_ref[field_name], "<类型定义错误> 强引用字段与弱引用字段重名："..field_name)
						info.ref[field_name] = v
						print("强引用类型字段：", field_name, "=", _getTypeName(v))
					end
				else
					assert(false, "<类型定义错误> 字段值类型错误："..field_name)
				end
			end
		end
	end

	if not info.strong_pool then
		setmetatable(info.pool, weak_pool_mt)
	end

	-- 将类型信息放入到映射表中
	_type_info_map[t] = info

	print("------类型定义结束：", _getTypeName(t), "--------\n")
	return t
end

-- 类型定义语法糖，用于实现typesys.XXX语法
-- 此语法可以将XXX作为name传递给__index函数，而t就是typesys
setmetatable(typesys, {
	__index = function(t, name)
		assert(nil == rawget(t, name), "<类型定义错误> 类型名已存在："..name)
		local new_t = setmetatable({
			__type_name = name
		}, _type_def_mt)
		rawset(t, name, new_t)
		return new_t
	end
})