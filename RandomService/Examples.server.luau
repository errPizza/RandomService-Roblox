-- Ejemplo opcional: colocar como Script en ServerScriptService.
local P = require(game:GetService("ServerScriptService"):WaitForChild("ProbabilityService"))

print("20%:", P.MakeNewProb(20))
print("0.001%:", P.MakeNewProb(0.001))
print("1 entre 10000:", P.MakeNewProb(1, 10000))

local chest = P.CreatePool({
    { Id = "Comun", Probability = 70 },
    { Id = "Raro", Probability = 1, OutOf = 4 },
    { Id = "Legendario", Probability = 5 },
})
print("Un premio:", chest:Select()[1])
print("Tres sorteos:", chest:Select(3))
print("Tres distintos:", chest:Select(3, { AllowDuplicates = false }))

local weighted = P.CreatePool({
    { Id = "Rojo", Weight = 5 },
    { Id = "Verde", Weight = 3 },
    { Id = "Azul", Weight = 2 },
}, { Mode = "Weight" })
print("Selección por pesos:", weighted:Select()[1])
for _, info in ipairs(weighted:GetProbabilities()) do
    print(info.Id, info.Probability .. "%")
end

local drops = P.CreateDropPool({
    { Id = "Monedas", Probability = 100 },
    { Id = "Material", Probability = 30 },
    { Id = "Espada", Probability = 1, OutOf = 1000 },
})
for _, id in ipairs(drops:RollDrops()) do
    print("Drop:", id)
end

local isolated = P.new({ Seed = 12345, MaxRolls = 500 })
print("Instancia separada:", isolated.MakeNewProb(50))
