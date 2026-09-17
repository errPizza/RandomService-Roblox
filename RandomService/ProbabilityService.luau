local RandomService = require(script:WaitForChild("RandomService"))

local ProbabilityService = {}

local function IsFiniteNumber(value)
	return type(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
end

-- Con un argumento: interpreta un porcentaje.
-- Con dos argumentos: interpreta "value entre outOf".
-- Devuelve una probabilidad entre 0 y 1.
function ProbabilityService.ToProbability(value, outOf)
	assert(
		IsFiniteNumber(value),
		"La probabilidad debe ser un número finito"
	)

	local denominator = outOf

	if denominator == nil then
		denominator = 100
	end

	assert(
		IsFiniteNumber(denominator) and denominator > 0,
		"El denominador debe ser un número finito mayor que 0"
	)

	assert(
		value >= 0 and value <= denominator,
		"La probabilidad debe estar entre 0 y el denominador (100 para porcentajes)"
	)

	return value / denominator
end

-- MakeNewProb(20)       -> 20%
-- MakeNewProb(0.001)    -> 0.001%
-- MakeNewProb(1, 10000) -> 1 entre 10000
function ProbabilityService.MakeNewProb(value, outOf)
	local probability =
		ProbabilityService.ToProbability(value, outOf)

	if probability == 0 then
		return false
	end

	if probability == 1 then
		return true
	end

	return RandomService.NextNumber() < probability
end

-- Cada premio:
-- { Id = "Raro", Probability = 20 }                -> 20%
-- { Id = "Raro", Probability = 1, OutOf = 10000 }  -> 1 entre 10000
--
-- Las probabilidades deben sumar 100%.
-- amount indica cuántos sorteos realizar; por defecto, 1.
-- Devuelve siempre una lista de IDs.
-- Puede haber premios repetidos entre sorteos.
function ProbabilityService.SelecPrize(prizes, amount)
	if amount == nil then
		amount = 1
	end

	assert(
		type(prizes) == "table" and #prizes > 0,
		"prizes debe ser una lista no vacía y sin huecos"
	)

	assert(
		IsFiniteNumber(amount)
			and amount >= 1
			and amount % 1 == 0,
		"amount debe ser un entero mayor o igual que 1"
	)

	local pool = {}
	local usedIds = {}
	local total = 0

	for index, prize in ipairs(prizes) do
		assert(
			type(prize) == "table",
			("El premio %d debe ser una tabla"):format(index)
		)

		local id = prize.Id

		assert(
			type(id) == "string" or IsFiniteNumber(id),
			("El Id del premio %d debe ser un texto o número finito"):format(index)
		)

		assert(
			not usedIds[id],
			("Id duplicado: %s"):format(tostring(id))
		)

		usedIds[id] = true

		local probability = ProbabilityService.ToProbability(
			prize.Probability,
			prize.OutOf
		)

		if probability > 0 then
			total += probability

			pool[#pool + 1] = {
				Id = id,
				Limit = total,
			}
		end
	end

	-- Permite pequeños errores de representación decimal.
	assert(
		math.abs(total - 1) <= 1e-12,
		("Las probabilidades deben sumar 100%%; suman %.12g%%"):format(
			total * 100
		)
	)

	local results = table.create(amount)

	for draw = 1, amount do
		local roll = RandomService.NextNumber() * total

		-- Respaldo para redondeos en el extremo del último intervalo.
		local selectedId = pool[#pool].Id

		for _, prize in ipairs(pool) do
			if roll < prize.Limit then
				selectedId = prize.Id
				break
			end
		end

		results[draw] = selectedId
	end

	return results
end

return ProbabilityService
