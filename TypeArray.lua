

local _logFunc = nil
if typesys.DEBUG_ON then 
	_logFunc = function(id, func_name, ...) print(string.format("array[%d]:%s", id, func_name), ...) end 
else
	_logFunc = function() end
end

local assert = assert

-------------

local setOwner = typesys.setOwner
local clearOwner = typesys.clearOwner
local hasOwner = typesys.hasOwner
local delete = typesys.delete

local nil_slot = {} -- 空元素占位符

-- 元素类型的类别
local _ET_TYPE_STRONG_TYPESYS = 1 -- 强引用typesys类型（包括注册的外部类型）
local _ET_TYPE_WEAK_TYPESYS = 2 -- 弱引用typesys类型（包括注册的外部类型）
local _ET_TYPE_NOT_TYPESYS = 3 -- 不是typesys类型

local _ET_TYPE_NAMES = {"strong_typesys", "weak_typesys", "not_typesys"}

--[[
为了不破坏typesys对类型设置的metatable，typesys.array类型不支持用[]进行访问
请使用此类型提供的函数接口进行访问
--]]
local array = typesys.array {
	__strong_pool = true,
	_a = typesys.unmanaged, -- 作为容器的table
	_et = typesys.unmanaged, -- 元素类型
	_et_type = 0 -- 元素类型的类别
}

-- 将要放入数组的元素使用此函数进行转换
local function _inElement(e, et_type)
	if nil == e then
		return nil_slot
	elseif _ET_TYPE_WEAK_TYPESYS == et_type then
		return e._id
	end
	return e
end

-- 将要从数组中拿出的元素使用此函数进行转换
local function _outElement(e, et_type)
	if nil_slot == e then
		return nil
	elseif _ET_TYPE_WEAK_TYPESYS == et_type then
		return typesys.getObjectByID(e)
	end
	return e
end

-- 创建一个数组，需要指定元素类型，以及是否使用弱引用方式存放元素（默认不使用）
function array:ctor(t, weak)
	local is_sys_t = typesys.checkType(t)
	assert(is_sys_t or "string" == type(t)) -- 类型参数要么是typesys类，要么是type(xxx)

	self._a = self._a or {}
	self._et = t
	if is_sys_t then
		if weak then
			self._et_type = _ET_TYPE_WEAK_TYPESYS
		else
			self._et_type = _ET_TYPE_STRONG_TYPESYS
		end
	else
		self._et_type = _ET_TYPE_NOT_TYPESYS
	end
	_logFunc(self._id, "ctor", is_sys_t and typesys.getTypeName(t) or t, _ET_TYPE_NAMES[self._et_type])
end

function array:dtor()
	self:clear()
	_logFunc(self._id, "dtor")
end

-- 检查元素合法性
function array:checkElement(e)
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

-- 获得元素个数
function array:size()
	return #self._a
end

-- 获取下标为i的元素
function array:get(i)
	assert(0 < i)
	return _outElement(self._a[i], self._et_type)
end

-- 将下标为i的元素设置为e
function array:set(i, e)
	assert(self:checkElement(e))
	local a = self._a
	assert(0 < i and #a >= i) -- 检查下标合法性

	_logFunc(self._id, "set", i, e)

	e = _inElement(e, self._et_type)

	if _ET_TYPE_STRONG_TYPESYS == self._et_type then
		-- 强引用typesys类型，需要对其生命周期进行处理
		local old = a[i]
		a[i] = e
		if nil_slot ~= e then
			setOwner(e) -- 设置被持有标记
		end
		if nil_slot ~= old then
			clearOwner(old) -- 去除被持有标记
			delete(old)
		end
	else
		a[i] = e
	end
end

-- 在下标为i的位置插入一个元素
function array:insert(i, e)
	assert(self:checkElement(e))
	local a = self._a
	assert(0 < i and #a >= i) -- 检查下标合法性

	_logFunc(self._id, "insert", i, e)

	e = _inElement(e, self._et_type)

	table.insert(self._a, i, e)
	
	if nil_slot ~= e and _ET_TYPE_STRONG_TYPESYS == self._et_type then
		-- 如果是强引用typesys类型，则设置被持有标记
		setOwner(e)
	end
end

-- 从数组尾部压入一个元素
function array:pushBack(e)
	assert(self:checkElement(e))

	_logFunc(self._id, "pushBack", e)

	local a = self._a
	e = _inElement(e, self._et_type)
	a[#a+1] = e
	if nil_slot ~= e and _ET_TYPE_STRONG_TYPESYS == self._et_type then
		-- 如果是强引用typesys类型，则设置被持有标记
		setOwner(e) 
	end
end

-- 从数组尾部弹出一个元素，如果数组为空，则弹出nil
function array:popBack()
	_logFunc(self._id, "popBack")

	local a = self._a
	local n = #a
	if 0 < n then
		local e = a[n]
		a[n] = nil -- 取出元素后将其从数组中抹去
		if nil_slot ~= e and _ET_TYPE_STRONG_TYPESYS == self._et_type then
			-- 如果是强引用typesys类型，则去除其被持有的标志
			clearOwner(e)
		end
		return _outElement(e, self._et_type)
	else
		return nil
	end
end

-- 获取数组尾部元素（不会将其弹出），数组为空则返回nil
function array:peekBack()
	_logFunc(self._id, "peekBack")

	local a = self._a
	local n = #a
	if 0 < n then
		return _outElement(a[n], self._et_type)
	else
		return nil
	end
end

-- 从数组头部压入一个元素
function array:pushFront(e)
	_logFunc(self._id, "pushFront", e)

	if nil == e and 0 == #self._a then
		return
	end
	assert(self:checkElement(e))
	
	e = _inElement(e, self._et_type)

	table.insert(self._a, 1, e)

	if nil_slot ~= e and _ET_TYPE_STRONG_TYPESYS == self._et_type then
		-- 如果是强引用typesys类型，则设置被持有标记
		setOwner(e)
	end
end

-- 从数组头部弹出一个元素，如果数组为空，则弹出nil
function array:popFront()
	_logFunc(self._id, "popFront")

	local a = self._a
	if 0 < #a then
		local e = a[1]
		table.remove(a, 1)
		if nil_slot ~= e and _ET_TYPE_STRONG_TYPESYS == self._et_type then
			-- 如果是强引用typesys类型，则去除其被持有的标志
			clearOwner(e)
		end
		return _outElement(e, self._et_type)
	else
		return nil
	end
end

-- 获取数组头部元素（不会将其弹出），数组为空则返回nil
function array:peekFront()
	_logFunc(self._id, "peekFront")

	local a = self._a
	if 0 < #a then
		return _outElement(a[1], self._et_type)
	else
		return nil
	end
end

-- 清除所有元素
function array:clear()
	_logFunc(self._id, "clear")

	local a = self._a

	if _ET_TYPE_STRONG_TYPESYS == self._et_type then
		-- 强引用typesys类型，需要对其生命周期进行处理
		for i=#a, 1, -1 do
			local e = a[i]
			a[i] = nil
			if nil_slot ~= e then
				clearOwner(e) -- 去除被持有标记
				delete(e)
			end
		end
	else
		for i=#a, 1, -1 do
			a[i] = nil
		end
	end
end

if not typesys.DEBUG_ON then
	-- 为了运行时性能，checkElement只在typesys.DEBUG_ON的时候生效
	array.checkElement = function() return true end
end
