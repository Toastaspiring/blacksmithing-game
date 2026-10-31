local serde = require("@lune/serde")
print(serde.encode("json", {a = 1/3, b = 0.1, c = 12.345678901234, d = 2^53 + 1, e = 1e-300}))
