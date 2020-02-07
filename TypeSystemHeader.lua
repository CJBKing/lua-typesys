
require("TypeSystem")
-- require("TypeSystem1")
-- 通过对比实验，使用一个表来存放所有对象的refs的方法在大量对象存在的情况下反而内存占用更高
-- 而且需要拼接唯一的k值，运行时还会产生大量的临时内存开销
-- 综合考虑还是在对象自身内部维护refs表更好
require("TypeArray")
require("TypeMap")