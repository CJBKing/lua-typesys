
local _CHECK_MODE = true -- 启动强制检查机制，及时发现代码问题，但会有运行性能损耗

local error = error

-------------

local _delete = typesys.delete
local _getObjectByID = typesys.getObjectByID
local _nil_slot = {} -- 空元素占位符

-- 元素类型的类别
local _ET_TYPE_STRONG_REF = 1 -- 强引用类型
local _ET_TYPE_WEAK_REF = 2 -- 弱引用类型
local _ET_TYPE_NOT_REF = 3 -- 不是类型

local array = typesys.def.array {
	__strong_pool = true,
	_a = typesys.__unmanaged, 	-- 作为容器的table
	_et = typesys.__unmanaged, 	-- 元素类型
	_et_type = 0 				-- 元素类型的类别
}

-- 将要放入数组的元素使用此函数进行转换
local function _inElement(e, et_type)
	if nil == e then
		return _nil_slot
	elseif _ET_TYPE_WEAK_REF == et_type then
		return e.__id
	end
	return e
end

-- 将要从数组中拿出的元素使用此函数进行转换
local function _outElement(e, et_type)
	if _nil_slot == e then
		return nil
	elseif _ET_TYPE_WEAK_REF == et_type then
		return _getObjectByID(e)
	end
	return e
end

-- 数组末尾放入nil元素
local function _trySetLastNil(a, i, e)
	local n = #a
	if nil == e and (n == i or n+1 == i) then
		a[i] = nil
		return true
	end
	return false
end

-- 模拟原生数组的语法
local _original_obj_mt = typesys.__getObjMetatable()
local _obj_mt = {}
for k,v in pairs(_original_obj_mt) do
	_obj_mt[k] = v
end
_obj_mt.__index = function(obj, i)
	if "number" == type(i) then
		return obj:get(i)
	end
	return _original_obj_mt.__index(obj, i)
end
_obj_mt.__newindex = function(obj, i, e)
	if "number" == type(i) then
		return obj:set(i, e)
	end
	return _original_obj_mt.__newindex(obj, i, e)
end
_obj_mt.__len = function(obj)
	return #rawget(obj, "_a")
end

-- 创建一个数组，需要指定元素类型，以及是否使用弱引用方式存放元素（默认不使用）
function array:__ctor(t, weak)
	local is_sys_t = typesys.isType(t)
	if not is_sys_t and "string" ~= type(t) then
		error("<创建数组错误> 元素类型不合法，要么是typesys定义的类型，要么是string类型："..type(t))
	end
	if not is_sys_t and "table" == t then
		error("<创建数组错误> 不允许创建table类型为元素的数组")
	end

	self._a = self._a or {}
	self._et = t
	if is_sys_t then
		if weak then
			self._et_type = _ET_TYPE_WEAK_REF
		else
			self._et_type = _ET_TYPE_STRONG_REF
		end
	else
		self._et_type = _ET_TYPE_NOT_REF
	end

	setmetatable(self, _obj_mt)
end

function array:__dtor()
	self:clear()
	setmetatable(self, _original_obj_mt)
end

-- 获得元素个数
function array:size()
	return #self._a
end

-- 获取下标为i的元素
function array:get(i)
	return _outElement(self._a[i], self._et_type)
end

-- 将下标为i的元素设置为e
function array:set(i, e)
	if _trySetLastNil(self._a, i, e) then
		return
	end
	e = _inElement(e, self._et_type)

	if _ET_TYPE_STRONG_REF == self._et_type then
		-- 强引用类型，需要对其生命周期进行处理
		local old = self._a[i]
		self._a[i] = e
		if _nil_slot ~= e then
			e.__owner = self.__id
		end
		if nil ~= old and _nil_slot ~= old then
			old.__owner = false
			_delete(old)
		end
	else
		self._a[i] = e
	end
end

-- 在下标为i的位置插入一个元素
function array:insert(i, e)
	if _trySetLastNil(self._a, i, e) then
		return
	end
	e = _inElement(e, self._et_type)

	table.insert(self._a, i, e)
	
	if _nil_slot ~= e and _ET_TYPE_STRONG_REF == self._et_type then
		e.__owner = self.__id
	end
end

