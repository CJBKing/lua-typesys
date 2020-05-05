package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

XXX = typesys.def.XXX{}
YYY = typesys.def.XXX{}	-- 错误：重复定义名为XXX的类型