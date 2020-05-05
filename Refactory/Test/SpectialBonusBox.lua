
SpectialBonusBox = typesys.def.SpectialBonusBox {
	__super = BonusBox,
	_chance = 0,
}

function SpectialBonusBox:__ctor(bonus, chance)
	SpectialBonusBox.__super.__ctor(self, bonus)
	self._chance = chance
end

function SpectialBonusBox:getChance()
	return self._chance
end