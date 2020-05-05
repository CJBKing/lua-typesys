package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

local new = typesys.new
local delete = typesys.delete

local a = new(typesys.map, type(0), type(""))
a:get("a")			-- 错误：map键类型为number，不能用string
a:set("a", "abc")	-- 错误：map键类型为number，不能用string
a = nil


