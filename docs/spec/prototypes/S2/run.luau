--!strict
-- S2 prototype runner: lune run run.luau
local Analyze = require("./analyze")
local Shapes = require("./shapes")
local Swords = require("./swords")
local Gjk = require("./gjk")

local fmt = string.format

local function f3(x: number): string
	return fmt("%.3f", x)
end

local function analyzeTimed(bp: any, reps: number): any
	local R = Analyze.run(bp)
	local best = R.T.total
	for _ = 2, reps do
		local R2 = Analyze.run(bp)
		if R2.T.total < best then
			best = R2.T.total
			R = R2
		end
	end
	return R
end

local REPS = 5
local examples = {
	Swords.minimal(),
	Swords.arming("Iron"),
	Swords.arming("Steel"),
	Swords.rapier(),
	Swords.cleaver(),
	Swords.sabre(),
	Swords.dagger(),
	Swords.greatsword(),
	Swords.ornate(),
	Swords.gamey(true),
	Swords.gamey(false),
	Swords.armingSegmented(),
	Swords.armingMirrored(),
	Swords.transform(Swords.arming("Iron"), "Arming translated (+0.13,+0.27,+0.05)", { 1, 0, 0, 0 }, { 0, 0, 0 }, { 0.13, 0.27, 0.05 }),
	Swords.transform(Swords.arming("Iron"), "Arming rotated 4deg about Z at grip", Swords.qAxis(0, 0, 1, 4), { 0, 0.88, 0 }, { 0, 0, 0 }),
}

local results = {}
for _, bp in ipairs(examples) do
	table.insert(results, analyzeTimed(bp, REPS))
end

print("=== Validation / cleaning ===")
for _, R in ipairs(results) do
	print(fmt("%-46s parts=%2d errors=[%s] cleaned=[%s] gjkPairs=%d gjkIters=%d", R.name, R.parts, table.concat(R.errors, ","), table.concat(R.cleaned, ","), R.gjkCalls, R.gjkIters))
end

print("\n=== Mass properties ===")
print(fmt("%-46s %7s %7s %7s %7s %7s %7s %7s %7s %8s", "sword", "vol", "mass", "comY", "gripY", "guardY", "bal", "reach", "bladeL", "I_grip"))
for _, R in ipairs(results) do
	local m = R.mass
	print(fmt("%-46s %7.4f %7.4f %7.3f %7.3f %7.3f %7.3f %7.3f %7.3f %8.4f", R.name, m.volume, m.mass, m.com[2], R.grip[2], m.guardY, m.balance, m.reach, m.bladeLength, m.inertia))
end

print("\n=== Raw factors (set All for Volume/Thin/Asym/SC; Blade set in brackets) ===")
print(fmt("%-46s %7s %7s %8s %8s %13s %13s %7s %6s %6s %5s", "sword", "V", "thin", "tauMean", "L", "asym[blade]", "SC[blade]", "edge", "nEff", "joints", "mats"))
for _, R in ipairs(results) do
	local A, B = R.F.All, R.F.Blade
	print(fmt("%-46s %7.4f %7.3f %8.4f %8.3f %6.3f[%5.3f] %6.3f[%5.3f] %7.3f %6.2f %6.2f %5d", R.name, A.raw.Volume, A.raw.Thinness, A.meanTau, A.L, A.raw.Asymmetry, B.raw.Asymmetry, A.raw.SurfaceComplexity, B.raw.SurfaceComplexity, A.raw.EdgeLength, A.raw.PartCount, A.raw.Joints, A.raw.MaterialMix))
end

print("\n=== Normalized factors x (All | Blade) ===")
print(fmt("%-46s %6s %6s %6s %6s %6s | %6s %6s %6s | %6s %6s %6s", "sword", "Vol", "Thin", "Asym", "SC", "Edge", "AsymB", "SCB", "EdgeB", "Parts", "Joint", "Mix"))
for _, R in ipairs(results) do
	local A, B = R.F.All.x, R.F.Blade.x
	print(fmt("%-46s %6.3f %6.3f %6.3f %6.3f %6.3f | %6.3f %6.3f %6.3f | %6.3f %6.3f %6.3f", R.name, A.Volume, A.Thinness, A.Asymmetry, A.SurfaceComplexity, A.EdgeLength, B.Asymmetry, B.SurfaceComplexity, B.EdgeLength, A.PartCount, A.Joints, A.MaterialMix))
