local serde = require("@lune/serde")
print(serde.encode("json", {1.2345, 0.1, 12345, -120, 1000000, 0, 2^31, 0.707107, -0.000001, 1/3, -0.0}, false))
print(serde.encode("json", {B1 = 1, B2 = {}}, false))
print(serde.encode("json", {}, false))
print(utf8.len("Épée"), #"Épée")
print(math.round(-0.5), math.round(0.5), math.round(2.5), math.round(-2.5))
local x = -0.0
print(x == 0, 1/x)
