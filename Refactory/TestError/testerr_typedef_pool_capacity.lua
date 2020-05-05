package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

XXX = typesys.def.XXX{
	__pool_capacity = ""	-- 错误：__pool_capacity得是number类型
}
