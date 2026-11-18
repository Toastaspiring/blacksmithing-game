--!nocheck
-- K + F against K, to the bit, through the emulator: fill inside hosts with lower and higher ids mixed in, Dust anywhere, exact copies of a lower index. Only designs whose kept parts stay kept. And past the budgets.
local V = require("./v1")
local Sets = require("./b_sets")
local fmt = string.format
local R = Sets.rng(2718)
local Fx = V.Fx

local function shrunk(host, f)
	local P = V.Shapes.prepare(host, 1)
	local q = V.copyPart(host)
	q.pos = { P.gx + f * (host.pos[1] - P.gx), P.gy + f * (host.pos[2] - P.gy), P.gz + f * (host.pos[3] - P.gz) }
	q.size = { host.size[1] * f, host.size[2] * f, host.size[3] * f }
	return q
end

local function freeSlot(parts)
	return Sets.freeSlot(parts, nil)
end

local designs, moved, flipped, ddMax = 0, 0, 0, 0
local bases = {}
for _, list in ipairs({ Fx.calibration(), Fx.golden(), Fx.perf() }) do
	for _, b in ipairs(list) do
		table.insert(bases, b)
	end
end
for round = 1, 40 do
	for _, b in ipairs(bases) do
		local K = V.renumber(V.copyParts(b.parts))
		if #K >= 24 then
			for _ = 1, R.int(4, 10) do table.remove(K, R.int(1, #K)) end
			V.renumber(K)
		end
		local Rk = V.emu(V.copyParts(K))
		local KF = V.copyParts(K)
		local n = R.int(1, 24 - #K)
		local added = {}
		for k = 1, n do
			local host = K[R.int(1, #K)]
			local u = R.u()
			local f
			if u < 0.5 then
				f = shrunk(host, R.range(0.2, 0.97))
			elseif u < 0.8 then
				local d = R.range(0.02, 0.0575)
				f = V.part("Dust", R.pick({ "Block", "Ball", "Wedge", "Cylinder" }), "Blade", { R.range(-0.7, 0.7), R.range(0.1, 4.9), R.range(-0.25, 0.25) }, R.quat(), { d, d, d })
			else
				f = V.copyPart(host) -- a copy: it comes after its original, below
			end
			f.slot = freeSlot(KF)
			f.filler = true
			f.copyOf = if u >= 0.8 then host else nil
			if f.slot then
				if f.copyOf then
					table.insert(KF, f)
				else
					table.insert(KF, R.int(1, #KF + 1), f)
				end
			end
		end
		-- a copy placed after its original: keep the relative order of K's parts
		V.renumber(KF)
		designs += 1
		local before = V.Sampling.exposure(V.prep(K))
		local after = V.Sampling.exposure(V.prep(KF))
		-- map K's parts into KF: the k-th part of KF that is not a filler
		local pos, j = {}, 0
		for i, p in ipairs(KF) do
			if not p.filler then
				j += 1
				pos[j] = i
			end
		end
		local same = true
		for i = 1, #K do
			if before.kept[i] ~= after.kept[pos[i]] then same = false end
		end
		if not same then
			flipped += 1
			print("a filler moved a verdict:", b.name)
		else
			local bits = before.hSurf == after.hSurf and before.surfSamples == after.surfSamples
			for i = 1, #K do
				bits = bits and before.exposedKept[i] == after.exposedKept[pos[i]]
				for m = 1, #K do
					bits = bits and before.contact[i][m] == after.contact[pos[i]][pos[m]]
				end
			end
			local Rf = V.emu(KF)
			local w = V.dDiff(Rk, Rf)
			ddMax = math.max(ddMax, w)
			if not bits or w > 0 then
				moved += 1
				if moved <= 5 then print(fmt("moved: %s, %d fillers, bits %s, |dD| %.6f", b.name, n, tostring(bits), w)) end
			end
		end
	end
end
print(fmt("%d designs: kept set moved %d, measure or D moved %d, worst |dD| %.6f", designs, flipped, moved, ddMax))
