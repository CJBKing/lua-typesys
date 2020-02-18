
-- 打开此开关，系统将会输出日志
local _DEBUG_ON = false

local print = _DEBUG_ON and print or function() end
local assert = assert

-- 对于外部类型（不使用typesys的“类型”），可能不存在_type_name字段，那么日志中将会使用这个字符串代替
local NO_NAME = "[no name]"

-------------

local INVALID_ID = 0
local last_id = INVALID_ID -- 用于生成id的记录变量
local type_info = {} -- 类型信息映射表，type为键，info为值
local alive_objects = {} -- 存活的实例对象映射表，id为键，obj为值

local weak_pool_mt = {__mode = "kv"} -- 用于弱引用的对象池的metatable
local type_def_mt = {} -- 类型定义的metatable
local type_mt = {} -- 类型的metatable
local obj_mt = {} -- 实例对象的metatable


local EVENT_DEFINE = 1              -- 事件：定义类型
local EVENT_NEW = 2					-- 事件：创建实例对象
local EVENT_DELETE = 3				-- 事件：销毁实例对象
local EVENT_REUSE = 4				-- 事件：重用实例对象
local EVENT_RECYCLE = 5				-- 事件：回收实例对象
local EVENT_REGISTER_EXTERNAL = 11	-- 事件：注册外部类型
local EVENT_NEW_EXTERNAL = 12		-- 事件：创建外部对象
local EVENT_DELETE_EXTERNAL = 13	-- 事件：销毁外部对象
local EVENT_REUSE_EXTERNAL = 14		-- 事件：重用外部对象
local EVENT_RECYCLE_EXTERNAL = 15	-- 事件：回收外部对象

------- [代码区段开始] 外部类型 --------->
--[[
-- 外部类型的定义协议
external_proto = {
	pool_capacity = -1, -- 对象池容量，负数为无限
	strong_pool = false, -- 对象池是否使用强引用
	new = function(t, id, ...) end -- new函数，创建并返回一个实例对象，...是构造参数，注意与onReuse区分
	delete = function(t, obj) end -- delete函数，销毁一个实例对象，注意与onRecycle区分
	onReuse = function(t, obj, ...) end -- 当对象被重用时被调用，...是构造参数，注意与new区分
	onRecycle = function(t, obj) end -- 当对象被回收时被调用，注意与delete区分
	setID = function(t, obj, id) end -- 设置对象ID
	getID = function(t, obj) end -- 获取对象ID
}
由于typesys不入侵外部类型对象，所以要求外部类型的定义协议提供typesys所需的各类函数
typesys会根据管理逻辑对其进行调用，各函数根据语义自行实现即可
--]]
-- 警告：外部类型实例对象不允许持有typesys的实例对象！！！typesys实例对象生命周期管理是封闭且独立的！！！
-- typesys的实例对象可以通过强引用或弱引用的方式持有外部类型实例对象

local external_objects = {} -- 外部类型映射表，外部obj为键，外部type为值
local external_owners = {} -- 外部对象持有者（typesys的实例对象）映射表，外部obj为键，owner为obj,true或者nil

-- 通过外部类型，类型信息，以及构造参数，创建外部类型的实例化对象
local function _newExternal(t, info, ...)

	-- 生成实例ID
	local id = last_id + 1
	last_id = id

	local obj
	local pool = info.pool
	local n = #pool
	if n > 0 then
		-- 从对象池中取出一个对象进行重用
		obj = pool[n]
		pool[n] = nil

		info.setID(t, obj, id)
		info.onReuse(t, obj, ...)

		print("reuse external type:", t._type_name or NO_NAME)
		typesys.eventHandler(EVENT_REUSE_EXTERNAL, obj)
	else
		-- 创建一个新的对象
		obj = info.new(t, id, ...)

		print("new external type:", t._type_name or NO_NAME)
		typesys.eventHandler(EVENT_NEW_EXTERNAL, obj)
	end

	-- 将对象注册到映射表中
	alive_objects[id] = obj
	external_objects[obj] = t

	return obj
