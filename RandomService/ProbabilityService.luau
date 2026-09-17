--[[
    =========================================================

    Entire Logic and Script made by:
    
    err_Pizza ( @err_Lo2sDat4 ) [ Another Game More ST | Developer ]
    
    =========================================================
--]]

local RandomService = require(script:WaitForChild("RandomService"))
local PrizePool = require(script:WaitForChild("PrizePool"))

local function New(options)
	
	options = options or {}
	
	assert(type(options) == "table", "options debe ser una tabla")
	
	local maxRolls = if options.MaxRolls == nil then 10000 else options.MaxRolls
	
	PrizePool.ValidateCount(maxRolls, 1000000)
	
	local random = RandomService.new(options.Seed)
	local service = {}

	service.ToProbability = PrizePool.ToProbability

	function service.MakeNewProb(value, outOf)
		
		local probability = PrizePool.ToProbability(value, outOf)
		
		if probability == 0 then return false end
		if probability == 1 then return true end
		
		return random.NextNumber() < probability
	end

	function service.CreatePool(prizes, poolOptions)
		
		poolOptions = poolOptions or {}
		
		assert(type(poolOptions) == "table", "options debe ser una tabla")
		
		local mode = if poolOptions.Mode == nil then "Percent" else poolOptions.Mode
		
		return PrizePool.Create(prizes, mode, false, random, maxRolls)
	end

	function service.CreateDropPool(prizes)
		
		return PrizePool.Create(prizes, "Percent", true, random, maxRolls)
	end

	function service.SelectPrize(prizes, amount, selectOptions)
		
		return service.CreatePool(prizes, selectOptions):Select(amount, selectOptions)
	end
	
	service.SelecPrize = service.SelectPrize

	function service.RollDrops(prizes)
		
		return service.CreateDropPool(prizes):RollDrops()
	end

	return table.freeze(service)
end

local ProbabilityService = table.clone(New())
ProbabilityService.new = New

return table.freeze(ProbabilityService)
