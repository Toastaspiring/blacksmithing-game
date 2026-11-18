local serde = require("@lune/serde")
local x = { 0.1 + 0.2, 1 / 3, 2.9898878901322363, 0.7112895730280278 }
local y = serde.decode("json", serde.encode("json", x))
for i = 1, #x do print(string.format("%.17g -> %.17g %s", x[i], y[i], tostring(x[i] == y[i]))) end