end

-- 销毁外部类型的实例化对象
local function _deleteExternal(obj, t, info)
	assert(nil ~= external_objects[obj])

	-- 将对象从映射表中移除
	alive_objects[info.getID(t, obj)] = nil
	external_objects[obj] = nil

	local pool = info.pool
	local pool_size = #pool
	local pool_capacity = info.pool_capacity
	if 0 > pool_capacity or 0 ~= pool_capacity and pool_size < pool_capacity then
		-- 将对象回收并放入到对象池当中
		print("recycle external type:", t._type_name or NO_NAME, info.getID(t, obj))
		typesys.eventHandler(EVENT_RECYCLE_EXTERNAL, obj)
		info.onRecycle(t, obj)
		pool[pool_size+1] = obj
	else
		-- 销毁对象
		print("delete external type:", t._type_name or NO_NAME, info.getID(t, obj))
		typesys.eventHandler(EVENT_DELETE_EXTERNAL, obj)
		info.delete(t, obj)
	end

	info.setID(t, obj, 0)
end

-- 向typesys注册一个外部类型，需要提供类型t和类型定义协议proto
local function regExternal(t, proto)
	if nil ~= type_info[t] then
		-- 不可以重复注册
		error("reregister external type: ", t._type_name or NO_NAME)
	end
	-- typesys逻辑所需的各类函数必须要在协议中提供
	assert(nil ~= proto.new and type(proto.new) == "function")
	assert(nil ~= proto.delete and type(proto.delete) == "function")
	assert(nil ~= proto.onReuse and type(proto.onReuse) == "function")
	assert(nil ~= proto.onRecycle and type(proto.onRecycle) == "function")
	assert(nil ~= proto.setID and type(proto.setID) == "function")
	assert(nil ~= proto.getID and type(proto.getID) == "function")

	print("\n------register external type:", t._type_name or NO_NAME, "begin--------")

	-- 构建类型信息
	local info = {
		pool_capacity = proto.pool_capacity or -1,
		strong_pool = proto.strong_pool or false,
		pool = {}, -- 对象池
		external_type = true, -- 标记为外部类型
		-- typesys需要使用的函数
		new = proto.new,
		delete = proto.delete,
		onReuse = proto.onReuse,
		onRecycle = proto.onRecycle,
		setID = proto.setID,
		getID = proto.getID
	}

	if not info.strong_pool then
		setmetatable(info.pool, weak_pool_mt)
	end

	-- 将类型信息放入到映射表中
	type_info[t] = info

	print("------register external type:", t._type_name or NO_NAME, "end--------\n")
	typesys.eventHandler(EVENT_REGISTER_EXTERNAL, t)
end

------- [代码区段结束] 外部类型 ---------<




------- [代码区段开始] 对象操作相关接口 --------->
-- 将对象标记为被持有状态
local function _objSetOwner(obj, t, owner)
	if nil == owner then
		-- 如果不知道被持有者（容器类型实现会用到），那么使用true占位
		owner = true
	end
	local info = type_info[t]
	if info.external_type then
		external_owners[obj] = true
	else
		obj._owner = true
	end
end

-- 将对象标记为不被持有状态
local function _objBreakOwner(obj, t)
	local info = type_info[t]
	if info.external_type then
		external_owners[obj] = nil
	else
		obj._owner = false
	end
end

-- 判断对象是否被持有
local function _objHasOwner(obj)
	return obj._owner or nil ~= external_owners[obj]
end

-- 判断类型和类型是否匹配
local function _typeIsType(t1, t2)
	local info = type_info[t1]
	if info.external_type then
		return t1 == t2
	else
		local t = t1
		while nil ~= t do
			if t == t2 then
				return true
			end
			t = t.__super
		end
		return false
	end
end

