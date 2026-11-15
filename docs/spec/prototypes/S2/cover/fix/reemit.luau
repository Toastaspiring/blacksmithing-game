--!nocheck
-- worst_new.luau again, every number as build/lib.luau's L.num writes it (17 significant digits); header from header.txt
local fs = require("@lune/fs")
local process = require("@lune/process")
local IN, HEAD, OUT = process.args[1], process.args[2], process.args[3]
local W = require("./" .. IN)
local fmt = string.format
local function num(x)
	if x ~= x then return "0/0" end
	if x == 0 then return if 1 / x < 0 then "-0" else "0" end
	if x == math.floor(x) and math.abs(x) < 1e15 then return string.format("%d", x) end
	return string.format("%.17g", x)
end
local function lit(p)
	return fmt('{ id = %d, slot = "%s", shape = "%s", material = "%s", pos = { %s, %s, %s }, rot = { %s, %s, %s, %s }, size = { %s, %s, %s } }',
		p.id, p.slot, p.shape, p.material, num(p.pos[1]), num(p.pos[2]), num(p.pos[3]), num(p.rot[1]), num(p.rot[2]), num(p.rot[3]),
		num(p.rot[4]), num(p.size[1]), num(p.size[2]), num(p.size[3]))
end
local out = { "--!strict" }
for line in string.gmatch(fs.readFile(HEAD), "[^\n]+") do table.insert(out, line) end
table.insert(out, "")
table.insert(out, "return {")
table.insert(out, "\tvalid = {")
local function emit(list, withMs)
	for _, d in ipairs(list) do
		table.insert(out, "\t\t{")
		table.insert(out, fmt("\t\t\tname = %q,", d.name))
		table.insert(out, fmt("\t\t\tunits = %s,", num(d.units)))
		if withMs then table.insert(out, fmt("\t\t\tverdictMs = %.2f,", d.verdictMs)) end
		table.insert(out, "\t\t\tparts = {")
		for _, p in ipairs(d.parts) do table.insert(out, "\t\t\t\t" .. lit(p) .. ",") end
		table.insert(out, "\t\t\t},")
		table.insert(out, "\t\t},")
	end
end
emit(W.valid, true)
table.insert(out, "\t},")
table.insert(out, "\ttooComplex = {")
emit(W.tooComplex, false)
table.insert(out, "\t},")
table.insert(out, "}")
fs.writeFile(OUT, table.concat(out, "\n") .. "\n")
