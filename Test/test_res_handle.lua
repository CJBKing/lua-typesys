
package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

local _test_go = 0
local function _InstantiateGameObject()
	_test_go = _test_go + 1
	print("_InstantiateGameObject", _test_go)
	return _test_go
end 

local function _destroyGameObject(go)
	print("_destroyGameObject", go)
end 

---------

local GameObjectHandle = typesys.GameObjectHandle {
	_go = typesys.unmanaged, -- GameObject对象
}

function GameObjectHandle:ctor(go)
	self._go = go
end

function GameObjectHandle:dtor()
	_destroyGameObject(self._go)
	self._go = nil
end

local new = typesys.new
local delete = typesys.delete

------- [代码区段开始] 测试脚本 --------->
local go_handle = new(GameObjectHandle, _InstantiateGameObject())

print()

delete(go_handle)
go_handle = nil
------- [代码区段结束] 测试脚本 ---------<




