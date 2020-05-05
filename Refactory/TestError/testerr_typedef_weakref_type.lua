package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

XXX = typesys.def.XXX{
	a = 1,
	weak_b = 0,	-- 错误：弱引用字段b的类型得是typesys.def定义的类型
}