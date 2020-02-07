
local function externalSetID(t, obj, id)
	obj._id = id
end

local function externalGetID(t, obj)
	return obj._id
end

local function externalNew(t, id, ...)
	local obj = t.new()
	externalSetID(t, obj, id)
	obj:ctor(...)
	return obj
end

local function externalDelete(t, obj)
	obj:dtor()
end

local function externalOnReuse(t, obj, ...)
	obj:ctor(...)
end

local function externalOnRecycle(t, obj)
	obj:dtor()
end

local external_proto = {
	pool_capacity = -1,
	strong_pool = true,
	new = externalNew,              -- 创建实例对象
	delete = externalDelete,        -- 销毁实例对象
	onReuse = externalOnReuse,      -- 当实例对象被重用时被调用 
	onRecycle = externalOnRecycle,  -- 当实例对象被回收时被调用
	setID = externalSetID,          -- 设置实例对象ID
	getID = externalGetID,          -- 获取实例对象ID
}

------------------------------------

local _logFunc = nil
if typesys.DEBUG_ON then 
	_logFunc = function(type_name, id, func_name, ...) print(string.format("%s[%d]:%s", type_name, id, func_name), ...) end 
else
	_logFunc = function() end
end

------- [代码区段开始] 定义外部类型Vector2 --------->
Vector2 = {_type_name = "Vector2"}
local Vector2_mt = {__index = Vector2}

function Vector2.new()
	return setmetatable({}, Vector2_mt)
end

function Vector2:ctor(x, y)
	self.x = x
	self.y = y
	_logFunc(self._type_name, self._id, "ctor", x, y)
end

function Vector2:dtor( ... )
	_logFunc(self._type_name, self._id, "dtor")
end

typesys.regExternal(Vector2, external_proto)
------- [代码区段结束] 定义外部类型Vector2 ---------<



------- [代码区段开始] 定义外部类型Vector3 --------->
Vector3 = {_type_name = "Vector3"}
local Vector3_mt = {__index = Vector3}

function Vector3.new()
	return setmetatable({}, Vector3_mt)
end

function Vector3:ctor(x, y, z)
	self.x = x
	self.y = y
	self.z = z
	_logFunc(self._type_name, self._id, "ctor", x, y, z)
end

function Vector3:dtor( ... )
	_logFunc(self._type_name, self._id, "dtor")
end

typesys.regExternal(Vector3, external_proto)
------- [代码区段结束] 定义外部类型Vector3 ---------<