-- 判断对象和类型是否匹配
local function _objIsType(obj, t)
	local info = type_info[t]
	if info.external_type then
		return external_objects[obj] == t
	else
		return _typeIsType(obj._type, t)
	end
end

-- 尝试为强引用字段赋值，返回成功与否
local function _objTryAssignStrongRef(obj, k, v, info)
	-- 获取字段的引用类型
	local rt = info.ref[k]
	if nil == rt then
		return false
	end

	if nil ~= v then
		assert(not _objHasOwner(v)) -- 值当前不能是正在被持有状态
		assert(_objIsType(v, rt)) -- 值与字段类型要匹配
		_objSetOwner(v, rt, obj)
	else
		-- 如果赋值为nil，那么使用false作为占位值
		v = false
	end

	local old = obj._refs[k]
	obj._refs[k] = v

	if old then
		-- 移除被持有标记
		_objBreakOwner(old, rt)
		-- 销毁原持有的对象
		typesys.delete(old)
	end
	return true
end

-- 尝试为弱引用字段赋值，返回成功与否
local function _objTryAssignWeakRef(obj, k, v, info)
	-- 获取字段的引用类型
	local rt = info.w_ref[k]
	if nil == rt then
		return false
	end

	if nil ~= v then
		assert(_objIsType(v, rt)) -- 值与字段类型要匹配

		-- 弱引用不直接引用对象，仅引用其ID
		local rt_info = type_info[rt]
		if rt_info.external_type then
			v = rt_info.getID(rt, v)
		else
			v = v._id
		end
	else
		-- 如果赋值为nil，那么使用false作为占位值
		v = false
	end
	
	obj._refs[k] = v
	return true
end

-- 给对象字段赋值
local function _objFieldAssign(obj, k, v)
	local t = obj._type
	assert(nil ~= t)
	local info = type_info[t]
	assert(nil ~= info)

	if nil ~= info.unmanaged[k] then
		-- 不管理的对象，直接赋值
		rawset(obj, k, v)
		return
	end
	if _objTryAssignStrongRef(obj, k, v, info) then
		return
	end
	if _objTryAssignWeakRef(obj, k, v, info) then
		return
	end

	error(string.format("type(%s) field assign failed: %s", t._type_name, tostring(k)))
end

-- 获取对象字段值
local function _objFieldGet(obj, k)
	local t = obj._type
	assert(nil ~= t)

	local tv = t[k]
	if nil ~= tv then
		-- 类型的字段（一般指函数，或静态变量）
		return tv
	end

	local info = type_info[t]
	assert(nil ~= info)

	local ref = info.ref[k]
	if nil ~= ref then
		-- 强引用字段，直接返回引用的对象
		return obj._refs[k] or nil
	end
	ref = info.w_ref[k]
	if nil ~= ref then
		-- 弱引用字段，通过引用的ID查找引用的对象
		local ref_id = obj._refs[k]
		if ref_id then
			return alive_objects[ref_id]
		end
		return nil
	end

	return nil
end

-- [语法糖] 改写对象的点“.”操作，以便处理获取和赋值逻辑（对强、弱引用的包装 ）
obj_mt.__index = _objFieldGet
obj_mt.__newindex = _objFieldAssign
------- [代码区段结束] 对象操作相关接口 ---------<


local function _copyTable(to, from)
	for k, v in pairs(from) do
		to[k] = v
	end
end


--[[
类型定义协议
proto = {
	__pool_capacity = -1, -- 对象池容量，负数为无限
	__strong_pool = false, -- 对象池是否使用强引用
	__super = typesys.xxx, -- 父类，调用父类函数请使用语法 self.__super.yyy(self, ...)，yyy为函数名，...是参数
	xxx = typesys.unmanaged -- typesys不管理字段
	weak_xxx, -- weak ref xxx -- 弱引用字段使用weak_前缀，请注意：字段名是不包含weak_前缀的
}

function XXX:ctor(...) end -- 类实例化对象的构造函数，创建或重用时被调用
function XXX:dtor(...) end -- 类实例化对象的析构函数，销毁或回收时被调用
--]]

