package.path = package.path ..';../?.lua'
require("TypeSystemHeader")
require("ExternalSample")

local new = typesys.new
local delete = typesys.delete

local Array = typesys.array
local Map = typesys.map

Transform = typesys.Transform {
	position = Vector3,
	angles = Vector3,
	scale = Vector3
}

function Transform:ctor()
end

function Transform:dtor()
end

------------

collectgarbage("collect")
local mem1 = collectgarbage("count")

local array = {}
for i=1, 1000 do
	local e = new(Transform)
	e.position = new(Vector3,i,i,i)
	e.angles = new(Vector3,i,i,i)
	e.scale = new(Vector3,i,i,i)
	array[i] = e
end

collectgarbage("collect")
local mem2 = collectgarbage("count")

print(string.format("mem1: %s", tostring(mem1)))
print(string.format("mem2: %s", tostring(mem2)))
print(string.format("cost: %s", tostring(mem2-mem1)))