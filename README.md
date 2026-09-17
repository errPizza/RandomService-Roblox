# ProbabilityService

A reusable probability and prize-selection module for Roblox, written in Luau.  
Un módulo reutilizable de probabilidades y selección de premios para Roblox, escrito en Luau.

**[English](#english) · [Español](#espanol)**

<a id="english"></a>

## English

### Overview

ProbabilityService provides percentage and fraction checks, weighted prize selection, selection without replacement, independent drops, and reusable prize pools. It returns booleans or prize IDs so each game can decide how to use the results.

It can be reused across Roblox experiences without depending on a particular inventory, currency, player-data system, or external plugin. It requires Roblox APIs and is not a standalone standard Lua library.

### Features

- Percentage checks: `MakeNewProb(20)` means **20%**.
- Fraction checks: `MakeNewProb(1, 10000)` means **1 in 10,000**.
- Percentage-based and weight-based prize selection.
- One or multiple results, with optional duplicate prevention.
- Independent drops that can return zero, one, or multiple prizes.
- Reusable pools with a private copy of their configuration.
- Effective-probability inspection.
- Separate generator instances and optional seeds for reproducible tests.
- Configuration validation and a configurable selection-count limit.
- Compatibility with both `SelectPrize()` and the original `SelecPrize()` spelling.

### Files and installation

| File | Purpose |
| --- | --- |
| [ProbabilityService.luau](./ProbabilityService.luau) | Main public API. |
| [RandomService.luau](./RandomService.luau) | Generator creation and seed handling. |
| [PrizePool.luau](./PrizePool.luau) | Validation and selection/drop algorithms. |
| [ProbabilityService.rbxm](./ProbabilityService.rbxm) | Importable model containing all three ModuleScripts. |
| [Examples.server.luau](./Examples.server.luau) | Optional usage examples. |
| [verify.luau](./verify.luau) | Local logic tests and model packaging checks. |

Import `ProbabilityService.rbxm` into Roblox Studio and place its root ModuleScript in `ServerScriptService`. Alternatively, create the following hierarchy and paste the corresponding source into each ModuleScript:

```text
ServerScriptService
└── ProbabilityService (ModuleScript)
    ├── RandomService (ModuleScript)
    └── PrizePool (ModuleScript)
```

Names in Studio must match exactly and must not include `.luau`. Both helper modules are direct children of `ProbabilityService`. The examples and verification script are not required children.

Require only the main module from your game scripts:

```lua
local P = require(
    game:GetService("ServerScriptService"):WaitForChild("ProbabilityService")
)
```

The following examples assume this `P` variable exists. **Use a dot for service functions and a colon for pool methods:** `P.CreatePool(...)`, then `pool:Select(...)`.

### Probability formats

| Input | Meaning | Internal probability |
| --- | --- | --- |
| `20` | 20% | `0.2` |
| `0.001` | 0.001% | `0.00001` |
| `1, 10000` | 1 in 10,000 | `0.0001` |
| `1, 100000000` | 1 in 100,000,000 | `0.00000001` |

A single argument is always a percentage. In particular, `0.25` means **0.25%**, not 25%.

```lua
local success = P.MakeNewProb(20)
local rareSuccess = P.MakeNewProb(0.001)
local fractionSuccess = P.MakeNewProb(1, 10000)

print(P.MakeNewProb(0))   -- Always false.
print(P.MakeNewProb(100)) -- Always true.

local probability = P.ToProbability(20) -- 0.2; does not perform a roll.
```

`ToProbability()` returns a value between 0 and 1. Do not pass that result as a single percentage argument unless you intend to divide by 100 again. To use it as a fraction, call `P.MakeNewProb(probability, 1)`.

### Percentage selection

```lua
local prizes = {
    { Id = "Common", Probability = 70 },
    { Id = "Rare", Probability = 1, OutOf = 4 }, -- 25%.
    { Id = "Legendary", Probability = 5 },
}

local selected = P.SelectPrize(prizes)
print(selected[1]) -- Always a list, even for one prize.

local three = P.SelecPrize(prizes, 3) -- Original name remains supported.
```

Percentage selection requires probabilities to add up to **100%**. A small floating-point tolerance is allowed. Each successful call returns exactly the requested number of IDs; duplicates are allowed by default.

To represent a no-reward outcome, include an explicit ID:

```lua
local result = P.SelectPrize({
    { Id = "Reward", Probability = 20 },
    { Id = "Nothing", Probability = 80 },
})

if result[1] ~= "Nothing" then
    print("Award:", result[1])
end
```

`"Nothing"` has no built-in special behavior. Your game interprets that ID.

### Reusable pools and selection without replacement

```lua
local chest = P.CreatePool({
    { Id = "Common", Probability = 70 },
    { Id = "Rare", Probability = 25 },
    { Id = "Legendary", Probability = 5 },
})

local one = chest:Select()
local several = chest:Select(3)
local distinct = chest:Select(2, {
    AllowDuplicates = false,
})
```

A pool validates and copies its configuration when created. Editing the original prize table later does not update the pool; create a new pool to use a changed configuration. Reuse pools for repeated rolls to avoid recreating and revalidating their configurations.

With `AllowDuplicates = false`, each selected prize is removed from that call's remaining candidates. Relative weights among the remaining prizes are preserved. For example, after removing the 70% prize above, the next draw gives the other prizes probabilities of `25 / 30` and `5 / 30`.

The pool itself is not consumed. A later call starts with all candidates again. Requesting more distinct prizes than the number of positive-probability entries raises an error.

### Weight-based selection

```lua
local weighted = P.CreatePool({
    { Id = "Common", Weight = 7 },
    { Id = "Rare", Weight = 2 },
    { Id = "Legendary", Weight = 1 },
}, {
    Mode = "Weight",
})

local selected = weighted:Select(2, {
    AllowDuplicates = false,
})
```

Weights do not need to add up to 100. Each initial probability is:

```text
probability = prize weight / sum of all weights
```

Weights `7, 2, 1` produce `70%, 20%, 10%`. Weights `2, 1` produce approximately `66.67%, 33.33%`. Use `Weight` fields and explicitly set `Mode = "Weight"`; do not mix them with `Probability` or `OutOf` fields.

For a one-off selection:

```lua
local selected = P.SelectPrize({
    { Id = "A", Weight = 2 },
    { Id = "B", Weight = 1 },
}, 2, {
    Mode = "Weight",
    AllowDuplicates = false,
})
```

### Independent drops

Use independent drops when multiple items may succeed in the same event:

```lua
local enemyDrops = P.CreateDropPool({
    { Id = "Coins", Probability = 100 },
    { Id = "Material", Probability = 30 },
    { Id = "Sword", Probability = 1, OutOf = 1000 },
})

local droppedIds = enemyDrops:RollDrops()
for _, id in ipairs(droppedIds) do
    print("Drop:", id)
end
```

Each entry is checked independently. The probabilities do **not** need to add up to 100%, and weights are not supported. Each ID appears at most once per call. Results preserve the configured order of successful entries.

Drops may return an empty list; in the example above, coins are guaranteed because their probability is 100%. To perform a one-off drop evaluation, use `P.RollDrops(prizes)`.

| Operation | Number of results | Probability relationship |
| --- | --- | --- |
| `pool:Select(amount)` | Exactly `amount` | Selects among competing candidates. |
| `dropPool:RollDrops()` | Zero to the number of entries | Evaluates each entry independently. |

Calling `Select()` on a drop pool or `RollDrops()` on a selection pool raises an error.

### Inspecting probabilities

```lua
for _, entry in ipairs(weighted:GetProbabilities()) do
    print(entry.Id, entry.Probability .. "%")
end
```

Returns a fresh list of `{ Id = ..., Probability = ... }`, with percentages from 0 to 100, including zero-probability entries. Modifying this list does not change the pool.

For selection, these are the initial probabilities for one draw. They are not the chance of appearing anywhere in a batch without replacement. For drops, they are the independent probabilities of each entry.

### Instances, seeds, and limits

```lua
local chests = P.new({ MaxRolls = 500 })
local testService = P.new({ Seed = 12345, MaxRolls = 1000 })

local success = chests.MakeNewProb(20)
local testResult = testService.MakeNewProb(50)
```

Each service instance owns a separate generator. All pools created by the same instance share that generator. Creating a pool does not perform a random draw; using a pool advances its instance's generator when randomness is needed.

`require()` returns the default service and exposes `P.new(options)` to create additional instances. Use `P.new(...)` again when you need another instance; returned instances do not expose their own `new()` method.

| Option | Default | Accepted values |
| --- | --- | --- |
| `Seed` | Generated automatically | An integer from `-(2^53 - 1)` to `2^53 - 1`. |
| `MaxRolls` | `10000` | An integer from `1` to `1000000`. |

Without a seed, `RandomService` combines time, clock, a GUID, and `math.random()` into a 32-bit hash and uses it to seed `Random.new()`.

A fixed seed is useful for reproducing tests when the inputs, ordering, and sequence of generator-consuming calls match. It is not a way to improve randomness. Do not rely on test-sequence compatibility across future engine or module changes.

`MaxRolls` limits the requested amount in `Select()`, `SelectPrize()`, and `SelecPrize()`. It does not cap the number of pool entries, limit request frequency, or track total lifetime rolls.

### Public API reference

| API | Returns | Notes |
| --- | --- | --- |
| `P.MakeNewProb(value, outOf?)` | `boolean` | Percentage if `outOf` is omitted; fraction otherwise. |
| `P.ToProbability(value, outOf?)` | `number` | Conversion to `[0, 1]` without a roll. |
| `P.CreatePool(prizes, options?)` | Selection pool | `options.Mode`: `"Percent"` (default) or `"Weight"`. |
| `P.CreateDropPool(prizes)` | Drop pool | Uses percentages or fractions. |
| `P.SelectPrize(prizes, amount?, options?)` | List of IDs | Creates a temporary pool; options accept `Mode` and `AllowDuplicates`. |
| `P.SelecPrize(prizes, amount?, options?)` | List of IDs | Alias of `SelectPrize`. |
| `P.RollDrops(prizes)` | List of IDs | Creates and evaluates a temporary drop pool. |
| `P.new(options?)` | Service instance | Available on the exported module; options accept `Seed` and `MaxRolls`. |
| `pool:Select(amount?, options?)` | List of IDs | Selection pools only; `amount = 1`, `AllowDuplicates = true` by default. |
| `pool:RollDrops()` | List of IDs | Drop pools only; evaluates each entry once. |
| `pool:GetProbabilities()` | List of probability entries | Available on both pool types; returns percentages. |

Set `Mode` when creating a selection pool. `pool:Select()` only uses `AllowDuplicates`; it does not change the pool's mode. Likewise, configure duplicate behavior on each selection call, not on `CreatePool()`.

### Validation and error handling

- Prize lists must be nonempty, consecutive arrays with no holes or extra keys on the outer table.
- Each prize must be a table with a unique string or finite-number `Id`.
- Percentages must be finite numbers between 0 and 100.
- Fractions require a finite `OutOf > 0` and a finite numerator between 0 and `OutOf`. Fraction inputs are not restricted to integers.
- Weights must be finite and nonnegative, with at least one positive weight for selection.
- Selection quantities must be positive integers within `MaxRolls`.
- Zero-probability entries never win and do not count toward the distinct-prize capacity.
- An independent drop pool may have all probabilities set to zero.

Invalid configurations raise errors through `assert`. Current error messages are in Spanish. Catch errors where your game needs to handle invalid external configuration:

```lua
local ok, poolOrError = pcall(function()
    return P.CreatePool({
        { Id = "InvalidTotal", Probability = 20 },
    })
end)

if not ok then
    warn(poolOrError)
end
```

### Integration, numerical limits, and scope

Execute reward rolls and validate requests on the server. Keep charging currency, granting items, and saving progress in the relevant game systems. This module returns results; it does not implement those operations or protect RemoteEvents by itself.

The system uses pseudorandomness and floating-point arithmetic. Extremely small chances or extremely different weights can encounter precision limits; arbitrary numerical precision is not guaranteed. A chance of 1 in N does not guarantee a success within N attempts.

Luck modifiers, pity guarantees, dynamic eligibility filters, persistence, and inventory delivery are not implemented in this version. A batch with duplicate prevention is not a persistent inventory exclusion system.

The generator is created once per service instance and reused. Building a pool takes linear time in the number of entries; selecting `k` prizes currently takes `O(k × n)` time for `n` entries. Independent drops take `O(n)` time. Reusing pools avoids repeated configuration validation but does not make each selection constant-time.

### Verification

The included verification script passed **156 assertions** covering probability conversion, interval boundaries, invalid inputs, large weights, isolated pool configuration, selection without replacement, independent drops, and model serialization.

These tests run in Lune and substitute `Random` and `HttpService`. They do not execute the module inside Roblox Studio or establish the statistical quality of Roblox's generator. Verify integration in Studio before using the module in your game.

From the parent directory containing `ProbabilityService-kit`, run:

```sh
lune run ProbabilityService-kit/verify.luau
```

The current test script expects that directory layout. It also rebuilds `ProbabilityService-kit/ProbabilityService.rbxm` and verifies that the model contains the expected scripts and source code. If you move the kit to a repository root, update the `folder` path in `verify.luau` accordingly.

---

<a id="espanol"></a>

## Español

### Descripción

ProbabilityService permite comprobar porcentajes y fracciones, seleccionar premios por pesos, seleccionar sin repetición, evaluar drops independientes y reutilizar tablas de premios. Devuelve booleanos o IDs para que cada juego decida cómo utilizar los resultados.

Puede reutilizarse en distintas experiencias de Roblox sin depender de un inventario, moneda, sistema de datos de jugadores o plugin externo. Requiere las APIs de Roblox; no es una biblioteca independiente de Lua estándar.

### Características

- Porcentajes: `MakeNewProb(20)` significa **20%**.
- Fracciones: `MakeNewProb(1, 10000)` significa **1 entre 10 000**.
- Selección de premios por porcentajes o por pesos.
- Uno o varios resultados, con opción de evitar repeticiones.
- Drops independientes que pueden devolver ninguno, uno o varios premios.
- Pools reutilizables con una copia privada de su configuración.
- Consulta de probabilidades efectivas.
- Generadores separados y semillas opcionales para reproducir pruebas.
- Validación de configuración y límite configurable de selecciones.
- Compatibilidad con `SelectPrize()` y con el nombre original `SelecPrize()`.

### Archivos e instalación

| Archivo | Función |
| --- | --- |
| [ProbabilityService.luau](./ProbabilityService.luau) | API pública principal. |
| [RandomService.luau](./RandomService.luau) | Creación del generador y gestión de semillas. |
| [PrizePool.luau](./PrizePool.luau) | Validación y algoritmos de selección y drops. |
| [ProbabilityService.rbxm](./ProbabilityService.rbxm) | Modelo importable con los tres ModuleScripts. |
| [Examples.server.luau](./Examples.server.luau) | Ejemplos opcionales. |
| [verify.luau](./verify.luau) | Pruebas locales de lógica y empaquetado. |

Importa `ProbabilityService.rbxm` en Roblox Studio y coloca su ModuleScript raíz en `ServerScriptService`. También puedes crear la siguiente estructura y pegar el código correspondiente en cada ModuleScript:

```text
ServerScriptService
└── ProbabilityService (ModuleScript)
    ├── RandomService (ModuleScript)
    └── PrizePool (ModuleScript)
```

Los nombres en Studio deben coincidir exactamente y no llevar `.luau`. Ambos módulos auxiliares son hijos directos de `ProbabilityService`. Los ejemplos y el script de verificación no son hijos necesarios.

Desde los scripts del juego, requiere únicamente el módulo principal:

```lua
local P = require(
    game:GetService("ServerScriptService"):WaitForChild("ProbabilityService")
)
```

Los siguientes ejemplos suponen que ya existe esta variable `P`. **Usa punto para las funciones del servicio y dos puntos para los métodos de los pools:** `P.CreatePool(...)` y después `pool:Select(...)`.

### Formatos de probabilidad

| Entrada | Significado | Probabilidad interna |
| --- | --- | --- |
| `20` | 20% | `0.2` |
| `0.001` | 0.001% | `0.00001` |
| `1, 10000` | 1 entre 10 000 | `0.0001` |
| `1, 100000000` | 1 entre 100 000 000 | `0.00000001` |

Un único argumento siempre representa un porcentaje. En particular, `0.25` significa **0.25%**, no 25%.

```lua
local success = P.MakeNewProb(20)
local rareSuccess = P.MakeNewProb(0.001)
local fractionSuccess = P.MakeNewProb(1, 10000)

print(P.MakeNewProb(0))   -- Siempre false.
print(P.MakeNewProb(100)) -- Siempre true.

local probability = P.ToProbability(20) -- 0.2; no realiza un sorteo.
```

`ToProbability()` devuelve un valor entre 0 y 1. No pases ese resultado como único argumento de porcentaje, salvo que quieras dividirlo nuevamente entre 100. Para usarlo como fracción, llama a `P.MakeNewProb(probability, 1)`.

### Selección por porcentajes

```lua
local prizes = {
    { Id = "Comun", Probability = 70 },
    { Id = "Raro", Probability = 1, OutOf = 4 }, -- 25%.
    { Id = "Legendario", Probability = 5 },
}

local selected = P.SelectPrize(prizes)
print(selected[1]) -- Siempre devuelve una lista, incluso para un premio.

local three = P.SelecPrize(prizes, 3) -- El nombre original sigue disponible.
```

La selección por porcentajes requiere que las probabilidades sumen **100%**. Se admite una pequeña tolerancia de punto flotante. Cada llamada válida devuelve exactamente la cantidad solicitada de IDs; por defecto, se permiten repeticiones.

Para representar un resultado sin recompensa, agrega un ID explícito:

```lua
local result = P.SelectPrize({
    { Id = "Premio", Probability = 20 },
    { Id = "Nada", Probability = 80 },
})

if result[1] ~= "Nada" then
    print("Entregar:", result[1])
end
```

`"Nada"` no tiene un comportamiento especial integrado. Tu juego interpreta ese ID.

### Pools reutilizables y selección sin repetición

```lua
local chest = P.CreatePool({
    { Id = "Comun", Probability = 70 },
    { Id = "Raro", Probability = 25 },
    { Id = "Legendario", Probability = 5 },
})

local one = chest:Select()
local several = chest:Select(3)
local distinct = chest:Select(2, {
    AllowDuplicates = false,
})
```

Un pool valida y copia su configuración al crearse. Modificar después la tabla original no actualiza el pool; crea uno nuevo para aplicar una configuración diferente. Reutiliza pools en sorteos frecuentes para evitar reconstruir y volver a validar sus configuraciones.

Con `AllowDuplicates = false`, cada premio seleccionado se elimina de los candidatos restantes de esa llamada. Se conservan los pesos relativos entre los premios restantes. Por ejemplo, al retirar el premio del 70% del ejemplo anterior, las probabilidades del siguiente sorteo serían `25 / 30` y `5 / 30`.

El pool no se consume. Una llamada posterior empieza otra vez con todos los candidatos. Pedir más premios distintos que entradas con probabilidad positiva produce un error.

### Selección por pesos

```lua
local weighted = P.CreatePool({
    { Id = "Comun", Weight = 7 },
    { Id = "Raro", Weight = 2 },
    { Id = "Legendario", Weight = 1 },
}, {
    Mode = "Weight",
})

local selected = weighted:Select(2, {
    AllowDuplicates = false,
})
```

Los pesos no necesitan sumar 100. Cada probabilidad inicial se calcula así:

```text
probabilidad = peso del premio / suma de todos los pesos
```

Los pesos `7, 2, 1` producen `70%, 20%, 10%`. Los pesos `2, 1` producen aproximadamente `66.67%, 33.33%`. Usa campos `Weight` y establece explícitamente `Mode = "Weight"`; no los mezcles con `Probability` ni `OutOf`.

Para una selección puntual:

```lua
local selected = P.SelectPrize({
    { Id = "A", Weight = 2 },
    { Id = "B", Weight = 1 },
}, 2, {
    Mode = "Weight",
    AllowDuplicates = false,
})
```

### Drops independientes

Usa drops independientes cuando varios objetos puedan obtenerse en un mismo evento:

```lua
local enemyDrops = P.CreateDropPool({
    { Id = "Monedas", Probability = 100 },
    { Id = "Material", Probability = 30 },
    { Id = "Espada", Probability = 1, OutOf = 1000 },
})

local droppedIds = enemyDrops:RollDrops()
for _, id in ipairs(droppedIds) do
    print("Drop:", id)
end
```

Cada entrada se evalúa de forma independiente. Las probabilidades **no** necesitan sumar 100% y no se admiten pesos. Cada ID aparece como máximo una vez por llamada. Los resultados conservan el orden de configuración de las entradas que tuvieron éxito.

Los drops pueden devolver una lista vacía; en el ejemplo anterior, las monedas están garantizadas porque su probabilidad es 100%. Para evaluar una tabla una sola vez, usa `P.RollDrops(prizes)`.

| Operación | Cantidad de resultados | Relación entre probabilidades |
| --- | --- | --- |
| `pool:Select(amount)` | Exactamente `amount` | Selecciona entre candidatos que compiten. |
| `dropPool:RollDrops()` | De cero al número de entradas | Evalúa cada entrada por separado. |

Llamar a `Select()` en un pool de drops o a `RollDrops()` en un pool de selección produce un error.

### Consulta de probabilidades

```lua
for _, entry in ipairs(weighted:GetProbabilities()) do
    print(entry.Id, entry.Probability .. "%")
end
```

Devuelve una lista nueva de `{ Id = ..., Probability = ... }`, con porcentajes de 0 a 100, incluyendo entradas de probabilidad cero. Modificar esta lista no cambia el pool.

En selección, muestra las probabilidades iniciales de un sorteo. No representa la probabilidad de aparecer en algún lugar de un lote sin repetición. En drops, muestra la probabilidad independiente de cada entrada.

### Instancias, semillas y límites

```lua
local chests = P.new({ MaxRolls = 500 })
local testService = P.new({ Seed = 12345, MaxRolls = 1000 })

local success = chests.MakeNewProb(20)
local testResult = testService.MakeNewProb(50)
```

Cada instancia del servicio tiene un generador separado. Todos los pools creados por una misma instancia comparten su generador. Crear un pool no realiza un sorteo; utilizarlo avanza el generador de su instancia cuando se necesita aleatoriedad.

`require()` devuelve el servicio predeterminado y expone `P.new(options)` para crear instancias adicionales. Usa nuevamente `P.new(...)` cuando necesites otra instancia; las instancias devueltas no exponen su propio método `new()`.

| Opción | Valor predeterminado | Valores admitidos |
| --- | --- | --- |
| `Seed` | Se genera automáticamente | Un entero entre `-(2^53 - 1)` y `2^53 - 1`. |
| `MaxRolls` | `10000` | Un entero entre `1` y `1000000`. |

Sin una semilla explícita, `RandomService` combina tiempo, reloj, un GUID y `math.random()` en un hash de 32 bits que utiliza como semilla de `Random.new()`.

Una semilla fija permite reproducir pruebas cuando coinciden las entradas, el orden y la secuencia de llamadas que consumen el generador. No mejora la aleatoriedad. No dependas de que una secuencia de pruebas se conserve después de cambios futuros del motor o del módulo.

`MaxRolls` limita la cantidad solicitada en `Select()`, `SelectPrize()` y `SelecPrize()`. No limita el número de entradas del pool, la frecuencia de solicitudes ni el total acumulado de sorteos.

### Referencia de la API pública

| API | Devuelve | Notas |
| --- | --- | --- |
| `P.MakeNewProb(value, outOf?)` | `boolean` | Porcentaje si se omite `outOf`; fracción si se proporciona. |
| `P.ToProbability(value, outOf?)` | `number` | Conversión a `[0, 1]` sin sortear. |
| `P.CreatePool(prizes, options?)` | Pool de selección | `options.Mode`: `"Percent"` (predeterminado) o `"Weight"`. |
| `P.CreateDropPool(prizes)` | Pool de drops | Usa porcentajes o fracciones. |
| `P.SelectPrize(prizes, amount?, options?)` | Lista de IDs | Crea un pool temporal; admite `Mode` y `AllowDuplicates`. |
| `P.SelecPrize(prizes, amount?, options?)` | Lista de IDs | Alias de `SelectPrize`. |
| `P.RollDrops(prizes)` | Lista de IDs | Crea y evalúa un pool temporal de drops. |
| `P.new(options?)` | Instancia del servicio | Disponible en el módulo exportado; admite `Seed` y `MaxRolls`. |
| `pool:Select(amount?, options?)` | Lista de IDs | Solo selección; por defecto `amount = 1` y `AllowDuplicates = true`. |
| `pool:RollDrops()` | Lista de IDs | Solo drops; evalúa cada entrada una vez. |
| `pool:GetProbabilities()` | Lista de probabilidades | Disponible en ambos tipos de pool; devuelve porcentajes. |

Establece `Mode` al crear el pool de selección. `pool:Select()` solo utiliza `AllowDuplicates`; no cambia el modo del pool. Asimismo, configura la opción de repeticiones en cada llamada de selección, no en `CreatePool()`.

### Validación y manejo de errores

- Las listas de premios deben ser arreglos consecutivos no vacíos, sin huecos ni claves adicionales en la tabla exterior.
- Cada premio debe ser una tabla con un `Id` de texto o número finito, único dentro de la lista.
- Los porcentajes deben ser números finitos entre 0 y 100.
- Las fracciones requieren un `OutOf > 0` finito y un numerador finito entre 0 y `OutOf`. Sus argumentos no están restringidos a enteros.
- Los pesos deben ser finitos y no negativos, con al menos uno positivo para selección.
- Las cantidades solicitadas deben ser enteros positivos dentro de `MaxRolls`.
- Las entradas de probabilidad cero nunca salen ni cuentan para la capacidad sin repetición.
- Un pool de drops independientes puede tener todas sus probabilidades en cero.

Las configuraciones inválidas producen errores mediante `assert`. Los mensajes actuales están en español. Captura los errores donde tu juego necesite manejar configuraciones externas inválidas:

```lua
local ok, poolOrError = pcall(function()
    return P.CreatePool({
        { Id = "TotalInvalido", Probability = 20 },
    })
end)

if not ok then
    warn(poolOrError)
end
```

### Integración, límites numéricos y alcance

Ejecuta los sorteos de recompensas y valida las solicitudes en el servidor. Deja el cobro de monedas, la entrega de objetos y el guardado del progreso en los sistemas correspondientes del juego. Este módulo devuelve resultados; no implementa esas operaciones ni protege RemoteEvents por sí solo.

El sistema utiliza pseudoaleatoriedad y aritmética de punto flotante. Las probabilidades extremadamente pequeñas o las diferencias extremas entre pesos pueden alcanzar límites de precisión; no se garantiza precisión numérica arbitraria. Una probabilidad de 1 entre N no garantiza un éxito en N intentos.

Esta versión no implementa modificadores de suerte, garantías por intentos fallidos (pity), filtros dinámicos de elegibilidad, persistencia ni entrega al inventario. Un lote sin repetición no equivale a excluir permanentemente los objetos que ya posee un jugador.

El generador se crea una vez por instancia y se reutiliza. Crear un pool requiere tiempo lineal según sus entradas; seleccionar `k` premios actualmente requiere `O(k × n)` para `n` entradas. Los drops independientes requieren `O(n)`. Reutilizar pools evita validar repetidamente la configuración, pero no convierte cada selección en una operación de tiempo constante.

### Verificación

El script de verificación incluido pasó **156 comprobaciones** de conversión de probabilidades, fronteras de intervalos, entradas inválidas, pesos grandes, aislamiento de configuraciones, selección sin repetición, drops independientes y serialización del modelo.

Estas pruebas se ejecutan en Lune y sustituyen `Random` y `HttpService`. No ejecutan el módulo dentro de Roblox Studio ni demuestran la calidad estadística del generador de Roblox. Verifica la integración en Studio antes de utilizarlo en tu juego.

Desde el directorio padre que contiene `ProbabilityService-kit`, ejecuta:

```sh
lune run ProbabilityService-kit/verify.luau
```

El script de pruebas actual espera esa estructura de directorios. También reconstruye `ProbabilityService-kit/ProbabilityService.rbxm` y comprueba que el modelo contenga los scripts y códigos esperados. Si mueves el kit a la raíz de un repositorio, ajusta la ruta `folder` de `verify.luau`.