-- [语法糖] 可以用typesys.XXX {}语法定义一个类型
type_def_mt.__call = function(t, proto)
	if nil ~= type_info[t] then
		-- 不可以重复定义
		error(string.format("redifined type: %s", t._type_name))
	end

	print("\n------define type:", t._type_name, "begin--------")

	local info = {
		pool_capacity = -1,
		strong_pool = false,
		super = nil, -- 父类
		pool = {}, -- 对象池
		num = {}, -- number类型的字段查询表
		str = {}, -- string类型的字段查询表
		bool = {}, -- boolean类型的字段查询表
		ref = {}, -- 强引用类型的字段查询表
		w_ref = {}, -- 弱引用类型的字段查询表
		unmanaged = {}, -- 不管理类型的字段查询表
	}

	if nil ~= proto.__super then
		local super = proto.__super
		info.super = super
		local super_info = type_info[super]
		assert(nil ~= super_info)

		-- 将父类的字段查询表拷贝过来
		_copyTable(info.num, super_info.num)
		_copyTable(info.str, super_info.str)
		_copyTable(info.bool, super_info.bool)
		_copyTable(info.ref, super_info.ref)
		_copyTable(info.w_ref, super_info.w_ref)
		_copyTable(info.unmanaged, super_info.unmanaged)

		t.__super = super
		setmetatable(t, {__index = super})
	else
		setmetatable(t, type_mt)
	end

	-- 解析协议
	for k,v in pairs(proto) do
		assert(type(k) == "string")
		if "__pool_capacity" == k then
			assert("number" == type(v))
			info.pool_capacity = v
		elseif "__strong_pool" == k then
			assert("boolean" == type(v))
			info.strong_pool = v
		elseif "__super" == k then
			-- ignore
		else
			assert("__" ~= string.sub(k, 1, 2)) -- “__”开始的字段为系统保留字段，不允许使用
			if typesys.unmanaged == v then
				print("unmanaged field:", k)
				info.unmanaged[k] = false
			else
				local vt = type(v)
				if "number" == vt then
					info.num[k] = v
					print("number:", k, "=", v)
				elseif "string" == vt then
					info.str[k] = v
					print("string:", k, "=", v)
				elseif "boolean" == vt  then
					info.bool[k] = v
					print("boolean:", k, "=", v)
				elseif vt == "table" and (nil ~= type_info[v] or getmetatable(v) == type_mt) then
					local field_name = k:match("^weak_(.+)")
					if field_name then
						k = field_name
						assert(nil == info.ref[k]) -- 强弱引用不可重名
						info.w_ref[k] = v
						print("weak reference:", k, "=", v._type_name)
					else
						assert(nil == info.w_ref[k]) -- 强弱引用不可重名
						info.ref[k] = v
						print("strong reference:", k, "=", v._type_name)
					end
				else
					error(string.format("Invalid field %s with type %s", k, vt))
				end
			end
		end
	end

	if not info.strong_pool then
		setmetatable(info.pool, weak_pool_mt)
	end

	-- 将类型信息放入到映射表中
	type_info[t] = info

	print("------define type:", t._type_name, "end--------\n")
	typesys.eventHandler(EVENT_DEFINE, t)
	return t
end

-- [语法糖] 可以用typesys.XXX {}语法定义一个类型
typesys = {}
typesys.unmanaged = {} -- 用于标记typesys不管理字段（容器类型实现会用到）

local function getObjectByID(id)  
	return alive_objects[id]
end

local function getType(obj)
	local t = external_objects[obj]
	if nil ~= t then
		return t
	end
	return obj._type
end

local function getTypeName(objOrType)
	local t = external_objects[objOrType]
	if nil ~= t then
		return t._type_name or NO_NAME
	end
	return objOrType._type_name
