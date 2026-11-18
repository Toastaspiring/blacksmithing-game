--!nocheck
local V = require("./v1")
local Sampling, Shapes, Analyze = V.Sampling, V.Shapes, V.Analyze
local Balance = require("./tree/src/shared/Definitions/Balance")
local Geo = Balance.Geometry
local Sets = require("./b_sets")
local fmt = string.format
local I = V.I
local R = Sets.rng(31337)

-- (1) a Ball's grid at any radius, legal and past legal: always nf = 4, 96 samples, weights to 4 pi r^2, largest sample 1.64 %
do
	local bad, biggest = 0, 0
	local radii = { 0.0363, 0.03628, 0.04, 0.1, 0.15, 0.3, 1, 3 }
	for k = 1, 2000 do table.insert(radii, R.range(0.01, 3)) end
	for _, r in ipairs(radii) do
		local d = 2 * r
		local P = Shapes.prepare(V.part("B", "Ball", "Blade", { 0, 2, 0 }, R.quat(), { d, d, d }), 1)
		local h = Shapes.PI * P.r / 2 / (Geo.VERDICT_BALL_NF - 0.5)
		local S = Sampling.surfaceSamples(P, h, nil, Geo.VERDICT_TRIANGLE_CELLS)
		if S.n ~= 96 then bad += 1 end
		local sum, top = 0, 0
		for i = 1, S.n do sum += S.w[i]; top = math.max(top, S.w[i]) end
		if math.abs(sum - P.area) > 1e-12 * P.area then bad += 1 end
		biggest = math.max(biggest, top / P.area)
	end
	print(fmt("Ball grid: %d radii 0.01..3, %d off 96 samples or off the area; largest sample %.4f %% of the area", #radii, bad, biggest * 100))
end

local function verdictGrid(P)
	local h = Sampling.ladder(Geo.H_SURF, function(s)
		local ax = math.max(1, math.min(64, math.ceil(2 * P.hx / s)))
		local ay = math.max(1, math.min(64, math.ceil(2 * P.hy / s)))
		local az = math.max(1, math.min(64, math.ceil(2 * P.hz / s)))
		return 2 * (ax * ay + ay * az + ax * az) <= Geo.VERDICT_SAMPLES
	end)
	return Sampling.surfaceSamples(P, h, nil, Geo.VERDICT_TRIANGLE_CELLS), h
end

-- (2) every shape at the legal extremes: the verdict's grid sums to the area, no sample anywhere odd
do
	local bad, maxN, cases = 0, 0, 0
	local worst
	local sides = { 0.02, 0.021, 0.05, 0.1, 0.3, 1, 1.6, 3, 5, 6 }
	for _, shape in ipairs({ "Block", "Wedge", "CornerWedge", "Cylinder" }) do
		for _, a in ipairs(sides) do
			for _, b in ipairs(sides) do
				for _, c in ipairs(sides) do
					local size = if shape == "Cylinder" then { a, math.min(b, c), math.min(b, c) } else { a, b, c }
					local P = Shapes.prepare(V.part("X", shape, "Blade", { 0, 2, 0 }, I, size), 1)
					local S, h = verdictGrid(P)
					local sum = 0
					for i = 1, S.n do
						sum += S.w[i]
						for _, v in ipairs({ S.x[i], S.y[i], S.z[i], S.w[i], S.nx[i], S.ny[i], S.nz[i], S.e1x[i], S.e2x[i] }) do
							if v ~= v or math.abs(v) == math.huge then bad += 1 end
						end
					end
					cases += 1
					if math.abs(sum - P.area) > 1e-9 * P.area then
						bad += 1
						print("area", shape, a, b, c, sum, P.area)
					end
					if S.n > maxN then
						maxN = S.n
						worst = fmt("%s %.3f x %.3f x %.3f at h %.2f", shape, size[1], size[2], size[3], h)
					end
				end
			end
		end
	end
	print(fmt("Verdict grids: %d solids at the extremes, %d bad; most samples %d (%s)", cases, bad, maxN, worst))
end

-- (2') the cost row's "at most about 70 samples": the worst real count on the legal range, a fine sweep
do
	local top, what = 0, ""
	local hist = {}
	for _, shape in ipairs({ "Block", "Wedge", "CornerWedge", "Cylinder" }) do
		for k = 1, 40000 do
			local function side()
				local u = R.u()
				if u < 0.3 then return R.range(0.02, 0.1) end
				if u < 0.7 then return R.range(0.1, 1) end
				return R.range(1, 6)
			end
			local a, b, c = side(), side(), side()
			local size = if shape == "Cylinder" then { a, math.min(b, c), math.min(b, c) } else { a, b, c }
			local P = Shapes.prepare(V.part("X", shape, "Blade", { 0, 2, 0 }, I, size), 1)
			local S, h = verdictGrid(P)
			hist[shape] = math.max(hist[shape] or 0, S.n)
			if S.n > top then
				top, what = S.n, fmt("%s %.3f x %.3f x %.3f at h %.2f", shape, size[1], size[2], size[3], h)
			end
		end
		print(fmt("  most verdict samples, %s: %d", shape, hist[shape]))
	end
	print("  overall", top, what)
end

-- (3) patchPoint: |v| >= r on any cylinder: no division by zero: every side sample of thin and fat cylinders, turned
do
	local bad, smallest = 0, math.huge
	for k = 1, 3000 do
		local d = if R.u() < 0.5 then 0.02 else R.range(0.02, 0.6)
		local L = R.range(0.02, 6)
		local P = Shapes.prepare(V.part("C", "Cylinder", "Blade", { R.range(-1, 1), R.range(0, 5), R.range(-1, 1) }, R.quat(), { L, d, d }), 1)
		local S = Sampling.surfaceSamples(P, R.pick({ 0.04, 0.16, 0.64 }), nil, 2)
		for i = 1, S.n do
			if not S.flat[i] then
				for _, ab in ipairs({ { -0.98, -0.98 }, { 0.98, 0.98 }, { 0.75, -0.75 }, { 0, 0 } }) do
					local x = S.x[i] + ab[1] * S.e1x[i] + ab[2] * S.e2x[i]
					local y = S.y[i] + ab[1] * S.e1y[i] + ab[2] * S.e2y[i]
					local z = S.z[i] + ab[1] * S.e1z[i] + ab[2] * S.e2z[i]
					local dx, dy, dz = x - P.cx, y - P.cy, z - P.cz
					local along = dx * P.ux + dy * P.uy + dz * P.uz
					local vx, vy, vz = dx - along * P.ux, dy - along * P.uy, dz - along * P.uz
					local l = math.sqrt(vx * vx + vy * vy + vz * vz)
					smallest = math.min(smallest, l / P.r)
					if l == 0 or l ~= l then bad += 1 end
				end
			end
		end
	end
	print(fmt("patchPoint: %d bad; smallest |v|/r %.9f", bad, smallest))
end

-- (4) P-FINITE: every number of Analyze.run on legal extremes, with and without measureInvalid, many cleaned, all cleaned, Dust only, copies only
local function finite(value, path, out)
	if type(value) == "number" then
		if value ~= value or math.abs(value) == math.huge then
			table.insert(out, path)
		end
	elseif type(value) == "table" then
		for k, v in value do
			finite(v, path .. "." .. tostring(k), out)
		end
	end
end
do
	local designs, bad, invalid = 0, 0, 0
	local shapes = { "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }
	local function legal(p)
		local lo, hi = Shapes.aabb(p)
		return hi[1] - lo[1] <= 1.6 and hi[2] - lo[2] <= 5 and hi[3] - lo[3] <= 0.6
	end
	local function check(parts)
		V.renumber(parts)
		local core = { schema = 1, name = "x", type = "Sword", parts = parts }
		for _, opt in ipairs({ { measureInvalid = true }, {} }) do
			local ok, r = pcall(Analyze.run, core, opt)
			designs += 1
			if not ok then
				bad += 1
				print("ERROR", r)
			else
				if not r.validation.ok then invalid += 1 end
				local out = {}
				finite(r, "r", out)
				if #out > 0 then
					bad += 1
					print("NONFINITE", table.concat(out, ", ", 1, math.min(5, #out)))
				end
			end
		end
	end
	for k = 1, 600 do
		local n = R.int(2, 24)
		local parts = {}
		local mode = R.int(1, 5)
		for i = 1, n do
			local shape = R.pick(shapes)
			local function side()
				local u = R.u()
				if mode == 1 then return 0.02 end -- all at MIN_DIM: all Dust
				if u < 0.35 then return 0.02 end
				if u < 0.6 then return R.range(0.02, 0.1) end
				if u < 0.9 then return R.range(0.1, 1.5) end
				return R.range(1, 5)
			end
			local size = { side(), side(), side() }
			if shape == "Ball" then local d = math.min(size[1], size[2], size[3]); size = { d, d, d } end
			if shape == "Cylinder" then local d = math.min(size[2], size[3]); size = { size[1], d, d } end
			local q = if R.u() < 0.3 then I else R.quat()
			local slot = if i == 1 then "Blade" elseif i == 2 then "Grip" elseif i <= 8 then "Blade" elseif i <= 14 then "Guard" elseif i <= 18 then "Pommel" else "Grip"
			local p = V.part("x", shape, slot, { 0, 2.5, 0 }, q, size)
			local guard = 0
			while not legal(p) and guard < 40 do
				for j = 1, 3 do p.size[j] = math.max(0.02, p.size[j] * 0.7) end
				guard += 1
			end
			local lo, hi = Shapes.aabb(p)
			p.pos = { R.range(-0.8 - lo[1], 0.8 - hi[1]), 2.5 + R.range(0 - lo[2], 5 - hi[2]), R.range(-0.3 - lo[3], 0.3 - hi[3]) }
			if mode == 2 and i > 1 then -- copies of the first part
				p = V.copyPart(parts[1])
				p.slot = slot
			end
			if mode == 3 and i > 2 then -- stacked at the walls
				p.pos[1] = 0.8 - (hi[1] - lo[1]) / 2
			end
			parts[i] = p
		end
		check(parts)
	end
	print(fmt("P-FINITE: %d runs, %d bad, %d invalid", designs, bad, invalid))
end

-- (5) non-canonical input through Analyze.run: it says canonical only, Pipeline asserts it. What does it do?
do
	local base = V.fixture("F5")
	local function case(name, mutate)
		local parts = V.copyParts(base)
		V.renumber(parts)
		mutate(parts)
		local core = { schema = 1, name = "x", type = "Sword", parts = parts }
		local ok, r = pcall(Analyze.run, core, { measureInvalid = true })
		local text
		if ok then
			local out = {}
			finite(r, "r", out)
			text = fmt("runs: valid %s, cleaned %d, physics %s, non-finite %d %s", tostring(r.validation.ok), #r.cleaned, tostring(r.physics ~= nil), #out, table.concat(out, ",", 1, math.min(3, #out)))
		else
			text = "raises: " .. tostring(r)
		end
		print(fmt("  %-44s %s", name, text))
	end
	case("parts out of id order", function(p) p[1], p[3] = p[3], p[1] end)
	case("duplicate ids", function(p) p[2].id = p[1].id end)
	case("q not normalized (x 3)", function(p) for k = 1, 4 do p[4].rot[k] *= 3 end end)
	case("q = -q", function(p) for k = 1, 4 do p[4].rot[k] = -p[4].rot[k] end end)
	case("q = 0", function(p) p[4].rot = { 0, 0, 0, 0 } end)
	case("a Ball with unequal sides", function(p) p[1].size = { 0.26, 3, 0.5 } end)
	case("a Cylinder with unequal Y, Z", function(p) p[2].shape = "Cylinder"; p[2].size = { 0.9, 0.1, 0.5 } end)
	case("size 0", function(p) p[4].size = { 0, 2.6, 0.06 } end)
	case("size negative", function(p) p[4].size = { -0.16, 2.6, 0.06 } end)
	case("Wedge size 0 in Y and Z", function(p) p[4].shape = "Wedge"; p[4].size = { 0.16, 0, 0 } end)
	case("Cylinder r = 0", function(p) p[2].shape = "Cylinder"; p[2].size = { 0.9, 0, 0 } end)
	case("NaN position", function(p) p[3].pos = { 0 / 0, 1, 0 } end)
	case("inf size", function(p) p[3].size = { math.huge, 1, 1 } end)
	case("unknown slot", function(p) p[3].slot = "Handle" end)
	case("unknown material", function(p) p[3].material = "Mithril" end)
	case("25 parts", function(p) for k = 1, 20 do local c = V.copyPart(p[1]); c.id = 100 + k; c.pos[1] += 0.001 * k; table.insert(p, c) end end)
	case("no parts", function(p) table.clear(p) end)
end
