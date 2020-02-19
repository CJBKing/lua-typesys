
package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

local new = typesys.new
local delete = typesys.delete

------- [代码区段开始] 测试脚本 --------->
local a = new(typesys.array, type(0))

print()

for i=1, 10 do
	a:pushBack(i)
	a:pushFront(i * -1)
end

print()

a:set(2, 101)
a:insert(3, 102)
a:peekBack()
a:peekFront()
a:popFront()
a:popBack()

print()

for i=1, a:size() do
	print(a:get(i))
end

a:clear()

print()

delete(a)
a = nil
------- [代码区段结束] 测试脚本 ---------<




