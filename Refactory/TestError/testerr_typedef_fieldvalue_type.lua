package.path = package.path ..';../?.lua'
require("TypeSystemHeader")

XXX = typesys.def.XXX{
	a = {},				-- 错误：不支持table类型的fieldvalue
	b = function()end,	-- 错误：不支持function类型的fieldvalue
}
