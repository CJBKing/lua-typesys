
package.path = package.path ..';../?.lua'
require("TypeSystemHeader")
require("BonusBox")
require("SpecialBonusBox")
require("io")
require("os")

local new = typesys.new
local delete = typesys.delete
local gc = typesys.gc
local setRootObject = typesys.setRootObject
local randomseed = math.randomseed
local random = math.random
local floor = math.floor
local s_format = string.format
local io_read = io.read
local os_time = os.time

local function _waitOpt()
	while true do
		local opt = io_read("*line")
		opt = tonumber(opt)
		if 1 == opt or 2 == opt then
			print("-------------------------------")
			return opt
		end
		print("你的选择超出了我的认知！要么1，要么2")
	end
end

local function _waitNumber()
	while true do
		local n = io_read("*line")
		n = tonumber(n)
		if nil ~= n and 0 < n then
			print("-------------------------------")
			return n
		end
		print("你得给出一个合理的数字！比0大的那种")
	end
end

Game = typesys.def.Game {
	_space = typesys.array,
	_pos = 1,
	_goal_bonus = 0,
	_rest_chance = 0,
	_opened_pos_map = typesys.map, -- pos -> bonus
	exit = false,
}

function Game:__ctor(space_size, start_pos, goal_bonus, chance)
	local special_num = random(space_size)
	local goal_pos = random(space_size)

	local bonus_block = floor(goal_bonus / goal_pos)

	local space = new(typesys.array, BonusBox)
	for i=1, space_size do
		local bonus
		if goal_pos == i then
			bonus = goal_bonus
		else
			bonus = random((i-1)*bonus_block, i*bonus_block)
		end
		if i == special_num then
			space[i] = new(SpecialBonusBox, bonus, random(chance))
		else
			space[i] = new(BonusBox, bonus)
		end
	end

	self._space = space
	self._pos = start_pos
	self._goal_bonus = goal_bonus
	self._rest_chance = chance
	self._opened_pos_map = new(typesys.map, type(0), type(0))

	self:_start()
end

function Game:_start()
	print("勇敢的冒险者，你好！")
	print(s_format("在你的面前有%d个宝箱，每个宝箱里都有带编号的宝物", #self._space))
	print(s_format("你的国王请求你帮他找到编号为%d的宝物", self._goal_bonus))
	print("你要接受这份委托，获得荣耀吗？")
	print("\n1：当然，作为一个冒险者，荣耀之于我就是生命！\n2：不了，我是懦夫，不想冒险！")
	
	local opt = _waitOpt()
	while 1 ~= opt do
		print("懦夫，你要接受这份委托，获得荣耀吗？")
		print("\n1：当然，作为一个冒险者，荣耀之于我就是生命！\n2：不了，我是懦夫，不想冒险！")
		opt = _waitOpt()
	end
	print("\n哈哈，我果然没有看走眼，你是一位真正的勇士！\n那么，让我来祝你一臂之力吧。。。\n\n<<<一股神秘的力量将宝箱按照从小到大排列起来了！>>>\n")
end

function Game:loop()
	if self.exit then
		return false
	end

	if not self:_checkChance() then
		self.exit = true
		return false
	end

	if self:_tryOpen() then
		self.exit = true
		return false
	end

	self:_tryMove()
	return true
end

function Game:_checkChance()
	if 0 >= self._rest_chance then
		print("可怜的冒险者啊，你已经没有机会了，这一路的艰辛终究还是一无所获！\n可能，这就是人生吧！\n再见！")
		return false
	end
	return true
end

function Game:_tryOpen()
	print(s_format("你当前所处位置是%d，还有%d次机会打开宝箱，你要用掉1次机会打开当前位置的宝箱吗？", self._pos, self._rest_chance))
	print("1：当然，逢宝必开才是冒险者！（大无畏）\n2：不了，我还想到处逛逛！（有点怂）")
	local opt = _waitOpt()

	if 1 == opt then
		self._rest_chance = self._rest_chance - 1
		local box = self._space[self._pos]
		local bonus, open_times = box:open()
		if 1 < open_times then
			print(s_format("这好像是我之前开过的宝箱，%d这个数字我有印象", bonus))
			if 0 < self._rest_chance then
				if 1 == self._rest_chance then
					print("啊啊啊！！！我简直愚蠢，这下只剩最后一次机会了！")
				else
					print(s_format("哎~ 浪费了一次机会，还剩%d次！", self._rest_chance))
				end
			end
			print("让我检查一下之前开过哪些宝箱吧：")
			for pos, bonus in pairs(self._opened_pos_map) do
				print(s_format("放在%d号位置的宝箱，宝物编号是：%d", pos, bonus))
			end
			return false
		end

		self._opened_pos_map:set(self._pos, bonus)
		if bonus == self._goal_bonus then
			print(s_format("恭喜你，勇敢的冒险者，你不辱使命，找到了宝物%d，获得了荣耀！", self._goal_bonus))
			return true
		else
			print(s_format("很遗憾，%d并不是你要找的宝物%d", bonus, self._goal_bonus))
			local chance = box:getChance()
			if 0 < chance then
				self._rest_chance = self._rest_chance + chance
				print("。。。。。。\n等等，宝箱中里还藏有另外一个东西\n。。。。。。")
				print(s_format("哇！！！意外收获，你获得了额外的%d次机会，还可以再开%d个宝箱！", chance, self._rest_chance))
			elseif 0 < self._rest_chance then
				if 1 == self._rest_chance then
					print("小心为上，你只剩下最后一次机会了！")
				else
					print(s_format("别气馁，你还有%d次机会呢~", self._rest_chance))
				end
			end
		end
	end
	return false
end

function Game:_tryMove()
	if 0 >= self._rest_chance then
		return
	end

	print(s_format("\n你当前所处位置是%d，你要往前还是往后移动？", self._pos))
	print("1：勇往直前！\n2：以退为进！")
	local dir = _waitOpt()
	print("移动几步？")
	local steps = _waitNumber()

	if 1 == dir then
		local max_steps = #self._space - self._pos
		if max_steps < steps then
			steps = max_steps
			if 0 < steps then
				print(s_format("\n<<<一股神秘的力量只让你前进了%d步>>>\n", steps))
			else
				print("\n<<<一股神秘的力量导致你原地不动>>>\n")
			end
			self._pos = #self._space
		else
			self._pos = self._pos + steps
		end
	elseif 2 == dir then
		if self._pos <= steps then
			steps = self._pos - 1
			if 0 < steps then
				print(s_format("\n<<<一股神秘的力量只让你退后了%d步>>>\n", steps))
			else
				print("\n<<<一股神秘的力量导致你原地不动>>>\n")
			end
			self._pos = 1
		else
			self._pos = self._pos - steps
		end
	end
end

----------------------

local seed = tostring(os_time()):reverse():sub(1, 7)
randomseed(seed)
print("冒险者："..seed)

local sapce_size = 20
local goal_bonus = 9527
local chance = 3
local game = new(Game, sapce_size, random(sapce_size), goal_bonus, chance)
setRootObject(game) -- 非常重要：game对象不会被gc掉
while game:loop() do gc() end
game = nil

