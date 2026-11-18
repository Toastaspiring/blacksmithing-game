--!nocheck
-- exactness where the reach matters: a round part (Ball or Cylinder, r 0.01…1, any turn) among walls and round hiders
-- whose faces stand in the band its facets' probes reach (δ … δ + its largest sag + the hider's over), every part asked by
-- the brute force: lune run x_round -- <seed> <count>
local process = require("@lune/process")
local L = require("./lib")
local E = require("./exactlib")
local TestRng = require("./repo/tests/lib/TestRng")
local Quat = L.Quat
local fmt = string.format
local seed, count = tonumber(process.args[1]) or 1, tonumber(process.args[2]) or 100
local rng = TestRng.new(seed)
local function rq()
	return Quat.hemisphere(Quat.normalize({ rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1) }))
end
local tot = { checked = 0, ties = 0, past = 0, bad = 0, nonfinite = 0, parts = 0 }
local t0 = os.clock()
for d = 1, count do
	local parts = {}
	local r = rng:pick({ 0.01, 0.02, 0.05, 0.1, 0.2, 0.3, 0.5, 1.0 }) * rng:range(0.8, 1.2)
	r = math.max(r, 0.01)
	local round = rng:pick({ "Ball", "Ball", "Cylinder" })
	local hx = rng:range(0.02, 1.5)
	local rot = if rng:float() < 0.3 then L.I else rq()
	if round == "Ball" then
		table.insert(parts, L.part(rng:pick({ "Blade", "Guard" }), "Ball", { 0, 0, 0 }, rot, { 2 * r, 2 * r, 2 * r }))
	else
		table.insert(parts, L.part(rng:pick({ "Blade", "Guard" }), "Cylinder", { 0, 0, 0 }, rot, { 2 * hx, 2 * r, 2 * r }))
	end
	local sagmax = if round == "Ball" then 0.0572 * r else 0.0049 * r
	local nw = rng:int(1, 8)
	for k = 1, nw do
		-- a wall (Block, Wedge or a round hider) whose face stands g past the round part's true surface along m
		local m = { rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1) }
		if rng:float() < 0.4 then
			m = { 0, 0, 0 }
			m[rng:int(1, 3)] = rng:pick({ -1, 1 })
		end
		local ml = math.sqrt(m[1] ^ 2 + m[2] ^ 2 + m[3] ^ 2)
		m = { m[1] / ml, m[2] / ml, m[3] / ml }
		local g = 0.012 + rng:range(-0.002, 1.05) * (sagmax + 0.03 * r) + rng:pick({ 0, 1e-7, -1e-7, 1e-9, 2e-7, 1e-5 })
		-- the true solid's support along m
		local support = r
		if round == "Cylinder" then
			local P0 = L.Shapes.prepare(L.copyPart(parts[1]), 1)
			local a = m[1] * P0.ux + m[2] * P0.uy + m[3] * P0.uz
			support = hx * math.abs(a) + r * math.sqrt(math.max(0, 1 - a * a))
		end
		local kind = rng:pick({ "Block", "Block", "Block", "Wedge", "Ball", "Cylinder" })
		local th = rng:pick({ 0.02, 0.05, 0.2 })
		local side = rng:range(0.05, 2.5) * r + 0.05
		-- a frame whose local Y is m: rotate +Y onto m
		local ax, ay, az = -m[3], 0, m[1] -- (0,1,0) × m
		local s = math.sqrt(ax * ax + az * az)
		local q
		if s < 1e-12 then
			q = if m[2] > 0 then { 0, 0, 0, 1 } else { 1, 0, 0, 0 }
		else
			local ang = math.acos(math.max(-1, math.min(1, m[2])))
			q = L.Quat.normalize({ ax / s * math.sin(ang / 2), 0, az / s * math.sin(ang / 2), math.cos(ang / 2) })
		end
		q = Quat.hemisphere(Quat.normalize(Quat.mul(q, L.axisAngle(0, 1, 0, rng:range(0, 360)))))
		if kind == "Block" or kind == "Wedge" then
			local cdist = support + g + th / 2
			table.insert(parts, L.part(rng:pick({ "Blade", "Guard", "Grip" }), kind, { m[1] * cdist, m[2] * cdist, m[3] * cdist }, q, { side, th, side }))
		elseif kind == "Ball" then
			local rr = rng:range(0.01, 0.3)
			local cdist = support + g + rr
			table.insert(parts, L.part(rng:pick({ "Blade", "Guard" }), "Ball", { m[1] * cdist, m[2] * cdist, m[3] * cdist }, rq(), { 2 * rr, 2 * rr, 2 * rr }))
		else
			local rr = rng:range(0.01, 0.3)
			local cdist = support + g + rr
			-- a cylinder lying across m (its axis local X ⟂ m): local Y of q is m, so its local X is ⟂ m
			table.insert(parts, L.part(rng:pick({ "Blade", "Guard" }), "Cylinder", { m[1] * cdist, m[2] * cdist, m[3] * cdist }, q, { rng:range(0.05, 1), 2 * rr, 2 * rr }))
		end
	end
	L.renumber(parts)
	local P = L.prep(parts)
	local models = L.models(P); if models[1] and d <= 12 then local idx = L.hidersOf(P, 1, models); local rd = L.readOf(P, 1, models); print(string.format("design %d: %s r %.3f, hiders %d of %d, reads %.4f", d, P[1].shape, P[1].r, #idx, #P - 1, rd)) end
	local ok, res = pcall(E.check, P)
	if not ok then
		print("ERROR " .. d .. ": " .. tostring(res))
	else
		tot.parts += #P
		tot.checked += res.checked
		tot.ties += res.ties
		tot.past += res.past
		tot.bad += #res.bad
		tot.nonfinite += res.nonfinite
		if #res.bad > 0 or res.nonfinite > 0 then
			print(fmt("design %d: BAD %d nonfinite %d", d, #res.bad, res.nonfinite))
			for _, b in ipairs(res.bad) do
				print(fmt("   part %d (%s) facet %d: cover %.17g outside [%.17g, %.17g] (miss %.3g of the part)", b.part, b.shape, b.facet, b.c, b.lo, b.hi, b.miss / b.total))
			end
			print("   parts: " .. require("@lune/serde").encode("json", parts))
		end
	end
end
print(fmt("seed %d: %d designs, %d parts, checked %d, ties %d, past the cell limit %d, outside the bracket %d, nonfinite %d (%.1f s)",
	seed, count, tot.parts, tot.checked, tot.ties, tot.past, tot.bad, tot.nonfinite, os.clock() - t0))
