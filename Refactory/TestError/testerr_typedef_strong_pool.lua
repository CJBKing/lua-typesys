package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

XXX = typesys.def.XXX{
	__strong_pool = ""	-- 错误：__strong_pool得是boolean类型
}
