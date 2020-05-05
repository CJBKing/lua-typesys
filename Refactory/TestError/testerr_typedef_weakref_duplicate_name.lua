package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

XXX = typesys.def.XXX{
	a = 1,
	weak_a = typesys.XXX,	-- 错误：弱引用字段a与字段a重名了
}
