package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

XXX = typesys.def.XXX{
	[1] = 0,	-- 错误：不支持非string类型的fieldname
}
