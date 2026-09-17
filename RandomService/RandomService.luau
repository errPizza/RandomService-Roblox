local HttpService = game:GetService("HttpService")

local RandomService = {}

local function CreateGenerator()
	local combined = table.concat({
		tostring(os.time()),
		tostring(os.clock()),
		HttpService:GenerateGUID(false),
		tostring(math.random()),
	}, "|")

	local hash = 2166136261

	for index = 1, #combined do
		hash = bit32.bxor(hash, string.byte(combined, index))

		-- Multiplicación por 16777619 módulo 2^32,
		-- descompuesta para conservar precisión.
		hash = bit32.band(
			hash * 403 + bit32.lshift(hash, 24),
			0xFFFFFFFF
		)
	end

	return Random.new(hash)
end

local generator = CreateGenerator()

-- Devuelve un número mayor o igual que 0 y menor que 1.
function RandomService.NextNumber()
	local value

	repeat
		value = generator:NextNumber()
	until value < 1

	return value
end

return RandomService
