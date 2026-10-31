local T = require("./typecheck_types")
local P = require("./typecheck_plans")
local B = require("./typecheck_balance")
local sum = 0
for _, st in P.Sword.steps do sum += st.weight end
print("types ok", typeof(T), "plan steps", #P.Sword.steps, "weight sum", sum, "MassRef", B.Stats.MassRef, "QGrid", B.Quality.QGrid)
