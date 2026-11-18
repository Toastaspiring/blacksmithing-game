--!nocheck
-- fragmentation: a face under a grid of up to 22 small hiders with hairline gaps (0 … 1e-5) and offsets at the hide test's
-- ties, the grid turned by small and odd angles, every shape as the target: the reading against arrbrute, every part asked
local process = require("@lune/process")
local L = require("./lib")
local E = require("./exactlib")
local TestRng = require("./repo/tests/lib/TestRng")
local Quat = L.Quat
local fmt = string.format
local seed, count = tonumber(process.args[1]) or 1, tonumber(process.args[2]) or 100
local rng = TestRng.new(seed)
local tot = { checked = 0, ties = 0, past = 0, bad = 0, nonfinite = 0 }
local GAPS = { 0, 1e-12, 1e-11, 1e-10, 1e-9, 1e-8, 1e-7, 2e-7, 1e-6, 1e-5 }
local OFFS = { 0, 1e-12, -1e-12, 1e-7, -1e-7, 1e-7 + 1e-12, 0.012, 0.012 + 1e-7, 0.012 - 1e-7, 0.012 + 1e-7 + 1e-12, 0.006, -0.003 }
for d = 1, count do
	local shape = rng:pick({ "Block", "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" })
	local s = rng:range(0.3, 1.2)
	local size = { s, rng:range(0.1, 0.6), rng:range(0.3, 1.2) }
	if shape == "Ball" then size = { s, s, s } elseif shape == "Cylinder" then size = { size[1], size[2], size[2] } end
	local parts = { L.part(rng:pick({ "Blade", "Guard" }), shape, { 0, 0, 0 }, L.I, size) }
	local nx, nz = rng:int(2, 5), rng:int(2, 4)
	local gap = rng:pick(GAPS)
	local off = rng:pick(OFFS)
	local th = rng:pick({ 0.02, 0.05 })
	local top = (shape == "Ball" and s / 2) or size[2] / 2
	local cw, cd = (size[1] - (nx - 1) * gap) / nx, (size[3] - (nz - 1) * gap) / nz
	local tilt = rng:pick({ 0, 0, 1e-7, 1e-4, 0.3, 7 })
	local q = L.axisAngle(rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1), tilt)
	for i = 1, nx do
		for j = 1, nz do
			local x = -size[1] / 2 + (i - 0.5) * cw + (i - 1) * gap
			local z = -size[3] / 2 + (j - 0.5) * cd + (j - 1) * gap
			local p = Quat.rotate(q, { x, top + off + th / 2, z })
			table.insert(parts, L.part(rng:pick({ "Blade", "Guard", "Grip" }), "Block", p, q, { math.max(0.02, cw), th, math.max(0.02, cd) }))
		end
	end
	L.renumber(parts)
	local P = L.prep(parts)
	local ok, r = pcall(E.check, P, { only = { [1] = true } })
	if not ok then
		print("ERROR " .. d .. ": " .. tostring(r))
	else
		tot.checked += r.checked
		tot.ties += r.ties
		tot.past += r.past
		tot.bad += #r.bad
		tot.nonfinite += r.nonfinite
		if #r.bad > 0 or r.nonfinite > 0 then
			print(fmt("design %d: BAD %d nonfinite %d %s", d, #r.bad, r.nonfinite, require("@lune/serde").encode("json", parts)))
		end
	end
end
print(fmt("seed %d: %d grids, targets checked %d, ties %d, past the cell limit %d, outside the bracket %d, nonfinite %d", seed, count, tot.checked, tot.ties, tot.past, tot.bad, tot.nonfinite))
