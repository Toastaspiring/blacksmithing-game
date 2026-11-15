--!nocheck
-- fix-4: V1's stud_price.luau (m2x-v1-4) on named trees. F5 with its pommel a Ball 0.6 across and its blade GROW longer,
-- plus 4 Blade studs a × len × a on the pommel's +x side along (0.828, ±0.451, ±0.451) (where the moved-out half-spaces
-- stand 0.0452 r past the sphere), their top faces p out of it: visible, the truth keeps them.
--   lune run studs -- <a> <len> <p> <grow> <tree> [<tree> ...]
local process = require("@lune/process")
local V = require("./vlab")
local Drep = require("./drep")
local a, len, p, GROW = tonumber(process.args[1]), tonumber(process.args[2]), tonumber(process.args[3]), tonumber(process.args[4])
local names = {}
for i = 5, #process.args do
	table.insert(names, process.args[i])
end
local N = V.tree(names[#names])
local function unit(x, y, z)
	local l = math.sqrt(x * x + y * y + z * z)
	return { x / l, y / l, z / l }
end
local function rotTo(d)
	return N.H.axisAngle(d[3], 0, -d[1], math.deg(math.acos(d[2])))
end
local R = 0.3
local PC = { 0, R, 0 }
local parts = N.copy(N.Blueprints.core("F5").parts)
parts[1] = N.part("Pommel", "Ball", PC, nil, { 2 * R, 2 * R, 2 * R })
parts[4].size[2] += GROW
parts[4].pos[2] += GROW / 2
parts[5].pos[2] += GROW
local base = N.copy(parts)
for _, s in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
	local d = unit(0.2484, s[1] * 0.1353, s[2] * 0.1353)
	local k = R + p - len / 2
	table.insert(parts, N.part("Blade", "Block", { PC[1] + k * d[1], PC[2] + k * d[2], PC[3] + k * d[3] }, rotTo(d), { a, len, a }))
end
local draft = N.Canonical and N.Canonical.draft or require(V.tree(names[#names]).root .. "/src/shared/Blueprint/Canonical").draft
local d = draft({ schema = 1, name = "studs", type = "Sword", parts = N.copy(parts) })
print("canonical draft ok:", d.ok)
parts = d.value.parts
Drep.report(string.format("studs %.2f × %.2f × %.2f, %.4f out, blade +%.2f", a, len, a, p, GROW), parts, #base + 1, names)
print("D without the studs: " .. V.dline(N.emu(base)))