-- 从数组尾部压入一个元素
function array:pushBack(e)
	if nil == e then
		return
	end

	e = _inElement(e, self._et_type)

	self._a[#self._a+1] = e
	if _nil_slot ~= e and _ET_TYPE_STRONG_REF == self._et_type then
		e.__owner = self.__id
	end
end

-- 从数组尾部弹出一个元素，如果数组为空，则弹出nil
function array:popBack()
	if 0 < #self._a then
		local e = self._a[n]
		self._a[n] = nil -- 取出元素后将其从数组中抹去
		if _nil_slot ~= e and _ET_TYPE_STRONG_REF == self._et_type then
			-- 如果是强引用类型，则去除其被持有的标志
			e.__owner = false
		end
		return _outElement(e, self._et_type)
	else
		return nil
	end
end

-- 获取数组尾部元素（不会将其弹出），数组为空则返回nil
function array:peekBack()
	if 0 < #self._a then
		return _outElement(self._a[n], self._et_type)
	else
		return nil
	end
end

-- 从数组头部压入一个元素
function array:pushFront(e)
	if nil == e and 0 == #self._a then
		return
	end
	
	e = _inElement(e, self._et_type)

	table.insert(self._a, 1, e)

	if _nil_slot ~= e and _ET_TYPE_STRONG_REF == self._et_type then
		-- 如果是强引用类型，则设置被持有标记
		e.__owner = self.__id
	end
end

-- 从数组头部弹出一个元素，如果数组为空，则弹出nil
function array:popFront()
	if 0 < #self._a then
		local e = self._a[1]
		table.remove(self._a, 1)
		if _nil_slot ~= e and _ET_TYPE_STRONG_REF == self._et_type then
			-- 如果是强引用类型，则去除其被持有的标志
			e.__owner = false
		end
		return _outElement(e, self._et_type)
	else
		return nil
	end
end

-- 获取数组头部元素（不会将其弹出），数组为空则返回nil
function array:peekFront()
	if 0 < #self._a then
		return _outElement(self._a[1], self._et_type)
	else
		return nil
	end
end

-- 清除所有元素
function array:clear()
	local a = self._a

	if _ET_TYPE_STRONG_REF == self._et_type then
		-- 强引用类型，需要对其生命周期进行处理
		for i=#a, 1, -1 do
			local e = a[i]
			a[i] = nil
			if _nil_slot ~= e then
				e.__owner = false
				_delete(e)
			end
		end
	else
		for i=#a, 1, -1 do
			a[i] = nil
		end
	end
end

-- 检查元素合法性
local function _checkElement(e, et, et_type)
	if nil == e then
		return
	end
	if _ET_TYPE_STRONG_REF == et_type then
		if not typesys.objIsType(e,  et) then
			error(string.format("<数组访问错误> 元素类型不匹配：元素类型是%s, 传入的参数类型却是%s", et.__type_name, e._type.__type_name))
		end
		if e.__owner then
			error("<数组访问错误> 元素已经被持有")
		end
	elseif _ET_TYPE_WEAK_REF == et_type then
		if not typesys.objIsType(e,  et) then
			error(string.format("<数组访问错误> 元素类型不匹配：元素类型是%s, 传入的参数类型却是%s", et.__type_name, e._type.__type_name))
		end
	else
		if type(e) ~= et then
			error(string.format("<数组访问错误> 元素类型不匹配：元素类型是%s, 传入的参数类型却是%s", et, type(e)))
		end
	end
end

if _CHECK_MODE then
	local _get = array.get
	array.get = function(self, i)
		if 0 >= i or #self._a < i then
			error(string.format("<数组访问错误> 下标越界：数组长度 %d, 下标 %d", #self._a, i))
		end
		return _get(self, i)
	end

	local _set = array.set
	array.set = function(self, i, e)
		if 0 >= i or #self._a+1 < i then
			error(string.format("<数组访问错误> 下标越界：数组长度 %d, 下标 %d", #self._a, i))
		end
		_checkElement(e, self._et, self._et_type)
		return _set(self, i, e)
	end

	local _insert = array.insert
	array.insert = function(self, i, e)
		if 0 >= i or #self._a+1 < i then
			error(string.format("<数组访问错误> 下标越界：数组长度 %d, 下标 %d", #self._a, i))
		end
		_checkElement(e, self._et, self._et_type)
		return _insert(self, i, e)
	end

	local _pushBack = array.pushBack
	array.pushBack = function(self, e)
		_checkElement(e, self._et, self._et_type)
		return _pushBack(self, e)
	end

	local _pushFront = array.pushFront
	array.pushFront = function(self, e)
		_checkElement(e, self._et, self._et_type)
		return _pushFront(self, e)
	end
end