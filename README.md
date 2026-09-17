# ProbabilityService

Sistema modular de sorteos para Roblox. Todos los archivos son independientes del juego actual.

## Instalación

Opción A: importa ProbabilityService.rbxm en Roblox Studio y coloca el módulo en ServerScriptService.

Opción B: conserva tu ModuleScript ProbabilityService, reemplaza su Source por ProbabilityService.luau y crea/reemplaza sus dos hijos ModuleScript:

```
ServerScriptService
└── ProbabilityService
    ├── RandomService
    └── PrizePool
```

Los nombres en Studio no llevan .luau. No necesitas requerir los módulos hijos directamente. Examples.server.luau y verify.luau no son hijos del módulo; son ejemplos y pruebas.

## Uso

```lua
local P = require(game:GetService("ServerScriptService"):WaitForChild("ProbabilityService"))

P.MakeNewProb(20)       -- 20%
P.MakeNewProb(0.001)    -- 0.001%
P.MakeNewProb(1, 10000) -- 1 entre 10000
P.ToProbability(20)    -- 0.2; conversión sin sorteo
```

Los métodos del servicio usan punto. Los métodos de un pool usan dos puntos.

## Selección por porcentajes

```lua
local prizes = {
    { Id = "Comun", Probability = 70 },
    { Id = "Raro", Probability = 1, OutOf = 4 },
    { Id = "Legendario", Probability = 5 },
}
local ids = P.SelecPrize(prizes) -- Siempre una lista de IDs.
print(ids[1])

local pool = P.CreatePool(prizes)
local three = pool:Select(3)
local distinct = pool:Select(3, { AllowDuplicates = false })
```

Las probabilidades deben sumar 100%, con una tolerancia mínima de representación decimal. Probability = 0.25 significa 0.25%, no 25%. SelectPrize y SelecPrize son alias. La cantidad por defecto es 1 y AllowDuplicates es true por defecto. Sin repetición, los pesos relativos se conservan entre premios restantes; la probabilidad condicional cambia después de cada selección. La exclusión dura solo esa llamada: el pool no se consume.

## Pesos

```lua
local pool = P.CreatePool({
    { Id = "Comun", Weight = 7 },
    { Id = "Raro", Weight = 2 },
    { Id = "Legendario", Weight = 1 },
}, { Mode = "Weight" })
local ids = pool:Select(2, { AllowDuplicates = false })
```

Un peso no es un porcentaje. Cada probabilidad es Weight / suma de pesos. Los pesos deben ser finitos y no negativos, y alguno debe ser positivo. Mode acepta Percent (por defecto) o Weight. No mezcles Weight con Probability/OutOf en una entrada.

También existe el atajo:

```lua
P.SelectPrize({{Id = "A", Weight = 2}, {Id = "B", Weight = 1}}, 2, {
    Mode = "Weight",
    AllowDuplicates = false,
})
```

## Drops independientes

```lua
local enemyDrops = P.CreateDropPool({
    { Id = "Monedas", Probability = 100 },
    { Id = "Material", Probability = 30 },
    { Id = "Espada", Probability = 1, OutOf = 1000 },
})
local ids = enemyDrops:RollDrops()
```

Evalúa cada premio por separado. Puede devolver una lista vacía o varios IDs y cada ID aparece como máximo una vez por llamada. Aquí los porcentajes NO necesitan sumar 100%. Los pesos no son válidos para drops independientes. El atajo P.RollDrops(prizes) crea un pool temporal y lo evalúa una vez.

## Consulta y reutilización

```lua
for _, item in ipairs(pool:GetProbabilities()) do
    print(item.Id, item.Probability) -- Porcentaje efectivo.
end
```

En selección muestra las probabilidades iniciales de un solo sorteo, no la probabilidad de inclusión en un lote sin repetición. En drops muestra las probabilidades independientes. Cada resultado es una copia nueva. Modificar la tabla original no modifica el pool; crea otro pool para cambiar su configuración. Reutiliza pools si sorteas frecuentemente.

## Instancias y semillas

```lua
local chests = P.new({ MaxRolls = 500 })
local test = P.new({ Seed = 12345, MaxRolls = 1000 })
local result = test.MakeNewProb(20)
```

Cada instancia tiene su propio generador. Los pools creados por una instancia comparten su generador. Una semilla fija es útil para repetir pruebas con la misma secuencia de operaciones; no la uses en producción si no deseas resultados reproducibles. Sin Seed se conserva la mezcla de tiempo, reloj, GUID y math.random del código original.

MaxRolls limita la cantidad solicitada en Select/SelectPrize/SelecPrize. Su valor predeterminado es 10000 y puede configurarse entre 1 y 1000000. No limita el número de entradas de una tabla ni es un limitador de frecuencia de solicitudes.

## Contratos

- Id: texto o número finito, único dentro de la lista.
- prizes: lista consecutiva sin huecos ni claves adicionales.
- Probabilidad 0: nunca sale. Probabilidad 100%: siempre tiene éxito en MakeNewProb o drops.
- Los premios de peso/probabilidad cero no cuentan para la capacidad sin repetición.
- Configuración inválida: error descriptivo con assert.
- Los resultados son IDs; el juego decide qué entregar.
- No modifica inventarios, cobra monedas ni guarda progreso.
- Para recompensas, ejecuta los sorteos y valida las solicitudes en el servidor.
- Usa aritmética de punto flotante y pseudoaleatoriedad; no garantiza precisión arbitraria ni un premio después de cierto número de intentos.

## Verificación

verify.luau ejecuta pruebas en Lune, incluyendo fronteras de intervalos, porcentajes/fracciones, pesos, errores, aislamiento de pools, selección sin repetición y drops. Random y HttpService se sustituyen durante estas pruebas: no son una ejecución dentro de Roblox Studio ni una validación estadística del generador de Roblox. También reconstruye ProbabilityService.rbxm y comprueba la jerarquía y fuentes después de serializar/deserializar.
