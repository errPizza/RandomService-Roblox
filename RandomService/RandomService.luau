local HttpService = game:GetService("HttpService")

local RandomService = {}

local function CreateSeed()
	local combined = table.concat({
		tostring(os.time()),
		tostring(os.clock()),
		HttpService:GenerateGUID(false),
		tostring(math.random()),
	}, "|")
	local hash = 2166136261
	for index = 1, #combined do
		hash = bit32.bxor(hash, string.byte(combined, index))
		-- Multiplicación por 16777619 módulo 2^32 sin perder precisión.
		hash = bit32.band(hash * 403 + bit32.lshift(hash, 24), 0xFFFFFFFF)
	end
	return hash
end

function RandomService.new(seed)
	if seed == nil then
		seed = CreateSeed()
	end
	assert(
		type(seed) == "number" and seed == seed
			and math.abs(seed) <= 9007199254740991 and seed % 1 == 0,
		"Seed debe ser un entero entre -(2^53-1) y 2^53-1"
	)
	local generator = Random.new(seed)
	return table.freeze({
		-- Intervalo [0, 1): evita seleccionar un extremo superior.
		NextNumber = function()
			local value
			repeat
				value = generator:NextNumber()
			until value < 1
			return value
		end,
	})
end

return table.freeze(RandomService)