end

local function checkType(t)
	return nil ~= type_info[t]
end

local function objIsType(obj, t)
	return _objIsType(obj, t)
end

local function typeIsType(t1, t2)
	return _typeIsType(t1, t2)
end

local function setOwner(obj)
	_objSetOwner(obj, getType(obj))
end

local function clearOwner(obj)
	_objBreakOwner(obj, getType(obj))
end

local function hasOwner(obj)
	return _objHasOwner(obj)
end

local function new(t, ...)
	local info = type_info[t]
	assert(nil ~= info)

	if info.external_type then
		-- 外部类型实例化
		return _newExternal(t, info, ...)
	end

	local obj
	local pool = info.pool
	local n = #pool
	local reuse = 0 < n
	if reuse then
		-- 从对象池中取出一个对象进行重用
		obj = pool[n]
		pool[n] = nil
		print("reuse", t._type_name)
	else
		-- 创建一个新的对象
		local refs = nil
		if nil ~= next(info.ref) or nil ~= next(info.w_ref) then
			-- 创建引用表，用于放置被引用的字段对象，默认用false占位
			refs = {}
			for k in pairs(info.ref) do
				refs[k] = false
			end
			for k in pairs(info.w_ref) do
				refs[k] = false
			end
		end
		obj = {_type = t, _refs = refs, _owner = false}
		print("new", t._type_name)
	end

	-- 生成实例ID
	local id = last_id + 1
	last_id = id

	obj._id = id

	-- 将值类型字段直接放置到对象上
	for k,v in pairs(info.num) do
		obj[k] = v
	end
	for k,v in pairs(info.str) do
		obj[k] = v
	end
	for k,v in pairs(info.bool) do
		obj[k] = v
	end

	-- 启动截获对象索引访问
	setmetatable(obj, obj_mt)

	-- 将对象放入映射表中
	alive_objects[id] = obj

	-- 调用对象的构造函数
	if nil ~= obj.ctor then
		obj:ctor(...)
	end

	if reuse then
		typesys.eventHandler(EVENT_REUSE, obj)
	else
		typesys.eventHandler(EVENT_NEW, obj)
	end
	return obj
end

local function delete(obj)
	-- 被持有对象不能被调用销毁
	assert(not _objHasOwner(obj))

	local t = external_objects[obj]
	if nil ~= t then
		-- 销毁外部类型对象
		return _deleteExternal(obj, t, type_info[t])
	end

	-- 不允许重复销毁
	assert(nil ~= alive_objects[obj._id], tostring(obj._type_name)..":"..tostring(obj._id)) -- circular reference will fail
	
	t = obj._type
	assert(nil ~= t)
	local info = type_info[t]
	assert(nil ~= info)

	-- 从映射表中移除
	alive_objects[obj._id] = nil

	-- 调用对象析构函数
	if nil ~= obj.dtor then
		obj:dtor()
	end

	local refs = obj._refs
	if nil ~= refs then
		-- 销毁强应用字段对象
		local ref
		for k, v in pairs(info.ref) do
			ref = refs[k]
			refs[k] = false
			if ref then
				-- 要先去除持有标志
				_objBreakOwner(ref, v)
				typesys.delete(ref)
			end
		end

		-- 清除弱引用字段
		for k in pairs(info.w_ref) do
			refs[k] = false
		end
	end

	local pool = info.pool
	local pool_size = #pool
	local pool_capacity = info.pool_capacity
	if 0 > pool_capacity or 0 ~= pool_capacity and pool_size < pool_capacity then
		-- 将对象回收并放入到对象池当中
		print("recycle", t._type_name, obj._id)
		typesys.eventHandler(EVENT_RECYCLE, obj)
		pool[pool_size+1] = obj
	else
		print("delete", t._type_name, obj._id)
		typesys.eventHandler(EVENT_DELETE, obj)
	end
	obj._id = INVALID_ID

	setmetatable(obj, nil)
