package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

XXX = typesys.def.XXX{
	y = typesys.YYY	-- 错误：没有这个类型
}