end

print("\n=== Difficulty per step: G / m / D -> tier (played) ===")
for _, R in ipairs(results) do
	local cells = {}
	for _, s in ipairs(R.steps) do
		table.insert(cells, fmt("%s%s G=%.3f m=%.2f D=%.3f %s%s", s.phase2 and "*" or "", s.id, s.G, s.m, s.D, s.tier, if s.tier ~= s.played then "->" .. s.played else ""))
	end
	print(fmt("%-46s", R.name))
	for _, c in ipairs(cells) do
		print("    " .. c)
	end
end

print("\n=== Timing (best of " .. REPS .. ", ms) ===")
print(fmt("%-46s %6s %6s %6s %6s %6s %7s %6s %6s %6s", "sword", "valid", "surf", "mass", "edge", "factor", "TOTAL", "volS", "surfS", "edgeC"))
for _, R in ipairs(results) do
	local T = R.T
	print(fmt("%-46s %6.2f %6.2f %6.2f %6.2f %6.2f %7.2f %6d %6d %6d", R.name, T.validate * 1000, T.surface * 1000, T.mass * 1000, T.edge * 1000, T.factors * 1000, T.total * 1000, R.volSamples, R.surfSamples, R.edge.cells))
end

print("\n=== Edge chains (blade outline, sharpenable) ===")
for _, R in ipairs(results) do
	local segs = {}
	for _, c in ipairs(R.edge.chains) do
		table.insert(segs, fmt("%d pts / %.3f", #c.points, c.length))
	end
	print(fmt("%-46s total=%.3f loops=%d chains: %s", R.name, R.edge.length, R.edge.loops, table.concat(segs, "; ")))
end
-- print the arming sword chain points (S3 path sample)
do
	local R = results[2]
	local pts = {}
	for _, p in ipairs(R.edge.chains[1].points) do
		table.insert(pts, fmt("(%.3f,%.3f)", p[1], p[2]))
	end
	print("Arming main chain: " .. table.concat(pts, " "))
end

-- ---------------------------------------------------------------- markdown summary for the draft
print("\n=== MARKDOWN: physics ===")
print("| Sword | Parts (kept) | Volume st^3 | Mass mu | Balance st | Reach st | Blade len st | I_grip mu*st^2 | ms |")
print("|---|---|---|---|---|---|---|---|---|")
for _, R in ipairs(results) do
	local m = R.mass
	print(fmt("| %s | %d (%d) | %.4f | %.3f | %.3f | %.3f | %.3f | %.3f | %.1f |", R.name, R.parts, R.parts - #R.cleaned, m.volume, m.mass, m.balance, m.reach, m.bladeLength, m.inertia, R.T.total * 1000))
end
print("\n=== MARKDOWN: blade profile ===")
print("| Sword | Grip axis | Blade mean thickness st | Blade width st | Cut index | Edge chains |")
print("|---|---|---|---|---|---|")
for _, R in ipairs(results) do
	local e = R.edge
	print(fmt("| %s | (%.3f, %.3f) | %.3f | %.3f | %.2f | %d |", R.name, R.axis[1], R.axis[2], e.bladeMeanThickness, e.bladeWidth, e.cutIndex, #e.chains))
end
print("\n=== MARKDOWN: factors (raw -> x) ===")
print("| Sword | Volume | Thinness | Asym (All / Blade) | SC (All / Blade) | Edge st | PartCount | Joints | Mix |")
print("|---|---|---|---|---|---|---|---|---|")
for _, R in ipairs(results) do
	local A, B = R.F.All, R.F.Blade
	print(fmt("| %s | %.3f -> %.2f | %.2f | %.3f / %.3f -> %.2f / %.2f | %.2f / %.2f -> %.2f / %.2f | %.2f -> %.2f | %.1f -> %.2f | %.1f -> %.2f | %d -> %.2f |", R.name,
		A.raw.Volume, A.x.Volume, A.x.Thinness, A.raw.Asymmetry, B.raw.Asymmetry, A.x.Asymmetry, B.x.Asymmetry,
		A.raw.SurfaceComplexity, B.raw.SurfaceComplexity, A.x.SurfaceComplexity, B.x.SurfaceComplexity,
		A.raw.EdgeLength, A.x.EdgeLength, A.raw.PartCount, A.x.PartCount, A.raw.Joints, A.x.Joints, A.raw.MaterialMix, A.x.MaterialMix))
end
print("\n=== MARKDOWN: difficulty (G_s / D_s -> played tier) ===")
print("| Sword | Smelting | Hammering | Sharpening | *Quenching | *Assembly | *Finishing |")
print("|---|---|---|---|---|---|---|")
for _, R in ipairs(results) do
	local cells = {}
	for _, s in ipairs(R.steps) do
		cells[s.id] = fmt("%.3f / %.3f %s", s.G, s.D, if s.phase2 then s.tier else (s.played .. (if s.tier ~= s.played then " (" .. s.tier .. ")" else "")))
	end
	print(fmt("| %s | %s | %s | %s | %s | %s | %s |", R.name, cells.Smelting, cells.Hammering, cells.Sharpening, cells.Quenching, cells.Assembly, cells.Finishing))
end

-- ---------------------------------------------------------------- mirror tool check
print("\n=== Mirror tool check (vertex sets) ===")
local function vertsOf(p)
	local P = Shapes.prepare(Shapes.sanitizePart(p), 1)
	local out = {}
	for i = 1, #P.wverts, 3 do
		table.insert(out, { P.wverts[i], P.wverts[i + 1], P.wverts[i + 2] })
	end
	return out, P
end
for _, shape in ipairs({ "Block", "Wedge", "CornerWedge" }) do
	local q = Swords.qmul(Swords.qAxis(0.3, 1, 0.2, 37), Swords.qAxis(1, 0.1, 0.4, 61))
	local p = Swords.part("A", shape, "Guard", "Iron", { 0.31, 1.7, 0.05 }, q, { 0.11, 0.23, 0.37 })
	local m = Swords.mirrorX(p, 0, "B")
	local va = vertsOf(p)
	local vb, PB = vertsOf(m)
	-- reflect va and match each to nearest in vb
	local worst = 0
	for _, a in ipairs(va) do
		local best = math.huge
		for _, b in ipairs(vb) do
			local dx, dy, dz = -a[1] - b[1], a[2] - b[2], a[3] - b[3]
			best = math.min(best, math.sqrt(dx * dx + dy * dy + dz * dz))
		end
		worst = math.max(worst, best)
	end
	-- also check the mirrored centroid
	local _, PA = vertsOf(p)
	print(fmt("%-12s max vertex mismatch = %.2e   centroid mismatch = %.2e", shape, worst, math.abs(-PA.gx - PB.gx) + math.abs(PA.gy - PB.gy) + math.abs(PA.gz - PB.gz)))
end

-- Z-mirror (plane z = z0): Block/Wedge/Cylinder/Ball q' = (w,-x,-y,z)*qY(180); CornerWedge q' = (w,-x,-y,z)*qY(-90), size (sz,sy,sx)
do
	local function mirrorZ(p, z0)
		local q = p.rot
		local qm = { q[1], -q[2], -q[3], q[4] }
		local size = { p.size[1], p.size[2], p.size[3] }
		if p.shape == "CornerWedge" then
			qm = Swords.qmul(qm, { math.sqrt(0.5), 0, -math.sqrt(0.5), 0 })
			size = { p.size[3], p.size[2], p.size[1] }
		else
			qm = Swords.qmul(qm, { 0, 0, 1, 0 })
		end
		return Swords.part("B", p.shape, p.slot, p.material, { p.pos[1], p.pos[2], 2 * z0 - p.pos[3] }, qm, size)
	end
	for _, shape in ipairs({ "Block", "Wedge", "CornerWedge", "Cylinder" }) do
		local q = Swords.qmul(Swords.qAxis(0.3, 1, 0.2, 37), Swords.qAxis(1, 0.1, 0.4, 61))
		local p = Swords.part("A", shape, "Guard", "Iron", { 0.31, 1.7, 0.05 }, q, { 0.11, 0.23, 0.37 })
		local m = mirrorZ(p, 0)
		local PA = Shapes.prepare(Shapes.sanitizePart(p), 1)
		local PB = Shapes.prepare(Shapes.sanitizePart(m), 1)
		-- compare by sampling: every volume sample of A mirrored must be inside B and vice versa
		local xs, ys, zs = Shapes.volumeSamples(PA, 0.02, 3, 40, 20000)
		local bad = 0
		for k = 1, #xs do
			if Shapes.sd(PB, xs[k], ys[k], -zs[k]) > 1e-9 then
				bad += 1
			end
		end
		print(fmt("Z-mirror %-12s samples=%d outside-mirror=%d  volume A=%.6f B=%.6f", shape, #xs, bad, PA.volume, PB.volume))
	end
end

-- ---------------------------------------------------------------- GJK tolerance checks
print("\n=== Contact tolerance checks (CONTACT_TOL = 0.01) ===")
local function prep(p)
	return Shapes.prepare(Shapes.sanitizePart(p), 1)
end
local base = prep(Swords.part("A", "Block", "Blade", "Iron", { 0, 1, 0 }, { 1, 0, 0, 0 }, { 0.4, 0.4, 0.4 }))
local cases = {
	{ "face-face flush", Swords.part("B", "Block", "Blade", "Iron", { 0, 1.4, 0 }, { 1, 0, 0, 0 }, { 0.4, 0.4, 0.4 }) },
	{ "face gap 0.005", Swords.part("B", "Block", "Blade", "Iron", { 0, 1.405, 0 }, { 1, 0, 0, 0 }, { 0.4, 0.4, 0.4 }) },
	{ "face gap 0.015", Swords.part("B", "Block", "Blade", "Iron", { 0, 1.415, 0 }, { 1, 0, 0, 0 }, { 0.4, 0.4, 0.4 }) },
	{ "edge on face (45deg) flush", Swords.part("B", "Block", "Blade", "Iron", { 0, 1.2 + 0.2 * math.sqrt(2), 0 }, Swords.qAxis(0, 0, 1, 45), { 0.4, 0.4, 0.4 }) },
	{ "edge on face gap 0.008", Swords.part("B", "Block", "Blade", "Iron", { 0, 1.208 + 0.2 * math.sqrt(2), 0 }, Swords.qAxis(0, 0, 1, 45), { 0.4, 0.4, 0.4 }) },
	{ "edge-edge crossed gap 0.012", Swords.part("B", "Block", "Blade", "Iron", { 0, 1.212 + 0.2 * math.sqrt(2), 0.0 }, Swords.qmul(Swords.qAxis(0, 1, 0, 45), Swords.qAxis(1, 0, 0, 45)), { 0.4, 0.4, 0.4 }) },
	{ "ball on face flush", Swords.part("B", "Ball", "Blade", "Iron", { 0.1, 1.35, 0.1 }, { 1, 0, 0, 0 }, { 0.3, 0.3, 0.3 }) },
	{ "ball gap 0.02", Swords.part("B", "Ball", "Blade", "Iron", { 0.1, 1.37, 0.1 }, { 1, 0, 0, 0 }, { 0.3, 0.3, 0.3 }) },
	{ "cylinder side on face flush", Swords.part("B", "Cylinder", "Blade", "Iron", { 0, 1.3, 0 }, { 1, 0, 0, 0 }, { 0.6, 0.2, 0.2 }) },
	{ "cylinder rotated 33deg, gap 0.009", Swords.part("B", "Cylinder", "Blade", "Iron", { 0, 1.209 + 0.3 * math.sin(math.rad(33)) + 0.1 * math.cos(math.rad(33)), 0 }, Swords.qAxis(0, 0, 1, 33), { 0.6, 0.2, 0.2 }) },
	{ "cylinder rotated 33deg, gap 0.012", Swords.part("B", "Cylinder", "Blade", "Iron", { 0, 1.212 + 0.3 * math.sin(math.rad(33)) + 0.1 * math.cos(math.rad(33)), 0 }, Swords.qAxis(0, 0, 1, 33), { 0.6, 0.2, 0.2 }) },
	{ "wedge slope on block edge, gap 0.006", Swords.part("B", "Wedge", "Blade", "Iron", { 0, 1.2 + 0.2 + 0.006 * math.sqrt(2), -0.4 }, { 1, 0, 0, 0 }, { 0.4, 0.4, 0.4 }) },
	{ "cornerwedge apex touching face", Swords.part("B", "CornerWedge", "Blade", "Iron", { 0.0, 1.2 + 0.15, 0.0 }, Swords.qAxis(1, 0, 0, 180), { 0.3, 0.3, 0.3 }) },
	{ "overlapping 50%", Swords.part("B", "Block", "Blade", "Iron", { 0.2, 1.2, 0 }, { 1, 0, 0, 0 }, { 0.4, 0.4, 0.4 }) },
}
for _, cse in ipairs(cases) do
	local B = prep(cse[2])
	local ok, d, it = Gjk.within(base, B, 0.01)
	print(fmt("%-36s connected=%-5s dist~%.4f iters=%d", cse[1], tostring(ok), d, it))
end

-- ---------------------------------------------------------------- invalid blueprints
print("\n=== Validation error cases ===")
do
	local a = Swords.arming()
	a.name = "pommel detached by 0.03"
	a.parts[1].pos = { 0, 0.30 - 0.05, 0 }
	local b = Swords.arming()
	b.name = "blade beyond hitbox top"
	b.parts[4].size = { 0.20, 3.8, 0.06 }
	b.parts[4].pos = { 0, 3.3, 0 }
	local c = Swords.arming()
	c.name = "no grip"
	table.remove(c.parts, 2)
	local d = Swords.transform(Swords.arming(), "upside-down", Swords.qAxis(1, 0, 0, 180), { 0, 2.225, 0 }, { 0, 0, 0 })
	for _, bp in ipairs({ a, b, c, d }) do
		local R = Analyze.run(bp)
		print(fmt("%-36s errors=[%s]", bp.name, table.concat(R.errors, ",")))
	end
end

-- ---------------------------------------------------------------- global voxel grid vs per-part sampling (aliasing)
print("\n=== Aliasing: global cell-centre voxel grid (cell 0.05) vs S2 per-part sampling ===")
local function globalVoxelVolume(bp, cell)
	local parts = {}
	for i, raw in ipairs(bp.parts) do
		parts[i] = Shapes.prepare(Shapes.sanitizePart(raw), i)
	end
	local nx, ny, nz = math.floor(1.6 / cell + 0.5), math.floor(5.0 / cell + 0.5), math.floor(0.6 / cell + 0.5)
	local count = 0
	for i = 0, nx - 1 do
		local x = -0.8 + (i + 0.5) * cell
		for j = 0, ny - 1 do
			local y = (j + 0.5) * cell
			for k = 0, nz - 1 do
				local z = -0.3 + (k + 0.5) * cell
				for _, p in ipairs(parts) do
					if Shapes.aabbContains(p, x, y, z, 0) and Shapes.sd(p, x, y, z) <= 0 then
						count += 1
						break
					end
				end
			end
		end
	end
	return count * cell * cell * cell
end
local bladeOnly = { name = "blade", parts = { Swords.part("Blade", "Block", "Blade", "Iron", { 0, 2.65, 0 }, { 1, 0, 0, 0 }, { 0.20, 2.50, 0.06 }) } }
print(fmt("exact blade volume = %.5f", 0.20 * 2.50 * 0.06))
for _, dz in ipairs({ 0, 0.005, 0.01, 0.015, 0.02, 0.025 }) do
	local moved = Swords.transform(bladeOnly, "m", { 1, 0, 0, 0 }, { 0, 0, 0 }, { 0.0, 0, dz })
	local gv = globalVoxelVolume(moved, 0.05)
	local R = Analyze.run({ name = "b", parts = { moved.parts[1], Swords.part("Grip", "Block", "Grip", "Iron", { 0, 1.0, dz }, { 1, 0, 0, 0 }, { 0.1, 0.8, 0.06 }) } })
	print(fmt("dz=%.3f  global-grid V=%.5f (%+5.1f%%)   S2 owned blade V=%.5f", dz, gv, (gv / 0.03 - 1) * 100, R.F.Blade.raw.Volume))
end

-- ---------------------------------------------------------------- surface complexity vs visible-part diversity
print("\n=== SurfaceComplexity raw (S/(6V^2/3)) vs VisibleParts (inverse Simpson of exposed areas) ===")
for _, R in ipairs(results) do
	print(fmt("%-46s SC_all=%.3f SC_blade=%.3f  Vis_all=%.2f Vis_blade=%.2f  exposedA=%.3f", R.name, R.F.All.raw.SurfaceComplexity, R.F.Blade.raw.SurfaceComplexity, R.F.All.raw.VisibleParts, R.F.Blade.raw.VisibleParts, R.F.All.exposed or 0))
end

-- ---------------------------------------------------------------- edge length rotation sensitivity
print("\n=== Edge length vs whole-sword rotation about Z (arming, pivot at grip) ===")
for _, deg in ipairs({ 0, 1, 2, 3, 5, 7, 9 }) do
	local bp = Swords.transform(Swords.arming("Iron"), "rot", Swords.qAxis(0, 0, 1, deg), { 0, 0.88, 0 }, { 0, 0, 0 })
	local R = Analyze.run(bp)
	print(fmt("rot %2d deg: edge=%.3f chains=%d  asymAll=%.3f thin=%.3f SC=%.3f errors=[%s]", deg, R.edge.length, #R.edge.chains, R.F.All.raw.Asymmetry, R.F.All.raw.Thinness, R.F.All.raw.SurfaceComplexity, table.concat(R.errors, ",")))
end

-- ---------------------------------------------------------------- adversarial cost
print("\n=== Adversarial worst case: 24 large overlapping parts filling the hitbox ===")
do
	local bp = { name = "stress", parts = {} }
	local slots = { "Grip", "Grip", "Grip", "Pommel" }
	for k = 1, 24 do
		local slot = if k <= 12 then "Blade" elseif k <= 20 then "Guard" else slots[k - 20]
		local shape = ({ "Block", "Wedge", "Cylinder", "CornerWedge" })[(k % 4) + 1]
		local rot = Swords.qAxis(0, 0, 1, 0.05 * k)
		local size = { 1.5, 4.6, 0.55 }
		if shape == "Cylinder" then
			rot = Swords.qmul(Swords.qAxis(0, 0, 1, 90 + 0.05 * k), { 1, 0, 0, 0 })
			size = { 4.6, 0.55, 0.55 }
		end
		table.insert(bp.parts, Swords.part("S" .. k, shape, slot, "Iron", { 0, 2.5, 0 }, rot, size))
	end
	local R = analyzeTimed(bp, 3)
	local T = R.T
	print(fmt("errors=[%s] volS=%d (h=%.3f) surfS=%d (h=%.3f) edgeCells=%d", table.concat(R.errors, ","), R.volSamples, R.hVol, R.surfSamples, R.hSurf, R.edge.cells))
	print(fmt("ms: valid %.1f surf %.1f mass %.1f edge %.1f factors %.1f TOTAL %.1f", T.validate * 1000, T.surface * 1000, T.mass * 1000, T.edge * 1000, T.factors * 1000, T.total * 1000))
end

-- ---------------------------------------------------------------- micro benchmark: cost of one sd evaluation
do
	local P = Shapes.prepare(Shapes.sanitizePart(Swords.part("A", "Wedge", "Blade", "Iron", { 0.1, 1.2, 0 }, Swords.qAxis(0.2, 1, 0.3, 33), { 0.3, 0.5, 0.2 })), 1)
	local n = 1000000
	local t0 = os.clock()
	local acc = 0
	for i = 1, n do
		acc += Shapes.sd(P, 0.1 + (i % 7) * 0.01, 1.2, 0.01)
	end
	local dt = os.clock() - t0
	print(fmt("\nsd() cost: %.3f us per call (%d calls, checksum %.3f)", dt / n * 1e6, n, acc))
end

-- ---------------------------------------------------------------- determinism: run twice, compare bitwise
print("\n=== Determinism (two runs, exact equality) ===")
do
	local R1 = Analyze.run(Swords.sabre())
	local R2 = Analyze.run(Swords.sabre())
	local same = true
	for i, s in ipairs(R1.steps) do
		if s.D ~= R2.steps[i].D then
			same = false
		end
	end
	same = same and R1.mass.mass == R2.mass.mass and R1.edge.length == R2.edge.length
	print("sabre identical across runs: " .. tostring(same))
end