end

local temp_pool = {}
local function deleteNoOwnerObjects()
	local temp = nil
	local temp_n = #temp_pool
	if 0 < temp_n then
		-- 从临时table池中取出一个table
		temp = temp_pool[temp_n]
		temp_pool[temp_n] = nil
	else
		-- 创建一个临时table
		temp = {}
	end

	-- 将未被持有对象放入到临时table中
	local i = 1
	for id,obj in pairs(alive_objects) do
		if not _objHasOwner(obj) then
			temp[i] = obj
			i = i+1
		end
	end

	-- 将临时table中的对象逐个销毁
	for i=#temp, 1, -1 do
		delete(temp[i])
		temp[i] = nil
	end

	-- 将临时table放回临时table池中
	temp_pool[#temp_pool+1] = temp
end

typesys.regExternal = regExternal     -- (t, proto) 注册外部类型
typesys.getObjectByID = getObjectByID -- (id) 通过ID获取对象
typesys.getType = getType             -- (obj) 通过对象获取类型
typesys.getTypeName = getTypeName     -- (objOrType) 通过对象获取类型获取类型名
typesys.checkType = checkType         -- (t) 判断是否是typesys的类型或者已注册的外部类型
typesys.objIsType = objIsType		  -- (obj, t) 判断一个对象是否属于某个类型
typesys.typeIsType = typeIsType 	  -- (t1, t2) 判断一个类型是否属于某个类型
typesys.setOwner = setOwner           -- (obj) 标志对象被持有
typesys.clearOwner = clearOwner       -- (obj) 去除对象被持有标志
typesys.hasOwner = hasOwner           -- (obj) 判断对象是否被持有
typesys.new = new          			  -- (t, ...) 创建或重用实例对象
typesys.delete = delete    			  -- (obj) 销毁或回收实例对象
typesys.deleteNoOwnerObjects = deleteNoOwnerObjects -- 销毁所有未被持有的对象 

typesys.INVALID_ID = INVALID_ID
typesys.DEBUG_ON = _DEBUG_ON

-- 系统回收typesys实例对象时，触发delete逻辑
obj_mt.__gc = function(obj)
	delete(obj)
end

------- [代码区段开始] 事件通知 --------->
typesys.EVENT_DEFINE = EVENT_DEFINE              			-- 事件：定义类型(event, t)
typesys.EVENT_NEW = EVENT_NEW								-- 事件：创建实例对象(event, obj)
typesys.EVENT_DELETE = EVENT_DELETE							-- 事件：销毁实例对象(event, obj)
typesys.EVENT_REUSE = EVENT_REUSE							-- 事件：重用实例对象(event, obj)
typesys.EVENT_RECYCLE = EVENT_RECYCLE						-- 事件：回收实例对象(event, obj)
typesys.EVENT_REGISTER_EXTERNAL = EVENT_REGISTER_EXTERNAL	-- 事件：注册外部类型(event, t)
typesys.EVENT_NEW_EXTERNAL = EVENT_NEW_EXTERNAL				-- 事件：创建外部对象(event, obj)
typesys.EVENT_DELETE_EXTERNAL = EVENT_DELETE_EXTERNAL		-- 事件：销毁外部对象(event, obj)
typesys.EVENT_REUSE_EXTERNAL = EVENT_REUSE_EXTERNAL			-- 事件：重用外部对象(event, obj)
typesys.EVENT_RECYCLE_EXTERNAL = EVENT_RECYCLE_EXTERNAL		-- 事件：回收外部对象(event, obj)
typesys.eventHandler = function(event, ...) end -- 需要监控事件则重设此函数即可
------- [代码区段结束] 事件通知 ---------<

-- 启动typesys定义类型的点“.”操作语法
setmetatable(typesys, {
	__index = function(t, name)
		local new_t = setmetatable({
			_type_name = name
		}, type_def_mt)
		t[name] = new_t
		return new_t
	end
})

