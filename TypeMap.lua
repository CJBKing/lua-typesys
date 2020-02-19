
local _logFunc = nil
if typesys.DEBUG_ON then 
	_logFunc = function(id, func_name, ...) print(string.format("map[%d]:%s", id, func_name), ...) end 
else
	_logFunc = function() end
end
local assert = assert

-------------

local setOwner = typesys.setOwner
local clearOwner = typesys.clearOwner
local hasOwner = typesys.hasOwner
local delete = typesys.delete

-- 元素类型的类别
local _ET_TYPE_STRONG_TYPESYS = 1 -- 强引用typesys类型（包括注册的外部类型）
local _ET_TYPE_WEAK_TYPESYS = 2 -- 弱引用typesys类型（包括注册的外部类型）
local _ET_TYPE_NOT_TYPESYS = 3 -- 不是typesys类型

local _ET_TYPE_NAMES = {"strong_typesys", "weak_typesys", "not_typesys"}

--[[
为了不破坏typesys对类型设置的metatable，typesys.map类型不支持用[]和pairs进行访问
请使用此类型提供的函数接口进行访问
--]]
local map = typesys.map {
	__strong_pool = true,
	_m = typesys.unmanaged, -- 作为容器的table 
	_kt = "", -- 键类型，只允许type(xxx)
	_et = typesys.unmanaged, -- 元素类型
	_et_type = 0 -- 元素类型的类别
}

-- 将要放入map的元素使用此函数进行转换
local function _inElement(e, et_type)
	if nil == e then
		return nil
	elseif _ET_TYPE_WEAK_TYPESYS == et_type then
		return e._id
	end
	return e
end

-- 将要从map中拿出的元素使用此函数进行转换
local function _outElement(e, et_type)
	if _ET_TYPE_WEAK_TYPESYS == et_type then
		return typesys.getObjectByID(e)
	end
	return e
end

-- 创建一个map，需要指定键类型，元素类型，以及是否使用弱引用方式存放元素（默认不使用）
function map:ctor(kt, et, weak)
	assert("string" == type(kt)) -- 键类型只允许是type(xxx)
	local is_sys_t = typesys.checkType(et)
	assert(is_sys_t or "string" == type(et)) -- 类型参数要么是typesys类，要么是type(xxx)

	self._m = self._m or {}
	self._kt = kt
	self._et = et
	if is_sys_t then
		if weak then
			self._et_type = _ET_TYPE_WEAK_TYPESYS
		else
			self._et_type = _ET_TYPE_STRONG_TYPESYS
		end
	else
		self._et_type = _ET_TYPE_NOT_TYPESYS
	end
	_logFunc(self._id, "ctor", kt, is_sys_t and typesys.getTypeName(et) or et, _ET_TYPE_NAMES[self._et_type])
end

function map:dtor()
	self:clear()
	_logFunc(self._id, "dtor")
end

-- 检查键合法性
function map:checkKey(k)
	if nil == k then
		return false
	end
	return type(k) == self._kt
end

-- 检查元素合法性
function map:checkElement(e)
	if nil == e then
		return true
	end
	if _ET_TYPE_STRONG_TYPESYS == self._et_type then
		return typesys.objIsType(e,  self._et) and not hasOwner(e)
	elseif _ET_TYPE_WEAK_TYPESYS == self._et_type then
		return typesys.objIsType(e,  self._et)
	else
		return type(e) == self._et
	end
end

-- 判断键是否存在
function map:containKey(k)
	return nil ~= self:get(k)
end

-- 判断map是否为空（没有元素）
function map:isEmpty()
	local e = next(self._m)
	if nil ~= e then
		e = _outElement(e, self._et_type)
	end
	return nil == e
end

-- 设置键为k的元素e
function map:set(k, e)
	assert(self:checkKey(k))
	assert(self:checkElement(e))

	_logFunc(self._id, "set", k, e)

	e = _inElement(e, self._et_type)

	if _ET_TYPE_STRONG_TYPESYS == self._et_type then
		-- 强引用typesys类型，需要对其生命周期进行处理
		local m = self._m
		local old = m[k]
		m[k] = e
		if nil ~= e then
			setOwner(e) -- 设置被持有标记
		end
		if nil ~= old then
			clearOwner(old) -- 去除被持有标记
			delete(old)
		end
	else
		self._m[k] = e
	end
end

-- 获取键为k的元素
function map:get(k)
	local e = self._m[k]
	if nil == e then
		return nil
	end
	return _outElement(e, self._et_type)
end

-- 清除所有元素
function map:clear()
	_logFunc(self._id, "clear")

	local m = self._m
	if _ET_TYPE_STRONG_TYPESYS == self._et_type then
		-- 强引用typesys类型，需要对其生命周期进行处理
		for k, old in pairs(m) do
			m[k] = nil
			if nil ~= old then
				clearOwner(old) -- 去除被持有标记
				delete(old)
			end
		end
	else
		for k in pairs(m) do
			m[k] = nil
		end
	end
end

-- 供pairs使用
function map:_next(k)
	local k, e = next(self._m, k)
	if nil ~= e then
		e = _outElement(e, self._et_type)
	end
	return k, e
end

-- 遍历map，只能调用此函数来触发
function map:pairs()
	return map._next, self
end

if not typesys.DEBUG_ON then
	map.checkKey = function() return true end
	map.checkElement = function() return true end
end




