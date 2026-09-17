local PrizePool = {}

local function IsFinite(value)
	return type(value) == "number" and value == value
		and value > -math.huge and value < math.huge
end

function PrizePool.ToProbability(value, outOf)
	local denominator = if outOf == nil then 100 else outOf
	assert(IsFinite(denominator) and denominator > 0, "OutOf debe ser finito y mayor que 0")
	assert(IsFinite(value) and value >= 0 and value <= denominator,
		"Probabilidad fuera de rango: usa 0 a 100, o 0 a OutOf")
	return value / denominator
end

function PrizePool.ValidateCount(value, maximum)
	assert(IsFinite(value) and value >= 1 and value % 1 == 0 and value <= maximum,
		("La cantidad debe ser un entero entre 1 y %d"):format(maximum))
end

function PrizePool.Create(prizes, mode, independent, random, maxRolls)
	assert(mode == "Percent" or mode == "Weight", "Mode debe ser Percent o Weight")
	assert(not independent or mode == "Percent", "Los drops necesitan probabilidades, no pesos")
	assert(type(prizes) == "table" and #prizes > 0, "La lista de premios está vacía")
	-- Comprueba toda la tabla: ipairs por sí solo ocultaría huecos.
	local size = #prizes
	local count = 0
	for key in pairs(prizes) do
		assert(IsFinite(key) and key % 1 == 0 and key >= 1 and key <= size,
			"prizes debe ser una lista consecutiva, sin huecos ni claves adicionales")
		count += 1
	end
	assert(count == size, "La lista de premios tiene huecos")

	local entries, usedIds = {}, {}
	local largest = 0
	for index = 1, size do
		local prize = prizes[index]
		assert(type(prize) == "table", ("El premio %d debe ser una tabla"):format(index))
		local id = prize.Id
		assert(type(id) == "string" or IsFinite(id), "Cada Id debe ser texto o un número finito")
		assert(not usedIds[id], ("Id duplicado: %s"):format(tostring(id)))
		usedIds[id] = true
		local mass
		if mode == "Weight" then
			assert(prize.Probability == nil and prize.OutOf == nil,
				"En modo Weight usa Weight, sin Probability ni OutOf")
			mass = prize.Weight
			assert(IsFinite(mass) and mass >= 0, "Weight debe ser finito y no negativo")
		else
			assert(prize.Weight == nil, "En modo Percent usa Probability, sin Weight")
			mass = PrizePool.ToProbability(prize.Probability, prize.OutOf)
		end
		largest = math.max(largest, mass)
		entries[index] = { Id = id, Mass = mass }
	end

	local total = 0
	for _, entry in ipairs(entries) do
		-- Escalar los pesos evita desbordar al sumar números grandes.
		if mode == "Weight" and largest > 0 then
			local scaled = entry.Mass / largest
			assert(entry.Mass == 0 or scaled > 0, "Los pesos tienen una diferencia numérica excesiva")
			entry.Mass = scaled
		end
		total += entry.Mass
	end
	if not independent then
		assert(total > 0, "Debe existir al menos un premio con posibilidad de salir")
		if mode == "Percent" then
			assert(math.abs(total - 1) <= 1e-12,
				("Las probabilidades deben sumar 100%%; suman %.12g%%"):format(total * 100))
		end
		for _, entry in ipairs(entries) do
			entry.Mass /= total
		end
	end

	-- Copia privada: modificar prizes después no modifica el pool.
	local positive = {}
	for _, entry in ipairs(entries) do
		if entry.Mass > 0 then
			positive[#positive + 1] = entry
		end
	end
	local pool = {}

	function pool:GetProbabilities()
		local result = table.create(#entries)
		for index, entry in ipairs(entries) do
			result[index] = { Id = entry.Id, Probability = entry.Mass * 100 }
		end
		return result
	end

	function pool:Select(amount, options)
		assert(not independent, "Este pool es de drops; usa :RollDrops()")
		amount = if amount == nil then 1 else amount
		PrizePool.ValidateCount(amount, maxRolls)
		options = options or {}
		assert(type(options) == "table", "options debe ser una tabla")
		local allowDuplicates = options.AllowDuplicates
		if allowDuplicates == nil then allowDuplicates = true end
		assert(type(allowDuplicates) == "boolean", "AllowDuplicates debe ser booleano")
		assert(allowDuplicates or amount <= #positive,
			"No hay suficientes premios con probabilidad positiva para evitar repeticiones")
		local active = if allowDuplicates then positive else table.clone(positive)
		local result = table.create(amount)
		for draw = 1, amount do
			local remaining = 0
			for _, entry in ipairs(active) do remaining += entry.Mass end
			local roll = random.NextNumber() * remaining
			local cumulative, selected = 0, #active
			for index, entry in ipairs(active) do
				cumulative += entry.Mass
				if roll < cumulative then selected = index; break end
			end
			result[draw] = active[selected].Id
			if not allowDuplicates then table.remove(active, selected) end
		end
		return result
	end

	function pool:RollDrops()
		assert(independent, "Este pool es de selección; usa :Select()")
		local result = {}
		for _, entry in ipairs(positive) do
			if entry.Mass == 1 or random.NextNumber() < entry.Mass then
				result[#result + 1] = entry.Id
			end
		end
		return result
	end

	return table.freeze(pool)
end

return table.freeze(PrizePool)
