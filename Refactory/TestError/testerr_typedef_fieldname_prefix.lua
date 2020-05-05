package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

XXX = typesys.def.XXX{
	__a = ""	-- 错误：__前缀是不允许自定义的
}
