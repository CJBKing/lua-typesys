package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

XXX = typesys.def.XXX{
	__super = 1,	-- 错误：__super指定的类型不是typesys.def定义的类型
}
