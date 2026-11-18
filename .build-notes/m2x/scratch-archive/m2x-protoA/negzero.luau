local serde = require("@lune/serde")
local fs = require("@lune/fs")
local s = serde.encode("json", { -0, 0, 1e-320, 5e-324 })
print(s)
local t = serde.decode("json", s)
print(1 / t[1], 1 / t[2], t[3], t[4])
local raw = fs.readFile("out/climb_4.json")
local n0 = 0
for _ in string.gmatch(raw, '[%[,]%-?0[,%]]') do n0 += 1 end
print("zero-valued numbers in climb_4.json:", n0, "  '-0' occurrences:", select(2, string.gsub(raw, "%-0[,%]]", "")))
print(string.sub(raw, 1, 400))
