
package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

local new = typesys.new
local delete = typesys.delete

------- [代码区段开始] 测试脚本 --------->
local m = new(typesys.map, type(""), type(0))

print()

for i=1, 10 do
	m:set(string.format("test_%d", i), i)
end

print(m:containKey("test_5"))

print()

if not m:isEmpty() then
	for k, v in m:pairs() do
		print(string.format("%s -> %d", k, v))
	end
end

m:clear()

print()

delete(m)
m = nil
------- [代码区段结束] 测试脚本 ---------<




