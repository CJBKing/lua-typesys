
package.path = package.path ..';../?.lua'
require("TypeSystemHeader")
require("ExternalSample")

local new = typesys.new
local delete = typesys.delete

------- [代码区段开始] 测试脚本 --------->
local v2 = new(Vector2, 1, 2)
local v3 = new(Vector3, 1, 2, 3)

print()

print(v2.x, v2.y)
print(v3.x, v3.y, v3.z)

print()

delete(v2)
v2 = nil
delete(v3)
v3 = nil
------- [代码区段结束] 测试脚本 ---------<




