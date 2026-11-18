local serde = require("@lune/serde")
local xs = { 1e-5, 1e-10, 1e-15, 3e-17, 1e-17, 1e-20, 1e-100, 1e-300, 2.5e-308, 0.0037301156250759953, 123456789.123456789, 1e300 }
local s = serde.encode("json", xs)
print(s)
local t = serde.decode("json", s)
for i = 1, #xs do print(string.format("%.17g -> %.17g %s", xs[i], t[i], tostring(xs[i] == t[i]))) end
