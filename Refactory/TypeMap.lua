
local _CHECK_MODE = true -- 启动强制检查机制，及时发现代码问题，但会有运行性能损耗

local error = error

-------------

local _delete = typesys.delete
local _getObjectByID = typesys.getObjectByID

-- 元素类型的类别
local _ET_TYPE_STRONG_REF = 1 -- 强引用类型
local _ET_TYPE_WEAK_REF = 2 -- 弱引用类型
local _ET_TYPE_NOT_REF = 3 -- 不是类型

local map = typesys.def.map {
	__strong_pool = true,
	_m = typesys.__unmanaged, 	-- 作为容器的table
	_kt = "", 					-- 键类型，只允许type(xxx)
	_et = typesys.__unmanaged, 	-- 元素类型
	_et_type = 0 				-- 元素类型的类别
}

-- 将要放入map的元素使用此函数进行转换
local function _inElement(e, et_type)
	if nil == e then
		return _nil_slot
	elseif _ET_TYPE_WEAK_REF == et_type then
		return e.__id
	end
	return e
end

-- 将要从map中拿出的元素使用此函数进行转换
local function _outElement(e, et_type)
	if _ET_TYPE_WEAK_REF == et_type then
		return _getObjectByID(e)
	end
	return e
end

-- 模拟原生map的语法
local _original_obj_mt = typesys.__getObjMetatable()
local _obj_mt = {}
for k,v in pairs(_original_obj_mt) do
	_obj_mt[k] = v
end
_obj_mt.__pairs = function(obj)
	return obj:pairs()
end

-- 创建一个map，需要指定键类型，元素类型，以及是否使用弱引用方式存放元素（默认不使用）
function map:__ctor(kt, et, weak)
	if "string" ~= type(kt) then
		error("<创建map错误> 键类型不合法，只能是string类型："..type(kt))
	end
	local is_sys_t = typesys.isType(et)
	if not is_sys_t and "string" ~= type(et) then
		error("<创建map错误> 元素类型不合法，要么是typesys定义的类型，要么是string类型："..type(et))
	end
	if not is_sys_t and "table" == et then
		error("<创建数组错误> 不允许创建table类型为元素的数组")
	end

	self._m = self._m or {}
	self._kt = kt
	self._et = et
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

function map:__dtor()
	self:clear()
	setmetatable(self, _original_obj_mt)
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
	e = _inElement(e, self._et_type)

	if _ET_TYPE_STRONG_REF == self._et_type then
		-- 强引用类型，需要对其生命周期进行处理
		local m = self._m
		local old = m[k]
		m[k] = e
		if nil ~= e then
			e.__owner = self.__id
		end
		if nil ~= old then
			old.__owner = false
			_delete(old)
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
	local m = self._m
	if _ET_TYPE_STRONG_REF == self._et_type then
		-- 强引用类型，需要对其生命周期进行处理
		for k, old in pairs(m) do
			m[k] = nil
			if nil ~= old then
				old.__owner = false
				_delete(old)
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
		if nil == e then
			k = nil
		end
	end
	return k, e
end

-- 遍历map
function map:pairs()
	return map._next, self
end

-- 检查键合法性
local function _checkKey(k, kt)
	if nil == k or type(k) ~= kt then
		error(string.format("<map访问错误> 键类型不匹配：键类型是%s, 传入的参数类型却是%s", kt, type(k)))
	end
end
-- 检查元素合法性
local function _checkElement(e, et, et_type)
	if nil == e then
		return
	end
	if _ET_TYPE_STRONG_REF == et_type then
		if not typesys.objIsType(e,  et) then
			error(string.format("<map访问错误> 元素类型不匹配：元素类型是%s, 传入的参数类型却是%s", et.__type_name, e._type.__type_name))
		end
		if e.__owner then
			error("<map访问错误> 元素已经被持有")
		end
	elseif _ET_TYPE_WEAK_REF == et_type then
		if not typesys.objIsType(e,  et) then
			error(string.format("<map访问错误> 元素类型不匹配：元素类型是%s, 传入的参数类型却是%s", et.__type_name, e._type.__type_name))
		end
	else
		if type(e) ~= et then
			error(string.format("<map访问错误> 元素类型不匹配：元素类型是%s, 传入的参数类型却是%s", et, type(e)))
		end
	end
end

if _CHECK_MODE then
	local _containKey = map.containKey
	map.containKey = function(self, k)
		_checkKey(k, self._kt)
		return _containKey(self, k)
	end

	local _set = map.set
	map.set = function(self, k, e)
		_checkKey(k, self._kt)
		_checkElement(e, self._et, self._et_type)
		return _set(self, k, e)
	end

	local _get = map.get
	map.get = function(self, k)
		_checkKey(k, self._kt)
		return _get(self, k)
	end
end