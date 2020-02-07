
package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

typesys.eventHandler = function(event, args)
	if typesys.EVENT_DEFINE == event then
		print("<事件|定义类型>：", args._type_name)
	elseif typesys.EVENT_NEW == event then
		print("<事件|创建实例对象>：", string.format("[%s]:%d", args._type_name, args._id))
	elseif typesys.EVENT_DELETE == event then
		print("<事件|重用实例对象>：", string.format("[%s]:%d", args._type_name, args._id))
	elseif typesys.EVENT_REUSE == event then
		print("<事件|重用实例对象>：", string.format("[%s]:%d", args._type_name, args._id))
	elseif typesys.EVENT_RECYCLE == event then
		print("<事件|回收实例对象>：", string.format("[%s]:%d", args._type_name, args._id))
	elseif typesys.EVENT_REGISTER_EXTERNAL == event then
		print("<事件|注册外部类型>：", args._type_name or "[no name]")
	elseif typesys.EVENT_NEW_EXTERNAL == event then
		print("<事件|创建外部对象>：", string.format("[%s]:%d", args._type_name or "[no name]", args._id))
	elseif typesys.EVENT_DELETE_EXTERNAL == event then
		print("<事件|销毁外部对象>：", string.format("[%s]:%d", args._type_name or "[no name]", args._id))
	elseif typesys.EVENT_REUSE_EXTERNAL == event then
		print("<事件|重用外部对象>：", string.format("[%s]:%d", args._type_name or "[no name]" or "[no name]", args._id))
	elseif typesys.EVENT_RECYCLE_EXTERNAL == event then
		print("<事件|回收外部对象>：", string.format("[%s]:%d", args._type_name or "[no name]", args._id))	
	end
end

local new = typesys.new
local delete = typesys.delete

local PersonData = typesys.PersonData {
	__pool_capacity = -1,
	__strong_pool = true,
	name = "<unnamed>",
	age = 0,
	dead = false,
}

local Person = typesys.Person {
	__pool_capacity = -1,
	__strong_pool = true,
	data = typesys.PersonData,
	weak_partner = typesys.Person,
}

function Person:logFunc(func_name, ... )
	print(string.format("Person[%s]:%s", self.data.name, func_name), ...)
end

function Person:ctor(name, age)
	local data = new(PersonData)
	self.data = data

	data.name = name
	data.age = age
	data.dead = false
	self:logFunc("ctor", data.age)
end

function Person:dtor()
	self:logFunc("dtor")
end

function Person:getName()
	return self.data.name
end

function Person:growUp()
	local data = self.data
	data.age = data.age + 1
	self:logFunc("growUp", data.age)
end

function Person:marry(other)
	self.partner = other
	other.partner = self
	self:logFunc("marry", other:getName())
end

function Person:die()
	local data = self.data
	data.dead = true
	self:logFunc("die", data.age)
end

local Male = typesys.Male {
	__pool_capacity = -1,
	__strong_pool = true,
	__super = typesys.Person,
}

function Male:marry(other)
	print("Male override function marry")
	self.__super.marry(self, other)
end

local Female = typesys.Female {
	__pool_capacity = -1,
	__strong_pool = true,
	__super = typesys.Person,
}

------- [代码区段开始] 测试脚本 --------->
local p1 = new(Male, "小明", 0)
local p2 = new(Female, "小红", 0)
print("")

for i=1, 20 do
	p1:growUp()
	p2:growUp()
end
print("")

p1:marry(p2)
print("")

for i=1, 10 do
	p1:growUp()
	p2:growUp()
end
print("")

p1:die()
p2:die()
print("")

delete(p1)
p1 = nil
delete(p2)
p2 = nil
------- [代码区段结束] 测试脚本 ---------<




