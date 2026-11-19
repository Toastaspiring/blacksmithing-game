--!strict
-- Physics/Cover (SPEC §4.4, §4.9, E-S2.12): the Enclosed verdict's reading, exact on a polyhedral model of each part.
--   (a) exact on its model: against CoverBrute's 3D clip and slab union with every part that hides, every part within EXACT
--       of its area, unless a tie (a face on the hide test's boundary to rounding) brackets it: then each facet lies between
--       the brute force with every piece grown and shrunk by TIE
--   (b) closed forms on the plate under lids
--   (c) the attack designs with their truth (CoverAttacks): the truth's verdict, within the model's band of its share; a
--       Ball sealed in walls its own probe reaches; the hiders Sampling itself hands over; a copy spun about a tied axis
--   (d) what it does not depend on: the order of the parts, a mirror image, an exact copy first or last, Dust
--   (e) the model: frames the world fixes, mirror images, the brute force's own construction, the sag, spread, hulls,
--       reach and over; a flat face's 32-gon against a Ball, and its frame
--   (f) the cap: units in any order and to the unit, all of them reported, in short stretches, a reading stopped at the
--       first report past its budget, designs past it TooComplex at once, the real designs at least 2 × under it

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Prop = require("../lib/Prop")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local Blueprints = require("../fixtures/Blueprints")
local H = require("./PhysicsHelpers")
local Brute = require("./CoverBrute")
local Attacks = require("./CoverAttacks")
local Plausible = require("./PlausibleDesigns")
local Balance = require("../../src/shared/Definitions/Balance")
local Mirror = require("../../src/shared/Blueprint/Mirror")
local Quat = require("../../src/shared/Blueprint/Quat")
local Analyze = require("../../src/shared/Physics/Analyze")
local Cover = require("../../src/shared/Physics/Cover")
local Sampling = require("../../src/shared/Physics/Sampling")
local Shapes = require("../../src/shared/Physics/Shapes")

-- Through a cast, as in Reference.spec: reference data, not game code.
local Fixtures: any = (require :: any)("../../docs/spec/prototypes/S2/v2/fixtures")
local Worst: any = (require :: any)("../../docs/spec/prototypes/S2/cover/worst_designs")

type Rng = TestRng.TestRng
type Prepared = Shapes.Prepared

local Geo = Balance.Geometry
local EXACT = 1e-9 -- a part's reading against the brute force, in share of its area, outside a tie (E-S2.12: 2.6e-13 at worst)
local TIE = 1e-11 -- the bracket: every moved half-space out and in by this much, a Ball's sphere for a circle grown and shrunk
-- a reading against the truth: the oracle's lattice; that and the round model's band, its spread included (a bar behind
-- slats reads 4.2 points under its truth, 0.4 without the spread)
local BAND_FLAT, BAND_ROUND = 0.003, 0.05

local function prepared(parts: { any }): { Prepared }
	local out: { Prepared } = table.create(#parts)
	for i, p in ipairs(parts) do
		out[i] = Shapes.prepare(p, i)
	end
	return out
end

-- The model of every part that hides: no exact copy of a part above it, no Dust.
local function models(parts: { Prepared }): { [number]: Cover.Model }
	local out: { [number]: Cover.Model } = {}
	local _, order = Sampling.ranked(parts)
	for r = 1, #order do
		local q = order[r]
		local copy = false
		for t = 1, r - 1 do
			copy = copy or Shapes.sameSolid(q, order[t])
		end
		if not copy and q.volume >= Geo.MIN_PART_VOLUME then
			out[q.index] = Cover.model(q)
		end
	end
	return out
end

-- Every hider's reading, whole: its shown area, against its hiders as Sampling hands them over.
local function readings(parts: { Prepared }): { [number]: number }
	local m = models(parts)
	local out: { [number]: number } = {}
	for i = 1, #parts do
		if m[i] then
			local _, higher, hm = H.hidersOf(parts, i, m)
			out[i] = (Cover.shown(m[i], hm, higher, math.huge, math.huge))
		end
	end
	return out
end

-- Model m with facet f alone, as a reading's target.
local function oneFacet(m: Cover.Model, f: number): Cover.Model
	local b = 6 * (f - 1)
	return {
		part = m.part, round = m.round, n = 1, poly = { m.poly[f] }, nx = { m.nx[f] }, ny = { m.ny[f] }, nz = { m.nz[f] },
		area = { m.area[f] }, box = { m.box[b + 1], m.box[b + 2], m.box[b + 3], m.box[b + 4], m.box[b + 5], m.box[b + 6] },
		spread = { m.spread[f] }, flat = { m.flat[f] }, hull = { m.hull[f] }, total = m.area[f], np = 0, planes = {}, sag = { if m.round then m.sag[f] else 0 },
		inner = 0, reach = m.reach, over = m.over, work = 0,
	}
end

-- (a): every hider of a design, read as Sampling hands its hiders over, against the brute force on Cover's own model with
-- every part that hides and no box test. Returns the parts checked, those a tie settled, and those past the brute force's
-- edge limit.
local function exactOn(parts: { Prepared }, what: string): (number, number, number)
	local m = models(parts)
	local b: { [number]: Brute.Model } = {}
	for i = 1, #parts do
		if m[i] then
			b[i] = Brute.fromCover(m[i])
		end
	end
	local checked, ties, past = 0, 0, 0
	for i = 1, #parts do
		if m[i] then
			local _, higher, hm = H.hidersOf(parts, i, m)
			local all, above = Brute.hiders(parts, i)
			local bh: { Brute.Model } = {}
			for k, j in ipairs(all) do
				bh[k] = b[j]
			end
			local brute: number? = 0
			for f = 1, m[i].n do
				local s = Brute.facetShown(b[i], f, bh, above)
				if s == nil then
					brute = nil
					break
				end
				brute = (brute :: number) + s
			end
			if brute == nil then
				past += 1
			else
				checked += 1
				local shown = Cover.shown(m[i], hm, higher, math.huge, math.huge)
				if math.abs(shown - brute) > EXACT * m[i].total then
					for f = 1, m[i].n do
						local lo = Brute.facetShown(b[i], f, bh, above, TIE)
						local hi = Brute.facetShown(b[i], f, bh, above, -TIE)
						if lo and hi then
							local c = Cover.shown(oneFacet(m[i], f), hm, higher, math.huge, math.huge)
							local tol = 1e-11 * m[i].area[f] + 1e-15
							A.truthy(c >= lo - tol and c <= hi + tol, what .. ", part " .. i .. ", facet " .. f .. ": " .. c .. " outside [" .. lo .. ", " .. hi .. "]")
						end
					end
					ties += 1
				end
			end
		end
	end
	return checked, ties, past
end

-- A tangle: n overlapping parts of every shape, faces against faces at offsets of 0, EPS_GEOM and its multiples, HIDE_OFFSET and
-- its neighbours, hairlines from 1e-9 to 1e-5, exact copies, round copies turned about their own symmetry, Dust, thin sheets.
-- No sword: the reading must be exact on any set of parts (the judge's tangles.luau, on TestRng).
local SHAPES = { "Block", "Block", "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }
local OFFSETS = { 0, 0, 0, 1e-7, -1e-7, 2e-7, -2e-7, 1e-8, -1e-8, 1.5e-8, -1.5e-8, 3e-8, -3e-8, 1e-9, -1e-9, 1e-6, -1e-6, 1e-5, -1e-5,
	0.012, -0.012, 0.0119999, 0.0120001, 0.012 + 1e-7, 0.012 - 1e-7, 0.001, -0.001, 0.05 }
local R = 0.70710678118654757
local AXIS_ROTS = { { 0, 0, 0, 1 }, { 0, 0, R, R }, { 0, R, 0, R }, { R, 0, 0, R }, { 0, 0, 1, 0 }, { 0.5, 0.5, 0.5, 0.5 } }

local function sized(shape: string, s: { number }): { number }
	if shape == "Ball" then
		local m = math.min(s[1], s[2], s[3])
		return { m, m, m }
	elseif shape == "Cylinder" then
		local m = math.min(s[2], s[3])
		return { s[1], m, m }
	end
	return s
end

local function tangle(rng: Rng): { any }
	local parts: { any } = {}
	local function add(shape: string, pos: { number }, rot: { number }, size: { number })
		table.insert(parts, H.solid(#parts + 1, shape, pos, rot, sized(shape, size)))
	end
	local function rsize(): { number }
		return { rng:range(0.02, 0.82), rng:range(0.02, 0.82), rng:range(0.02, 0.82) }
	end
	for k = 1, rng:int(3, 10) do
		local mode = rng:int(1, 10)
		local shape = rng:pick(SHAPES)
		if k == 1 or mode <= 3 then
			local rot = if rng:float() < 0.6 then rng:pick(AXIS_ROTS) else H.randomQuat(rng)
			add(shape, { rng:range(-0.3, 0.3), rng:range(-0.3, 0.3), rng:range(-0.3, 0.3) }, rot, rsize())
		elseif mode <= 7 then -- a face against a face of an earlier part, the same turn, at an offset of the list
			local host = rng:pick(parts)
			local axis = rng:int(1, 3)
			local side = if rng:float() < 0.5 then -1 else 1
			local size = sized(shape, rsize())
			local off = rng:pick(OFFSETS)
			local d = side * (host.size[axis] / 2 + size[axis] / 2 + off)
			if rng:float() < 0.25 then
				d = side * (host.size[axis] / 2 - size[axis] / 2 + off)
			end
			local l = { 0, 0, 0 }
			l[axis] = d
			for a = 1, 3 do
				if a ~= axis then
					l[a] = if rng:float() < 0.3 then (if rng:float() < 0.5 then -1 else 1) * (host.size[a] / 2 - size[a] / 2) + rng:pick(OFFSETS)
						else (rng:float() - 0.5) * host.size[a]
				end
			end
			local w = Quat.rotate(host.rot, l)
			add(shape, { host.pos[1] + w[1], host.pos[2] + w[2], host.pos[3] + w[3] }, table.clone(host.rot), size)
		elseif mode == 8 then -- an exact copy, a round copy turned about its symmetry, or a copy nudged
			local host = rng:pick(parts)
			local rot: { number }, pos: { number } = table.clone(host.rot), table.clone(host.pos)
			local r = rng:float()
			if r < 0.3 and (host.shape == "Cylinder" or host.shape == "Ball") then
				rot = Quat.hemisphere(Quat.normalize(Quat.mul(host.rot, H.axisAngle(1, 0, 0, rng:range(0, 90)))))
			elseif r < 0.6 then
				local a = rng:int(1, 3)
				pos[a] += rng:pick(OFFSETS)
			end
			table.insert(parts, H.solid(#parts + 1, host.shape, pos, rot, table.clone(host.size)))
		elseif mode == 9 then -- a Dust speck on a face
			local host = rng:pick(parts)
			add("Block", { host.pos[1] + host.size[1] / 2, host.pos[2], host.pos[3] }, H.I, { 0.05, 0.05, 0.05 })
		else -- a thin sheet over a face
			local host = rng:pick(parts)
			local axis = rng:int(1, 3)
			local size = { host.size[1] * rng:range(0.3, 1.3), host.size[2] * rng:range(0.3, 1.3), host.size[3] * rng:range(0.3, 1.3) }
			size[axis] = math.max(rng:pick({ 0.02, 0.013, 0.012, 0.011, 0.03 }), 0.02)
			local l = { 0, 0, 0 }
			l[axis] = host.size[axis] / 2 + size[axis] / 2 + rng:pick(OFFSETS)
			local w = Quat.rotate(host.rot, l)
			add("Block", { host.pos[1] + w[1], host.pos[2] + w[2], host.pos[3] + w[3] }, table.clone(host.rot), size)
		end
	end
	return parts
end

local function attackParts(d: any): { Prepared }
	return prepared(d.parts)
end

local function shuffled(rng: Rng, list: { any }): { any }
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = rng:int(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

-- A part's class among exact copies of one another: the parts whose solid is its.
local function copiesOf(parts: { any }, i: number): number
	local P = Shapes.prepare(parts[i], 1)
	local n = 0
	for j = 1, #parts do
		if Shapes.sameSolid(P, Shapes.prepare(parts[j], 2)) then
			n += 1
		end
	end
	return n
end

-- (a)'s designs: the F fixtures, C09 and the attack designs (the calibration and regression fixtures, P2–P5 and more tangles: slow).
local function exactOnDesigns(cores: { any }, what: string)
	local checked = 0
	for _, core in ipairs(cores) do
		checked += (exactOn(prepared(core.parts), what .. " " .. tostring(core.name)))
	end
	A.truthy(checked > 0, what .. ": parts checked")
end

local function exactOnTangles(count: number)
	local checked, ties, past = 0, 0, 0
	Prop.check(count, function(rng: Rng): any
		return tangle(rng)
	end, function(parts: any)
		local c, t, p = exactOn(prepared(parts), "a tangle")
		checked, ties, past = checked + c, ties + t, past + p
	end)
	A.truthy(checked > 4 * count, "parts checked: " .. checked .. " (ties " .. ties .. ", past the edge limit " .. past .. ")")
	A.truthy(past <= checked / 20, "most parts within the brute force's edge limit: " .. past)
end

return Test.suite("Physics/Cover", function(t)
	-- ── (a) exact on its model ───────────────────────────────────────────────────────────────────────────────────

	t.it("(a) exact on its model, against a brute force: the F fixtures, C09 and the attack designs", function()
		local cores: { any } = {}
		for _, id in ipairs(Blueprints.order) do
			table.insert(cores, Blueprints.core(id))
		end
		table.insert(cores, H.ornate())
		exactOnDesigns(cores, "fixture")
		exactOnDesigns(Attacks, "attack")
	end)

	-- A round part in a round hider is read by their true solids (§4.4): a hair inside, the part shows nothing, for one
	-- test's units; a hair out, it is not hidden whole, though its centre + r lies well inside (a rod's ends stand out, not
	-- its middle). Rods r 0.05 along (1, 1, 1)/√3 in a Ball r 0.3, their cap rims 2e-5 inside (the caps' hulls stand out:
	-- the part's own test hides them) or 1e-5 out; rods r 0.02 turned 30° in a Cylinder r 0.1 off the origin, a rim 2e-4
	-- under its cap or past it (more than the rim's 32-gon sags); Balls r 0.04 against a Cylinder's side, 2e-4 inside or
	-- 1e-5 out. Last, that rod in the Ball with its rims EPS_GEOM − 2e-10 out of the sphere, within the coincident band: its
	-- farthest point taken by its parts, not as sqrt(|d|² − a²), which on the axis line leaves about 1e-9 and reads it (V1).
	t.it("(a) exact on its model, against a brute force: round parts a hair inside and a hair out of round hiders", function()
		local S3 = 1 / math.sqrt(3)
		local diag = H.axisAngle(0, -1, 1, math.deg(math.acos(S3))) -- local X onto (1, 1, 1)/√3
		local tilt = Quat.hemisphere(Quat.normalize(Quat.mul(H.axisAngle(0, 0, 1, 90), H.axisAngle(0, 0, 1, -30)))) -- X 30° off +Y
		local designs: { { any } } = {}
		for _, e in ipairs({ 2e-4, -1e-5 }) do
			local hx = math.sqrt((0.3 - (if e > 0 then 2e-5 else e)) ^ 2 - 0.05 ^ 2)
			table.insert(designs, {
				H.solid(1, "Ball", { 0, 1, 0 }, H.I, { 0.6, 0.6, 0.6 }),
				H.solid(2, "Cylinder", { 0, 1, 0 }, diag, { 2 * hx, 0.1, 0.1 }),
			})
			local y = 1 + 0.3 - (if e > 0 then e else -2e-4) - 0.1 * math.cos(math.rad(30)) - 0.02 * math.sin(math.rad(30))
			table.insert(designs, {
				H.solid(1, "Cylinder", { 0.1, 1, 0 }, H.Z90, { 0.6, 0.2, 0.2 }),
				H.solid(2, "Cylinder", { 0.1, y, 0 }, tilt, { 0.2, 0.04, 0.04 }),
			})
			table.insert(designs, {
				H.solid(1, "Cylinder", { 0, 1, 0 }, H.Z90, { 0.6, 0.2, 0.2 }),
				H.solid(2, "Ball", { 0.1 - 0.04 - e, 1, 0 }, H.I, { 0.08, 0.08, 0.08 }),
			})
		end
		local onAxis = math.sqrt((0.3 + Geo.EPS_GEOM - 2e-10) ^ 2 - 0.05 ^ 2)
		table.insert(designs, {
			H.solid(1, "Ball", { 0, 1, 0 }, H.I, { 0.6, 0.6, 0.6 }),
			H.solid(2, "Cylinder", { 0, 1, 0 }, diag, { 2 * onAxis, 0.1, 0.1 }),
		})
		for k, parts in ipairs(designs) do
			local list = prepared(parts)
			local inside = k <= 3 or k == 7
			local reads = H.reads(list, 2)
			A.truthy(if inside then reads == 0 else reads > 0, "design " .. k .. ": the inner part reads " .. reads)
			exactOn(list, "design " .. k)
			if inside then
				-- its one test against the hider, reported: UNITS_PER_TEST
				local m = models(list)
				local _, higher, hm = H.hidersOf(list, 2, m)
				local reported = 0
				local _, used = Cover.shown(m[2], hm, higher, math.huge, math.huge, function(n: number)
					reported += n
				end)
				A.eq(used, 0.5, "design " .. k .. ": the part's own test")
				A.eq(reported, used, "design " .. k .. ": reported")
			end
		end
	end)

	-- A Cylinder in a Cylinder at any tilt (§4.4): its cap circles' farthest point from the hider's axis, exactly, where the
	-- caps' centres' distance + r stood up to r·(1 − cos) above it. Rods r 0.03, 0.2 long and pucks r 0.1, 0.1 long in a
	-- disk r 0.8 (a Cylinder along Z, 0.5 long, centred at c, then turned by T about c with all of them), tangent to its
	-- rim, then turned about the radius toward the disk's axis (a {turn, lean} of turns, in degrees: tilts from it of 90°
	-- down to 0°) and leaned about the tangent toward the radius, centred on the tangent point (written with their axis the
	-- other way) or 0.4 of their half length along their axis either way (the first or the second cap the farther), their
	-- farthest points 1e-9, EPS_GEOM ∓ 2e-10, 1e-6 and 0.01 r (their own) inside the disk's true side or out of it, by the
	-- brute force's bracket: each read with the disk ranking higher and lower, against the brute force at ±TIE; every one
	-- the rule holds (within EPS_GEOM of the side if the disk ranks higher, deeper if not) reads 0, for its test's units and
	-- 28 a cap circle its bounds leave open. The centred ones are also moved 2e-8 along their axis, one cap then a hair
	-- farther out than the other (at the middle turns both left open by their bounds, one held and the other not, which no
	-- reading that is not moved has), and read written either way, its caps in either order: the same reading and units
	-- (V2). Returns the readings checked, those held and their caps searched, and the units of every reading, held or not:
	-- the cap's outcome (V1).
	local function tiltedRods(T: { number }, c: { number }, turns: { { number } }): (number, number, number, number)
		local R, alpha, eps = 0.8, math.rad(30), Geo.EPS_GEOM
		local rx, ry = math.sin(alpha), math.cos(alpha)
		local t11, t12, t13, t21, t22, t23, t31, t32, t33 = Quat.toMatrix(T)
		local disk = Shapes.prepare(H.solid(1, "Cylinder", c, Quat.hemisphere(Quat.normalize(Quat.mul(T, H.Y90))), { 0.5, 2 * R, 2 * R }, "Guard"), 1)
		local dm = Cover.model(disk)
		local db = Brute.fromCover(dm)
		local checked, held, searched, units = 0, 0, 0, 0
		for _, size in ipairs({ { 0.03, 0.1 }, { 0.1, 0.05 } }) do
			local r, hx = size[1], size[2]
			for _, tl in ipairs(turns) do
				local turn, lean = tl[1], tl[2]
				local q0 = Quat.hemisphere(Quat.normalize(Quat.mul(H.axisAngle(-ry, rx, 0, lean), Quat.mul(H.axisAngle(rx, ry, 0, turn),
					H.axisAngle(0, 0, 1, math.deg(math.atan2(-rx, ry)))))))
				local nx, _, _, ny, _, _, nz = Quat.toMatrix(q0) -- its axis: the matrix's first column
				-- the part y0 along the radius and `along` along its axis, written `rot`, turned by T about c
				local function place(y0: number, along: number, rot: { number }): Prepared
					local ox, oy, oz = y0 * rx + along * nx, y0 * ry + along * ny, along * nz
					return Shapes.prepare(H.solid(2, "Cylinder", { c[1] + t11 * ox + t12 * oy + t13 * oz, c[2] + t21 * ox + t22 * oy + t23 * oz,
						c[3] + t31 * ox + t32 * oy + t33 * oz }, Quat.hemisphere(Quat.normalize(Quat.mul(T, rot))), { 2 * hx, 2 * r, 2 * r }), 2)
				end
				for v, shift in ipairs({ 0, 0.4 * hx, -0.4 * hx }) do
					local q = if v == 1 then Quat.hemisphere(Quat.normalize(Quat.mul(q0, { 0, 0, 1, 0 }))) else q0 -- its axis the other way
					for _, m in ipairs({ -1e-9, -(eps - 2e-10), -(eps + 2e-10), -1e-6, -0.01 * r, 1e-9, eps - 2e-10, eps + 2e-10, 1e-6, 0.01 * r }) do
						-- its farthest point m out of the side (m < 0: inside), by secant steps along the radius
						local y0 = R - r - 0.02
						local P = place(y0, shift, q)
						for _ = 1, 6 do
							local below, above = Brute.standsOut(P, disk)
							y0 += m - (below + above) / 2
							P = place(y0, shift, q)
						end
						local below, above = Brute.standsOut(P, disk)
						local pm = Cover.model(P)
						local pb = Brute.fromCover(pm)
						local what = string.format("r %.2f turned %g° and leaned %g°, shifted %.3f, %.1e out", r, turn, lean, shift, m)
						A.truthy(math.abs((below + above) / 2 - m) < 1e-12 and above - below < 1e-12, what .. ": placed, bracket [" .. below .. ", " .. above .. "]")
						if v == 1 then
							local a, b = Cover.model(place(y0, 2e-8, q0)), Cover.model(place(y0, 2e-8, q))
							for _, higher in ipairs({ true, false }) do
								local sa, ua = Cover.shown(a, { dm }, { higher }, math.huge, math.huge)
								local sb, ub = Cover.shown(b, { dm }, { higher }, math.huge, math.huge)
								A.truthy(ua == ub and math.abs(sa - sb) <= 1e-11 * a.total, what .. ", moved 2e-8, higher " .. tostring(higher) .. ": " .. sa
									.. " for " .. ua .. " units one way, " .. sb .. " for " .. ub .. " the other")
							end
						end
						for _, higher in ipairs({ true, false }) do
							local limit = if higher then eps else -eps
							local inside = if higher then above <= limit else above < limit
							local outside = if higher then below > limit else below >= limit
							A.truthy(inside ~= outside, what .. ": the bracket settles the rule")
							local shown, used = Cover.shown(pm, { dm }, { higher }, math.huge, math.huge)
							units += used
							local lo: number?, hi: number? = 0, 0
							for f = 1, pm.n do
								local a, b = Brute.facetShown(pb, f, { db }, { higher }, TIE), Brute.facetShown(pb, f, { db }, { higher }, -TIE)
								lo, hi = if lo and a then lo + a else nil, if hi and b then hi + b else nil
							end
							if lo and hi then
								checked += 1
								local tol = 1e-11 * pm.total + 1e-15
								A.truthy(shown >= lo - tol and shown <= hi + tol, what .. ", higher " .. tostring(higher) .. ": " .. shown .. " outside [" .. lo .. ", " .. hi .. "]")
							end
							if inside then
								held += 1
								A.eq(shown, 0, what .. ", higher " .. tostring(higher) .. ": held, reads 0")
								A.truthy(used == 0.5 or used == 28.5 or used == 56.5, what .. ": its test's units " .. used)
								searched += (used - 0.5) / 28
							end
						end
					end
				end
			end
		end
		return checked, held, searched, units
	end

	t.it("(a) exact on its model, against a brute force: tilted rods and pucks in a Cylinder, a hair inside and out, both ranks", function()
		local checked, held, searched, units = tiltedRods(H.I, { 0, 2, 0 }, { { 0, 0 }, { 2, 0 }, { 30, 0 }, { 60, 0 }, { 88, 0 }, { 90, 0 } })
		A.truthy(checked == 720 and held == 360 and searched == 136, "checked " .. checked .. ", held " .. held .. ", caps searched " .. searched)
		A.eq(units, 709562, "the readings' units")
	end)

	-- The same where a slip in the search's frame or bounds, or a parallel cut too coarse, would show (V1: every search
	-- above runs against a disk along Z centred on x = z = 0, where a wrong term in X or Y of its axis drops out): the disk
	-- turned 37° about (1, 2, 3) and off the origin, so that no component of its axis, its centre or the rods' axes is 0;
	-- and rods along the disk's axis leaned 0.03° and 0.0046° toward its radius (5.2e-4 and 8e-5 rad). At 0.03° the bounds
	-- leave the pucks' caps open, where a cut taking the axes as parallel would stand r·(1 − cos) = 1.4e-8 above the rim,
	-- past the 2e-10 margins; at 0.0046° they differ by under 1e-10 and decide every test. The caps searched and the units
	-- are counted to the cap, so that a search charged wrongly, or bounds that leave more caps open, show.
	t.slow("(a) exact on its model, against a brute force: tilted rods in a turned Cylinder, and near its axis", function()
		local c1, h1, s1, u1 = tiltedRods(Quat.hemisphere(Quat.normalize(H.axisAngle(1, 2, 3, 37))), { 0.13, 2.07, -0.11 },
			{ { 2, 0 }, { 60, 0 }, { 90, 0.03 }, { 90, 0.0046 } })
		local c2, h2, s2, u2 = tiltedRods(H.I, { 0, 2, 0 }, { { 90, 0.03 }, { 90, 0.0046 } })
		A.truthy(c1 == 480 and h1 == 240 and s1 == 78 and c2 == 240 and h2 == 120 and s2 == 6,
			"checked " .. c1 .. " and " .. c2 .. ", held " .. h1 .. " and " .. h2 .. ", caps searched " .. s1 .. " and " .. s2)
		A.truthy(u1 == 478107 and u2 == 226227, "the readings' units " .. u1 .. " and " .. u2)
	end)

	-- The same at its caps (V1: a slip in X of the centres' offset along the hider's axis survived the suite: at the turned
	-- disk's side it moves the rods 0.09 along its axis, which leaves them inside its caps): rods and pucks as above, 0.4
	-- along the same radius, turned 90° and 60° (along the disk's axis and 30° off it), moved along the axis until their
	-- farthest points stand 1e-9, EPS_GEOM ∓ 2e-10, 1e-6 and 0.01 r inside either cap or out of it, by the brute force's
	-- bracket: each read with the disk ranking higher and lower, against the brute force at ±TIE; every one the rule holds
	-- reads 0, for its one test's units (both caps' bounds hold). The disk's centre added in any term of that offset moves
	-- the parts by twice that term of c·u along the axis, −0.09, 0.31 and 0.20 in X, Y and Z, so that under one cap or the
	-- other the parts held are read facet by facet, or those out of it read 0. The units of every reading are counted too:
	-- at 60° a part a hair out reads 0 on its model, whose caps' 32-gons stand under its rims' farthest points.
	t.it("(a) exact on its model, against a brute force: rods and pucks at a turned Cylinder's caps, a hair inside and out, both ranks", function()
		local T, c = Quat.hemisphere(Quat.normalize(H.axisAngle(1, 2, 3, 37))), { 0.13, 2.07, -0.11 }
		local alpha, eps = math.rad(30), Geo.EPS_GEOM
		local rx, ry = math.sin(alpha), math.cos(alpha)
		local t11, t12, t13, t21, t22, t23, t31, t32, t33 = Quat.toMatrix(T)
		local disk = Shapes.prepare(H.solid(1, "Cylinder", c, Quat.hemisphere(Quat.normalize(Quat.mul(T, H.Y90))), { 0.5, 1.6, 1.6 }, "Guard"), 1)
		local dm = Cover.model(disk)
		local db = Brute.fromCover(dm)
		local checked, held, units = 0, 0, 0
		for _, size in ipairs({ { 0.03, 0.1 }, { 0.1, 0.05 } }) do
			local r, hx = size[1], size[2]
			for _, turn in ipairs({ 90, 60 }) do
				local rot = Quat.hemisphere(Quat.normalize(Quat.mul(T, Quat.mul(H.axisAngle(rx, ry, 0, turn),
					H.axisAngle(0, 0, 1, math.deg(math.atan2(-rx, ry)))))))
				-- the part 0.4 along the radius and z along the disk's axis, turned by T about c
				local function place(z: number): Prepared
					local ox, oy = 0.4 * rx, 0.4 * ry
					return Shapes.prepare(H.solid(2, "Cylinder", { c[1] + t11 * ox + t12 * oy + t13 * z, c[2] + t21 * ox + t22 * oy + t23 * z,
						c[3] + t31 * ox + t32 * oy + t33 * z }, rot, { 2 * hx, 2 * r, 2 * r }), 2)
				end
				for _, side in ipairs({ 1, -1 }) do
					for _, m in ipairs({ -1e-9, -(eps - 2e-10), -(eps + 2e-10), -1e-6, -0.01 * r, 1e-9, eps - 2e-10, eps + 2e-10, 1e-6, 0.01 * r }) do
						-- its farthest point m out of the cap (m < 0: inside), by secant steps along the axis
						local z = side * 0.1
						local P = place(z)
						for _ = 1, 3 do
							local below, above = Brute.standsOut(P, disk)
							z += side * (m - (below + above) / 2)
							P = place(z)
						end
						local below, above = Brute.standsOut(P, disk)
						local pm = Cover.model(P)
						local pb = Brute.fromCover(pm)
						local what = string.format("r %.2f turned %g° at cap %+d, %.1e out", r, turn, side, m)
						A.truthy(math.abs((below + above) / 2 - m) < 1e-12 and above - below < 1e-12, what .. ": placed, bracket [" .. below .. ", " .. above .. "]")
						for _, higher in ipairs({ true, false }) do
							local limit = if higher then eps else -eps
							local inside = if higher then above <= limit else above < limit
							local outside = if higher then below > limit else below >= limit
							A.truthy(inside ~= outside, what .. ": the bracket settles the rule")
							local shown, used = Cover.shown(pm, { dm }, { higher }, math.huge, math.huge)
							units += used
							local lo: number?, hi: number? = 0, 0
							for f = 1, pm.n do
								local a, b = Brute.facetShown(pb, f, { db }, { higher }, TIE), Brute.facetShown(pb, f, { db }, { higher }, -TIE)
								lo, hi = if lo and a then lo + a else nil, if hi and b then hi + b else nil
							end
							if lo and hi then
								checked += 1
								local tol = 1e-11 * pm.total + 1e-15
								A.truthy(shown >= lo - tol and shown <= hi + tol, what .. ", higher " .. tostring(higher) .. ": " .. shown .. " outside [" .. lo .. ", " .. hi .. "]")
							end
							if inside then
								held += 1
								A.eq(shown, 0, what .. ", higher " .. tostring(higher) .. ": held, reads 0")
								A.eq(used, 0.5, what .. ", higher " .. tostring(higher) .. ": its one test's units")
							end
						end
					end
				end
			end
		end
		A.truthy(checked == 160 and held == 80, "checked " .. checked .. ", held " .. held)
		A.eq(units, 216225, "the readings' units")
	end)

	-- A flat face against a Ball reads the Ball's true sphere, on the 32-gon round the circle its plane cuts (§4.4): a Block's
	-- top cutting a Ball r 0.3 at every height from its centre to past its pole (through the centre, near it, halfway, where
	-- the probe's plane passes the pole within EPS_GEOM, within 1e-6 and EPS_GEOM of tangent, missing it), the Block larger
	-- and smaller than the Ball (the buried test's margin both ways); then turned Blocks, Wedges, CornerWedges and a
	-- Cylinder's caps cutting it anywhere.
	t.it("(a) exact on its model, against a brute force: flat faces cutting a Ball at every height, both ranks, near tangent", function()
		local R, eps, delta = 0.3, Geo.EPS_GEOM, Geo.HIDE_OFFSET
		local checked = 0
		for _, h in ipairs({ 0, 0.05, -0.05, 0.15, 0.29, R - delta - eps, R - delta, R - delta + eps, R - 1e-6, R - eps, R, R + eps,
			R + 2 * eps, R + 1e-6 }) do
			for _, w in ipairs({ 0.9, 0.2 }) do -- larger than the Ball, then smaller
				local list = prepared({
					H.solid(1, "Ball", { 0, 1, 0 }, H.I, { 2 * R, 2 * R, 2 * R }),
					H.solid(2, "Block", { 0.013, 1 + h - 0.1, -0.007 }, H.I, { w, 0.2, w }),
				})
				checked += (exactOn(list, "a Block's top " .. h .. " over the centre, " .. w .. " wide"))
			end
		end
		local rng = TestRng.new(Prop.baseSeed)
		for _ = 1, 40 do
			local shape = rng:pick({ "Block", "Block", "Wedge", "CornerWedge", "Cylinder" })
			local size = sized(shape, { rng:range(0.05, 0.7), rng:range(0.05, 0.7), rng:range(0.05, 0.7) })
			local d, x, y, z = rng:range(0, R + 0.2), rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1)
			local l = math.sqrt(x * x + y * y + z * z)
			local list = prepared({
				H.solid(1, "Ball", { 0, 1, 0 }, H.I, { 2 * R, 2 * R, 2 * R }),
				H.solid(2, shape, { d * x / l, 1 + d * y / l, d * z / l }, H.randomQuat(rng), size),
			})
			checked += (exactOn(list, "a turned " .. shape))
		end
		A.truthy(checked >= 2 * 28 + 2 * 40 - 4, "parts checked: " .. checked)
	end)

	t.it("(a) exact on its model, against a brute force: 40 tangles of overlapping, near-touching parts of every shape", function()
		exactOnTangles(40)
	end)

	t.slow("(a) exact on its model: the calibration and regression fixtures, P2–P5, and 600 tangles", function()
		local cores: { any } = {}
		for _, set in ipairs({ Fixtures.calibration(), Fixtures.regression(), Fixtures.perf() }) do
			for _, b in ipairs(set) do
				if b.parts and string.sub(b.name, 1, 2) ~= "P1" then
					table.insert(cores, b)
				end
			end
		end
		exactOnDesigns(cores, "fixture")
		exactOnTangles(600)
	end)

	-- ── (b) the closed forms ─────────────────────────────────────────────────────────────────────────────────────

	t.it("(b) what shows of the plate under lids, to 6 decimals of its closed form, kept or cleaned", function()
		local function pct(lids: { { number } }): number
			return 100 * H.reads(H.underLids(lids), 1)
		end
		local function kept(lids: { { number } }): boolean
			return Sampling.exposure(H.underLids(lids)).kept[1]
		end
		local s, FAR = 0.008, 0.5
		local ring = { { -0.25 + s, 0.25 - s, -0.25 + s, 0.25 - s } }
		A.near(pct(ring), 2.915520, 5e-7, "a strip 0.008 all round")
		A.truthy(kept(ring), "kept")
		local three = { { -0.25 + s, 0.25 - s, -FAR, 0.25 - s } }
		A.near(pct(three), 2.198491, 5e-7, "the strip on 3 sides")
		A.truthy(kept(three), "kept")
		A.near(pct({ { -0.248, 0.248, -0.248, 0.248 } }), 0.737741, 5e-7, "a hair 0.002 all round")
		A.near(pct({ { -0.249, 0.249, -0.249, 0.249 } }), 0.369593, 5e-7, "a hair 0.001 all round")
		for _, def in ipairs({ { 0.03, 2.777759 }, { 0.00001, 0.000907 } }) do
			local g = def[1]
			A.near(pct({ { -FAR, 0.0625 - g / 2, -FAR, FAR }, { 0.0625 + g / 2, FAR, -FAR, FAR } }), def[2], 5e-7, "a slit " .. g)
		end
		local x0, x1 = 0.0625 + 0.26 * 0.0625, 0.0625 + 0.74 * 0.0625
		A.near(pct({ { -FAR, x0, -FAR, FAR }, { x1, FAR, -FAR, FAR }, { x0, x1, -FAR, x0 }, { x0, x1, x1, FAR } }), 0.166664, 5e-7, "a window")
		-- the laminated core of Verdict.spec: its proud rims, 5.540 %
		local parts = prepared({
			H.part(1, "Pommel", "Ball", "Iron", { 0, 0.3, 0 }, H.I, { 0.3, 0.3, 0.3 }),
			H.part(2, "Grip", "Cylinder", "Iron", { 0, 0.88, 0 }, H.Z90, { 0.9, 0.16, 0.16 }),
			H.part(3, "Guard", "Block", "Iron", { 0, 1.4, 0 }, H.I, { 1.1, 0.16, 0.3 }),
			H.part(4, "Blade", "Block", "Iron", { 0, 2.45, 0.0225 }, H.I, { 1, 2, 0.025 }),
			H.part(5, "Blade", "Block", "Iron", { 0, 2.45, -0.0225 }, H.I, { 1, 2, 0.025 }),
			H.part(6, "Blade", "Block", "Iron", { 0, 3.47, 0 }, H.I, { 1, 0.04, 0.07 }),
			H.part(7, "Blade", "Block", "Steel", { 0, 2.45, 0 }, H.I, { 1.04, 2, 0.02 }),
		})
		A.near(100 * H.reads(parts, 7), 5.540, 5e-4, "the laminated core")
	end)

	-- ── (c) the attack designs ───────────────────────────────────────────────────────────────────────────────────

	t.it("(c) the attack designs read their truth: the truth's verdict, the share within the model's band", function()
		A.truthy(#Attacks >= 15, "designs: " .. #Attacks)
		for _, d in ipairs(Attacks) do
			local parts = attackParts(d)
			local target = parts[d.target]
			local band = if target.code == Shapes.CYLINDER or target.code == Shapes.BALL then BAND_ROUND else BAND_FLAT
			A.eq(Sampling.exposure(parts).kept[d.target], d.kept, d.name .. ": the truth's verdict")
			A.near(H.reads(parts, d.target), d.truth, band, d.name .. ": the share")
		end
	end)

	-- T-PHY-09's copies: a Cylinder spun about its axis, a Ball turned any way, are their originals to the model
	t.it("(c) a round copy spun or turned about its own symmetry is hidden by its original, which shows whole", function()
		local cylinder = H.solid(1, "Cylinder", { 0, 2, 0 }, H.Z90, { 0.6, 0.24, 0.24 })
		local spun = H.solid(2, "Cylinder", { 0, 2, 0 }, Quat.hemisphere(Quat.mul(H.Z90, H.axisAngle(1, 0, 0, 37))), { 0.6, 0.24, 0.24 })
		local ball = H.solid(1, "Ball", { 0, 2, 0 }, H.I, { 0.3, 0.3, 0.3 })
		local turned = H.solid(2, "Ball", { 0, 2, 0 }, H.axisAngle(1, 2, 3, 77), { 0.3, 0.3, 0.3 })
		for _, pair in ipairs({ { cylinder, spun }, { ball, turned }, { spun, cylinder }, { turned, ball } }) do
			local parts = prepared(pair)
			local first = H.reads(parts, 1)
			local second = H.reads(parts, 2)
			A.near(math.min(first, second), 0, 1e-12, pair[1].shape .. ": one of the 2 reads nothing")
			A.near(math.max(first, second), 1, 1e-12, pair[1].shape .. ": the other its whole model")
			A.eq(#Sampling.exposure(parts).cleaned, 1, pair[1].shape .. ": one cleaned")
		end
	end)

	-- A Cylinder whose axis has its two smallest components equal (two 45° snaps) is framed by its axis's last bits, so a
	-- copy spun about it has another model, and read up to about half on its original's (41.8 % for two 0.6 × 0.24 rods
	-- spun 38°, 47.3 % for 1.0 × 0.12 spun 172°). Its true solid lies in its original's, which ranks higher: it reads
	-- nothing (§4.4).
	t.it("(c) a copy spun about a tied axis reads nothing: its true solid lies in its original's", function()
		local snap = Quat.hemisphere(Quat.normalize(Quat.mul(H.axisAngle(0, 1, 0, -45), H.axisAngle(0, 0, 1, 45))))
		for _, def in ipairs({ { 0.6, 0.24, 38 }, { 1.0, 0.12, 172 } }) do
			local size = { def[1], def[2], def[2] }
			local spun = Quat.hemisphere(Quat.normalize(Quat.mul(snap, H.axisAngle(1, 0, 0, def[3]))))
			local parts = prepared({ H.solid(1, "Cylinder", { 0, 2, 0 }, snap, size, "Blade"), H.solid(2, "Cylinder", { 0, 2, 0 }, spun, size, "Guard") })
			A.eq(H.reads(parts, 2), 0, def[1] .. " × " .. def[2] .. ": the copy")
			A.truthy(H.reads(parts, 1) > 0.5, def[1] .. " × " .. def[2] .. ": the original shows more than half")
			A.eq(#Sampling.exposure(parts).cleaned, 1, "one cleaned")
		end
	end)

	-- V1's caged-Ball swords: a Ball in the blade of a valid 23-part sword, sealed by 6 walls 0.02 thick g off it and 12 edge
	-- blocks that meet past ±b. A Ball d 0.4, g 0.002769, b 0.051018: its facets probe HIDE_OFFSET + their sag (up to 0.0234
	-- past their own boxes), so the walls lie within its probe though past a facet's box grown by HIDE_OFFSET alone, where a
	-- box test that short read 2.345 % and kept it; every wall a hider, it reads 0.447 % without the spread, 0.000 % with it
	-- (the truth 0.502 %). A Ball d 0.16, g 0.00537, b 0.0302, in a blade 0.05 thick: its facets probe along their normals
	-- past the edge blocks where its true points' radial probes meet them, 2.330 % without the spread and kept (Hammering
	-- 0.1548 Normal through the emulator, the truth's row 0.2020 Hard); 0.000 % with it (the truth 1.93 %), cleaned.
	local function cagedSword(r: number, g: number, b: number, thick: number): { any }
		local c = { 0, 2.4, 0 }
		local wall, span, E = 0.02, 2 * r + 0.1, r + 0.06
		local low, high = c[2] - (r + g + wall), c[2] + (r + g + wall)
		local parts: { any } = {
			H.part(1, "Grip", "Block", "Iron", { 0, 0.75, 0 }, H.I, { 0.16, 0.9, 0.16 }),
			H.part(2, "Guard", "Block", "Iron", { 0, 1.29, 0 }, H.I, { 1, 0.18, 0.24 }),
			H.part(3, "Blade", "Block", "Iron", { 0, (1.38 + low) / 2, 0 }, H.I, { 0.16, low - 1.38, thick }),
			H.part(4, "Blade", "Block", "Iron", { 0, (high + 4) / 2, 0 }, H.I, { 0.16, 4 - high, thick }),
			H.part(5, "Blade", "Ball", "Iron", c, H.I, { 2 * r, 2 * r, 2 * r }),
		}
		local wallSlots = { "Blade", "Blade", "Blade", "Blade", "Blade", "Pommel" }
		for a = 1, 3 do
			for _, s in ipairs({ -1, 1 }) do
				local pos, size = table.clone(c), { span, span, span }
				pos[a] += s * (r + g + wall / 2)
				size[a] = wall
				table.insert(parts, H.part(#parts + 1, wallSlots[#parts - 4], "Block", "Iron", pos, H.I, size))
			end
		end
		local edgeSlots = { "Blade", "Blade", "Blade", "Blade", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Grip" }
		for a = 1, 3 do
			for o = a + 1, 3 do
				for _, sa in ipairs({ -1, 1 }) do
					for _, so in ipairs({ -1, 1 }) do
						-- past +b or short of −b along a and o, all of ±E along the third axis
						local lo, hi = { -E, -E, -E }, { E, E, E }
						lo[a], hi[a] = if sa > 0 then b else -E, if sa > 0 then E else -b
						lo[o], hi[o] = if so > 0 then b else -E, if so > 0 then E else -b
						local pos, size = {}, {}
						for k = 1, 3 do
							pos[k], size[k] = c[k] + (lo[k] + hi[k]) / 2, hi[k] - lo[k]
						end
						table.insert(parts, H.part(#parts + 1, edgeSlots[#parts - 10], "Block", "Iron", pos, H.I, size))
					end
				end
			end
		end
		return parts
	end

	t.it("(c) a Ball sealed in walls its own probe reaches, or caged beside its facets, in a valid sword: Enclosed", function()
		for _, def in ipairs({ { 0.2, 0.002769, 0.051018, 0.06 }, { 0.08, 0.00537, 0.0302, 0.05 } }) do
			local parts = cagedSword(def[1], def[2], def[3], def[4])
			local what = "the caged Ball r " .. def[1]
			A.eq(#parts, 23, "23 parts")
			A.truthy(Analyze.run(H.core("caged Ball", parts)).validation.ok, what .. ": a valid sword")
			local P = prepared(parts)
			exactOn(P, what)
			A.near(100 * H.reads(P, 5), 0, 5e-4, what .. " reads its hide test")
			A.falsy(Sampling.exposure(P).kept[5], what .. ": Enclosed")
		end
	end)

	-- (a) reads every part against H.hidersOf, a copy of Sampling's choice of hiders; these read Sampling's own. A Cylinder
	-- r 0.4 along Z hovers 0.013 over a window 0.1052 wide in the lids on the plate, a corner of its 32-gon down: its box is
	-- past HIDE_OFFSET + 2·EPS_GEOM from the plate's but within its over (0.002), so its sides' half-spaces moved out by
	-- their sag, which meet 0.0019 under it there, reach the plate's probe and hide a strip of the window. Handed over, the
	-- plate reads 1.679 % and is cleaned; a reach of HIDE_OFFSET alone would read the window whole, 2.049 %, and keep it,
	-- as the truth does (a flat face reads a Cylinder on its prism, §17.2). A Ball r 0.4 hovering 0.015 over the window hid a
	-- piece of it the same way on its half-spaces moved out (1.280 %, cleaned); a flat face reads a Ball's true sphere,
	-- which lies past the probe here: the window whole, to the bit what the plate reads with no Ball.
	t.it("(c) Sampling hands over a round hider within its over: a Cylinder hovering over a window in the lids", function()
		local c, w, r = 0.0625, 0.1052, 0.4
		local x0, x1, FAR = c - w / 2, c + w / 2, 0.5
		local lids = { { -FAR, x0, -FAR, FAR }, { x1, FAR, -FAR, FAR }, { x0, x1, -FAR, x0 }, { x0, x1, x1, FAR } }
		local parts = H.partsUnder(lids)
		table.insert(parts, H.solid(#parts + 1, "Cylinder", { c, r + 0.013, c }, H.axisAngle(0, 1, 0, 90), { 0.6, 2 * r, 2 * r }))
		local P = prepared(parts)
		A.falsy(Shapes.aabbOverlap(P[1], P[#P], Geo.HIDE_OFFSET + 2 * Geo.EPS_GEOM), "past HIDE_OFFSET from the plate's box")
		exactOn(P, "the hovering Cylinder")
		A.near(100 * H.reads(P, 1), 1.679, 5e-4, "the plate reads what the model's probe leaves")
		A.falsy(Sampling.exposure(P).kept[1], "Enclosed")
		local ball = H.partsUnder(lids)
		table.insert(ball, H.solid(#ball + 1, "Ball", { c, r + 0.015, c }, H.I, { 2 * r, 2 * r, 2 * r }))
		local Q = prepared(ball)
		exactOn(Q, "the hovering Ball")
		A.eq(H.reads(Q, 1), H.reads(prepared(H.partsUnder(lids)), 1), "under the Ball, the window whole")
		A.truthy(Sampling.exposure(Q).kept[1], "kept")
	end)

	-- Sampling's verdict is the one every part asked would give: a Block walled 0.005 off on 5 sides and HIDE_OFFSET − EPS_GEOM/2
	-- on the 6th, which a reach of HIDE_OFFSET less 2·EPS_GEOM leaves out; a plate framed but for a window 0.05 wide under a
	-- Cylinder r 0.4 along Z, a corner of its 32-gon down, whose bottom stands HIDE_OFFSET + 0.0005 above it, within the
	-- Cylinder's over, which a reach without the over leaves out (handed over, the plate reads 1.629 % and is cleaned; left
	-- out, 3.906 %, kept). Under a Ball r 0.3 there it read 0.079 % on the Ball's half-spaces moved out; a flat face reads a
	-- Ball's sphere, past the probe here, and the plate its window whole, 3.906 % (truly 3.907 %).
	t.it("(c) Sampling asks every part that can hide: a wall HIDE_OFFSET − EPS/2 off, a framed plate under a Cylinder's edge", function()
		local function withAll(parts: { Prepared }): { boolean }
			local rank, order = Sampling.ranked(parts)
			local all: { Cover.Model } = {}
			for i = 1, #parts do
				all[i] = Cover.model(parts[i])
			end
			local out: { boolean } = {}
			for i = 1, #parts do
				local hm: { Cover.Model }, higher: { boolean } = {}, {}
				for k = 1, #order do
					local j = order[k].index
					if j ~= i then
						table.insert(hm, all[j])
						table.insert(higher, k < rank[i])
					end
				end
				out[i] = Cover.shown(all[i], hm, higher, math.huge, math.huge) >= Geo.ENCLOSED_EXPOSED_MAX * all[i].total
			end
			return out
		end
		local walls: { any } = { H.solid(1, "Block", { 0, 0, 0 }, H.I, { 0.4, 0.4, 0.4 }) }
		local gaps = { 0.005, 0.005, 0.005, 0.005, 0.005, Geo.HIDE_OFFSET - Geo.EPS_GEOM / 2 }
		local axes = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 0, 1 }, { 0, 0, -1 }, { 0, -1, 0 }, { 0, 1, 0 } }
		for k = 1, 6 do
			local u, d = axes[k], 0.2 + gaps[k] + 0.025
			local size = { 0.6, 0.6, 0.6 }
			for a = 1, 3 do
				if u[a] ~= 0 then
					size[a] = 0.05
				end
			end
			table.insert(walls, H.solid(k + 1, "Block", { u[1] * d, u[2] * d, u[3] * d }, H.I, size))
		end
		local window: { any } = {
			H.solid(1, "Block", { 0, -0.01, 0 }, H.I, { 0.16, 0.02, 0.16 }),
			H.solid(2, "Block", { 0, -0.07, 0 }, H.I, { 0.5, 0.1, 0.5 }),
		}
		for _, s in ipairs({ -1, 1 }) do
			table.insert(window, H.solid(#window + 1, "Block", { s * 0.105, -0.01, 0 }, H.I, { 0.04, 0.04, 0.26 }))
			table.insert(window, H.solid(#window + 1, "Block", { 0, -0.01, s * 0.105 }, H.I, { 0.26, 0.04, 0.04 }))
			table.insert(window, H.solid(#window + 1, "Block", { 0, 0.025, s * 0.0525 }, H.I, { 0.16, 0.04, 0.055 }))
			table.insert(window, H.solid(#window + 1, "Block", { s * 0.0525, 0.055, 0 }, H.I, { 0.055, 0.1, 0.05 }))
		end
		table.insert(window, H.solid(#window + 1, "Cylinder", { 0, Geo.HIDE_OFFSET + 0.0005 + 0.4, 0 }, H.axisAngle(0, 1, 0, 90), { 0.6, 0.8, 0.8 }))
		for _, design in ipairs({ walls, window }) do
			local P = prepared(design)
			local kept, all = Sampling.exposure(P).kept, withAll(P)
			for i = 1, #P do
				A.eq(kept[i], all[i], "part " .. i .. " of " .. #P)
			end
		end
	end)

	-- ── (d) what it does not depend on ───────────────────────────────────────────────────────────────────────────

	-- By part id: any order gives every reading the same bits. Exact copies of one solid compare as a class: which of them the
	-- index keeps is the rank's last key (§4.4).
	local function sameInAnyOrder(rng: Rng, parts: { any }, what: string)
		local base = readings(prepared(parts))
		for _ = 1, 3 do
			local order = shuffled(rng, parts)
			local now = readings(prepared(order))
			for k, p in ipairs(order) do
				local i = table.find(parts, p) :: number
				if copiesOf(parts, i) == 1 then
					A.eq(now[k], base[i], what .. ": part " .. p.id .. "'s reading")
				end
			end
		end
	end

	t.it("(d) any order of the parts: every reading the same bits, tangles and attack designs", function()
		Prop.check(40, function(rng: Rng): any
			return { parts = tangle(rng), seed = rng:u32() }
		end, function(c: any)
			sameInAnyOrder(TestRng.new(c.seed), c.parts, "a tangle")
		end)
		local rng = TestRng.new(Prop.baseSeed)
		for _, d in ipairs(Attacks) do
			sameInAnyOrder(rng, d.parts, d.name)
		end
	end)

	-- The image across the centre plane X or Z: its parts read what the original's do, to rounding, and keep the same verdicts.
	-- True twins (one part the image of another) swap who keeps a face they share: their readings swap, their verdicts too.
	local function mirrored(parts: { any }, plane: any, what: string)
		local images: { any } = {}
		for i, p in ipairs(parts) do
			images[i] = Mirror.reflect(p, plane)
		end
		local P, Q = prepared(parts), prepared(images)
		local a, b = readings(P), readings(Q)
		local ka, kb = Sampling.exposure(P).kept, Sampling.exposure(Q).kept
		for i = 1, #parts do
			local twin = false
			for j = 1, #parts do
				if j ~= i and Shapes.sameSolid(Q[j], P[i]) then
					twin = true
				end
			end
			if not twin then
				A.eq(kb[i], ka[i], what .. " across " .. plane .. ": part " .. i .. "'s verdict")
				if a[i] then
					A.near(b[i] / Q[i].area, a[i] / P[i].area, 1e-9, what .. " across " .. plane .. ": part " .. i .. "'s reading")
				end
			end
		end
	end

	-- one case a plane: the two together come near a fast case's budget on a busy machine
	for _, plane in ipairs({ "X", "Z" } :: { any }) do
		t.it("(d) a mirror image across " .. plane .. " reads the original's, part for part: fixtures, C09, attack designs", function()
			for _, id in ipairs(Blueprints.order) do
				mirrored(Blueprints.core(id).parts, plane, id)
			end
			mirrored(H.ornate().parts, plane, "C09")
			for _, d in ipairs(Attacks) do
				mirrored(d.parts, plane, d.name)
			end
		end)
	end

	t.it("(d) an exact copy first or last, a Dust speck on a face: every other reading the same bits", function()
		Prop.check(40, function(rng: Rng): any
			local parts = tangle(rng)
			return { parts = parts, pick = rng:int(1, #parts) }
		end, function(c: any)
			local parts = c.parts
			local base = readings(prepared(parts))
			local p = parts[c.pick]
			local copy = table.clone(p)
			copy.id = 99
			local speck = H.solid(98, "Block", { p.pos[1] + p.size[1] / 2, p.pos[2], p.pos[3] }, H.I, { 0.05, 0.05, 0.05 })
			local first, last, dusted = { copy }, {}, {}
			for _, q in ipairs(parts) do
				table.insert(first, q)
				table.insert(last, q)
				table.insert(dusted, q)
			end
			table.insert(last, copy)
			table.insert(dusted, speck)
			local a, b, d = readings(prepared(first)), readings(prepared(last)), readings(prepared(dusted))
			for i = 1, #parts do
				if not Shapes.sameSolid(Shapes.prepare(parts[i], 1), Shapes.prepare(p, 2)) then
					A.eq(a[i + 1], base[i], "a copy first: part " .. i)
					A.eq(b[i], base[i], "a copy last: part " .. i)
				end
				A.eq(d[i], base[i], "a speck: part " .. i)
			end
			A.eq(d[#dusted], nil, "the speck has no reading: Dust")
		end)
	end)

	-- ── (e) the model ────────────────────────────────────────────────────────────────────────────────────────────

	-- Every vertex of a model, sorted, for set comparisons.
	local function vertices(m: Cover.Model): { { number } }
		local out: { { number } } = {}
		for f = 1, m.n do
			local poly = m.poly[f]
			for k = 1, #poly, 3 do
				table.insert(out, { poly[k], poly[k + 1], poly[k + 2] })
			end
		end
		table.sort(out, function(p: { number }, q: { number }): boolean
			for c = 1, 3 do
				if math.abs(p[c] - q[c]) > 1e-9 then
					return p[c] < q[c]
				end
			end
			return false
		end)
		return out
	end
	local function sameSet(a: { { number } }, b: { { number } }, tol: number, what: string)
		A.eq(#a, #b, what .. ": as many vertices")
		for k = 1, #a do
			for c = 1, 3 do
				A.near(a[k][c], b[k][c], tol, what .. ": vertex " .. k)
			end
		end
	end

	t.it("(e) frames the world fixes: a round part spun or turned about its symmetry has its original's model", function()
		local rng = TestRng.new(Prop.baseSeed)
		for _ = 1, 20 do
			local q = H.randomQuat(rng)
			local d = rng:range(0.05, 0.8)
			local cylinder = H.solid(1, "Cylinder", { 0.1, 2, -0.05 }, q, { rng:range(0.1, 2), d, d })
			local spun = table.clone(cylinder)
			spun.rot = Quat.hemisphere(Quat.normalize(Quat.mul(q, H.axisAngle(1, 0, 0, rng:range(-180, 180)))))
			local flipped = table.clone(cylinder)
			flipped.rot = Quat.hemisphere(Quat.normalize(Quat.mul(q, H.axisAngle(0, 0, 1, 180))))
			local base = vertices(Cover.model(H.prepare(cylinder)))
			sameSet(vertices(Cover.model(H.prepare(spun))), base, 1e-15 * (1 + d + cylinder.size[1]) * 4, "a Cylinder spun about its axis")
			sameSet(vertices(Cover.model(H.prepare(flipped))), base, 1e-15 * (1 + d + cylinder.size[1]) * 4, "a Cylinder end for end")
			local ball = H.solid(1, "Ball", { -0.2, 2.5, 0.1 }, H.randomQuat(rng), { d, d, d })
			local turned = table.clone(ball)
			turned.rot = H.randomQuat(rng)
			sameSet(vertices(Cover.model(H.prepare(turned))), vertices(Cover.model(H.prepare(ball))), 0, "a Ball turned any way")
		end
	end)

	-- The circle's start, the world axis most across the Cylinder's own, ties going to Y, then X, then Z: along X or Z its first
	-- side faces Y, along Y it faces X.
	t.it("(e) a Cylinder's 32-gon starts from Y across an axis along X or Z, from X across an axis along Y", function()
		local function firstNormal(rot: { number }): { number }
			local m = Cover.model(H.prepare(H.solid(1, "Cylinder", { 0, 0, 0 }, rot, { 1, 0.4, 0.4 })))
			return { m.nx[1], m.ny[1], m.nz[1] }
		end
		A.truthy(firstNormal(H.I)[2] > 0.99, "axis X: the first side faces Y")
		A.truthy(firstNormal(H.Z90)[1] > 0.99, "axis Y: the first side faces X")
		A.truthy(firstNormal(H.axisAngle(0, 1, 0, 90))[2] > 0.99, "axis Z: the first side faces Y")
	end)

	t.it("(e) the model of a mirror image is the mirror image of the model, every shape", function()
		local rng = TestRng.new(Prop.baseSeed)
		for _, shape in ipairs({ "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }) do
			for _ = 1, 8 do
				local size = sized(shape, { rng:range(0.05, 1), rng:range(0.05, 1), rng:range(0.05, 1) })
				local part = H.solid(1, shape, { rng:range(-0.5, 0.5), rng:range(1, 4), rng:range(-0.2, 0.2) }, H.randomQuat(rng), size)
				for _, plane in ipairs({ "X", "Z" } :: { any }) do
					local image = Cover.model(H.prepare(Mirror.reflect(part, plane)))
					local m = Cover.model(H.prepare(part))
					local reflected: { { number } } = {}
					for _, v in ipairs(vertices(m)) do
						table.insert(reflected, if plane == "X" then { -v[1], v[2], v[3] } else { v[1], v[2], -v[3] })
					end
					table.sort(reflected, function(p: { number }, q: { number }): boolean
						for c = 1, 3 do
							if math.abs(p[c] - q[c]) > 1e-9 then
								return p[c] < q[c]
							end
						end
						return false
					end)
					sameSet(vertices(image), reflected, 1e-14, shape .. " across " .. plane)
					A.near(image.total, m.total, 1e-12 * m.total, shape .. " across " .. plane .. ": its area")
				end
			end
		end
	end)

	t.it("(e) the model as §4.4 words it: the brute force's own construction, its half-spaces' sag and facets' spread, a Ball's 128 triangles", function()
		local rng = TestRng.new(Prop.baseSeed)
		for _, shape in ipairs({ "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }) do
			for _ = 1, 6 do
				local size = sized(shape, { rng:range(0.05, 1), rng:range(0.05, 1), rng:range(0.05, 1) })
				local P = H.prepare(H.solid(1, shape, { rng:range(-0.5, 0.5), rng:range(1, 4), rng:range(-0.2, 0.2) }, H.randomQuat(rng), size))
				local m, b = Cover.model(P), Brute.model(P)
				A.eq(m.n, #b.facets, shape .. ": facets")
				A.eq(m.np, #b.planes, shape .. ": half-spaces")
				A.near(m.total, b.total, 1e-12 * b.total, shape .. ": area")
				local bv: { { number } } = {}
				for _, poly in ipairs(b.facets) do
					for k = 1, #poly, 3 do
						table.insert(bv, { poly[k], poly[k + 1], poly[k + 2] })
					end
				end
				table.sort(bv, function(p: { number }, q: { number }): boolean
					for c = 1, 3 do
						if math.abs(p[c] - q[c]) > 1e-9 then
							return p[c] < q[c]
						end
					end
					return false
				end)
				sameSet(vertices(m), bv, 1e-14, shape .. ": the vertices")
				-- sag: 0 on a polyhedron and a cap; on a round facet the true support past its plane, its probe's lead
				local ms, bs = table.clone(m.sag), table.clone(b.sag)
				table.sort(ms)
				table.sort(bs)
				for i = 1, m.np do
					A.near(ms[i], bs[i], 1e-13, shape .. ": sag " .. i)
					A.truthy(m.sag[i] >= 0, "never negative")
					if not m.round then
						A.eq(m.sag[i], 0, shape .. ": a polyhedron's half-spaces are its faces")
					end
				end
				-- spread: 0 on a polyhedron and a cap, HIDE_OFFSET × sin(π/32) on a Cylinder's side (half its 11.25°)
				local mp, bp = table.clone(m.spread), table.clone(b.spread)
				table.sort(mp)
				table.sort(bp)
				for f = 1, m.n do
					A.near(mp[f], bp[f], 1e-15, shape .. ": spread " .. f)
					if not m.round then
						A.eq(m.spread[f], 0, shape .. ": a polyhedron's probe is its faces'")
					end
					-- flat: a facet whose true surface is its plane, a polyhedron's and a Cylinder's caps (they read a Ball's sphere)
					A.eq(m.flat[f], not m.round or (shape == "Cylinder" and f > 32), shape .. ": facet " .. f .. " flat or round")
				end
				-- a round facet's hull: its vertices, then each pushed out onto the plane parallel to it that the true solid
				-- touches (a Ball's from its centre, a Cylinder side's from its axis), a cap's onto the 32-gon round its circle
				if m.round then
					for f = 1, m.n do
						local hull, poly = m.hull[f], m.poly[f]
						A.eq(#hull, 2 * #poly, shape .. ": facet " .. f .. "'s hull")
						for j = 1, #poly, 3 do
							local vx, vy, vz = hull[2 * j - 1], hull[2 * j], hull[2 * j + 1]
							A.deepEq({ vx, vy, vz }, { poly[j], poly[j + 1], poly[j + 2] }, shape .. ": a vertex first")
							local px, py, pz = hull[2 * j + 2] - P.cx, hull[2 * j + 3] - P.cy, hull[2 * j + 4] - P.cz
							local t = if shape == "Cylinder" then px * P.ux + py * P.uy + pz * P.uz else 0
							px, py, pz = px - t * P.ux, py - t * P.uy, pz - t * P.uz
							local reach = if shape == "Cylinder" and f > 32 then math.sqrt(px * px + py * py + pz * pz) * 0.99518472667219693
								else px * m.nx[f] + py * m.ny[f] + pz * m.nz[f]
							A.near(reach, P.r, 1e-12 * (1 + P.r), shape .. ": facet " .. f .. ", its point pushed out")
						end
					end
				end
				if shape == "Cylinder" then
					A.truthy(m.sag[33] + m.sag[34] <= 1e-14, "the caps: " .. m.sag[33] + m.sag[34])
					A.truthy(m.sag[1] > 0, "a side")
					A.eq(m.spread[33] + m.spread[34], 0, "the caps' spread")
					A.near(m.spread[1], Geo.HIDE_OFFSET * 0.098017140329560604, 1e-15, "a side's spread")
				elseif shape == "Ball" then
					A.eq(m.n, 8 * Geo.COVER_BALL_GRID * Geo.COVER_BALL_GRID, "128 triangles")
					local largest = 0
					for f = 1, m.n do
						largest = math.max(largest, m.area[f] / m.total)
					end
					A.within(largest, 0.012, 0.0121, "the largest triangle, 1.21 % of the model: none alone keeps a Ball")
					A.within(m.total / (4 * Shapes.PI * P.r * P.r), 0.95, 0.96, "inscribed: 95.1 % of the sphere's area")
				end
			end
		end
	end)

	-- Sampling hands over every part whose box comes within the part's reach + the hider's over + 2·EPS_GEOM (§4.4), and a
	-- facet asks each hider whose box, grown by its over, comes within the facet's probe and spread: so on every model each
	-- facet lies in the part's box and probes and spreads no further than the reach, and the half-spaces moved out by their
	-- sag stand past the box by no more than the over. A Ball's: the 4 facets round each axis meet on it 0.0260 r out, the tip of a cone that holds the
	-- whole polytope; a Cylinder's: its moved sides meet the caps at the circumscribed 32-gon, sec(π/32) − 1 = 0.0048 r out.
	t.it("(e) reach and over: each facet's probe within the reach, the moved half-spaces within the over of the box", function()
		local rng = TestRng.new(Prop.baseSeed)
		-- where planes i, j, k of m meet, each moved out by its sag (Cramer's rule)
		local function meet(m: Cover.Model, i: number, j: number, k: number): (number, number, number)
			local p = m.planes
			local a1, a2, a3, d1 = p[4 * i - 3], p[4 * i - 2], p[4 * i - 1], p[4 * i] + m.sag[i]
			local b1, b2, b3, d2 = p[4 * j - 3], p[4 * j - 2], p[4 * j - 1], p[4 * j] + m.sag[j]
			local c1, c2, c3, d3 = p[4 * k - 3], p[4 * k - 2], p[4 * k - 1], p[4 * k] + m.sag[k]
			local det = a1 * (b2 * c3 - b3 * c2) - a2 * (b1 * c3 - b3 * c1) + a3 * (b1 * c2 - b2 * c1)
			return (d1 * (b2 * c3 - b3 * c2) - a2 * (d2 * c3 - b3 * d3) + a3 * (d2 * c2 - b2 * d3)) / det,
				(a1 * (d2 * c3 - b3 * d3) - d1 * (b1 * c3 - b3 * c1) + a3 * (b1 * d3 - d2 * c1)) / det,
				(a1 * (b2 * d3 - d2 * c2) - a2 * (b1 * d3 - d2 * c1) + d1 * (b1 * c2 - b2 * c1)) / det
		end
		local function past(P: Prepared, x: number, y: number, z: number): number
			return math.max(x - P.maxx, P.minx - x, y - P.maxy, P.miny - y, z - P.maxz, P.minz - z)
		end
		local ball, cylinder = 0, 0
		for _, shape in ipairs({ "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }) do
			for _ = 1, 10 do
				local size = sized(shape, { rng:range(0.02, 1.5), rng:range(0.02, 1.5), rng:range(0.02, 1.5) })
				local P = H.prepare(H.solid(1, shape, { rng:range(-0.5, 0.5), rng:range(1, 4), rng:range(-0.2, 0.2) }, H.randomQuat(rng), size))
				local m = Cover.model(P)
				local longest = Geo.HIDE_OFFSET
				for f = 1, m.n do
					longest = math.max(longest, Geo.HIDE_OFFSET + (if m.round then m.sag[f] else 0) + m.spread[f])
					local poly = m.poly[f]
					for k = 1, #poly, 3 do
						A.truthy(past(P, poly[k], poly[k + 1], poly[k + 2]) <= 1e-12, shape .. ": facet " .. f .. " in the box")
					end
				end
				A.eq(m.reach, longest, shape .. ": the reach, the longest probe and spread")
				if shape == "Cylinder" then
					local out = -math.huge
					for k = 1, 32 do
						for cap = 33, 34 do
							out = math.max(out, past(P, meet(m, k, if k == 32 then 1 else k + 1, cap)))
						end
					end
					A.truthy(out <= m.over, "a Cylinder's over: " .. out / P.r .. " r")
					cylinder = math.max(cylinder, out / P.r)
				elseif shape == "Ball" then
					for axis = 1, 3 do
						for _, s in ipairs({ -1, 1 }) do
							local at = { P.cx, P.cy, P.cz }
							at[axis] += s * P.r
							local round: { number } = {}
							for f = 1, m.n do
								local poly = m.poly[f]
								for k = 1, #poly, 3 do
									if math.abs(poly[k] - at[1]) + math.abs(poly[k + 1] - at[2]) + math.abs(poly[k + 2] - at[3]) <= 1e-12 then
										table.insert(round, f)
									end
								end
							end
							A.eq(#round, 4, "4 facets round an axis")
							local x, y, z = meet(m, round[1], round[2], round[3])
							local x2, y2, z2 = meet(m, round[2], round[3], round[4])
							A.near(math.abs(x - x2) + math.abs(y - y2) + math.abs(z - z2), 0, 1e-12, "the 4 meet in one point")
							local out = past(P, x, y, z)
							A.truthy(out <= m.over, "a Ball's over: " .. out / P.r .. " r")
							ball = math.max(ball, out / P.r)
						end
					end
				else
					A.eq(m.over, 0, shape .. ": a polyhedron's half-spaces are its faces")
				end
			end
		end
		A.within(ball, 0.0255, 0.0265, "a Ball's half-spaces stand 0.0260 r out")
		A.within(cylinder, 0.003, 0.0049, "a Cylinder's at most 0.0048 r")
	end)

	-- A flat face against a Ball reads its true sphere (§4.4): what the Ball hides of a plate's top, 2.4 r wide, at height h
	-- over its centre is the 32-gon round the circle that the top's plane cuts from the sphere grown by EPS_GEOM, or its
	-- probe's plane δ higher where that circle is larger: 32·tan(π/32)·ρ², its corners R·(sec(π/32) − 1) = 0.0048 R past the
	-- sphere through the centre (within OVER_BALL, so the box tests leave no piece out), less off it, and the inner ball
	-- inside it. Its frame comes from the face's normal and the world alone: a Block described another way (its X and Y sizes
	-- swapped with a quarter turn about Z) and its images across X and Z read what it reads against a Ball, to rounding, with
	-- two 45° snaps too (a normal whose two least components tie: (0.7071, 0.5, 0.5), and (0.5, 0.7071, −0.5), X and Z, V1).
	t.it("(e) a flat face against a Ball: the 32-gon round the circle its plane cuts, in a frame its normal and the world fix", function()
		local R, eps, delta = 0.3, Geo.EPS_GEOM, Geo.HIDE_OFFSET
		local qm = Cover.model(H.prepare(H.solid(1, "Ball", { 0, 2, 0 }, H.I, { 2 * R, 2 * R, 2 * R })))
		local T32 = 0.098491403357164253 -- tan(π/32)
		for _, f in ipairs({ -0.9, -0.5, 0, 0.3, 0.7, 0.95, 0.99 }) do
			local h = f * R
			local pm = Cover.model(H.prepare(H.solid(2, "Block", { 0.013, 2 + h - 0.01, -0.007 }, H.I, { 2.4 * R, 0.02, 2.4 * R }), 2))
			local top = 0
			for k = 1, pm.n do
				if pm.ny[k] > 0.999 then
					top = k
				end
			end
			local rho2 = math.max((R + eps) ^ 2 - h * h, (R + eps) ^ 2 - (h + delta) ^ 2)
			local hidden = pm.area[top] - Cover.shown(oneFacet(pm, top), { qm }, { true }, math.huge, math.huge)
			A.near(hidden, 32 * T32 * rho2, 1e-12 * rho2, "a plate's top " .. f .. " r over the centre: the 32-gon round its circle")
		end
		local rng = TestRng.new(Prop.baseSeed)
		local snaps = Quat.hemisphere(Quat.normalize(Quat.mul(H.axisAngle(1, 0, 0, 45), H.axisAngle(0, 1, 0, 45))))
		local snapsXZ = Quat.hemisphere(Quat.normalize(Quat.mul(H.axisAngle(0, 1, 0, 45), H.axisAngle(0, 0, 1, 45)))) -- (0.5, 0.7071, −0.5): X and Z tie
		local Z90 = { 0, 0, 0.70710678118654757, 0.70710678118654757 }
		for k = 1, 28 do
			local rot = if k <= 4 then snaps elseif k > 24 then snapsXZ else H.randomQuat(rng)
			local size = { rng:range(0.35, 0.6), rng:range(0.35, 0.6), rng:range(0.35, 0.6) } -- poking out of the Ball, never round it
			local pos = { rng:range(-0.15, 0.15), 2 + rng:range(-0.15, 0.15), rng:range(-0.15, 0.15) }
			local block = H.solid(2, "Block", pos, rot, size, "Guard")
			local turned = H.solid(2, "Block", pos, Quat.hemisphere(Quat.normalize(Quat.mul(rot, Z90))), { size[2], size[1], size[3] }, "Guard")
			local ball = H.solid(1, "Ball", { 0, 2, 0 }, H.I, { 2 * R, 2 * R, 2 * R })
			local P = prepared({ ball, block })
			local reads = H.reads(P, 2)
			A.truthy(reads > 0 and reads < 1, "case " .. k .. ": the Ball hides some of the Block: " .. reads)
			A.near(H.reads(prepared({ ball, turned }), 2), reads, 1e-9, "case " .. k .. ": described another way")
			for _, plane in ipairs({ "X", "Z" } :: { any }) do
				A.near(H.reads(prepared({ ball, Mirror.reflect(block, plane) }), 2), reads, 1e-9, "case " .. k .. ": across " .. plane)
			end
		end
	end)

	-- ── (f) the cap ──────────────────────────────────────────────────────────────────────────────────────────────

	local function unitsOf(parts: { Prepared }): (number, boolean)
		local e = Sampling.exposure(parts)
		return e.verdictWork, e.capped
	end

	t.it("(f) the real designs stay at least 2 × under VERDICT_WORK_MAX: F, C and X fixtures, P1–P5", function()
		local heaviest, name = 0, ""
		local function see(parts: { any }, what: string)
			local units, capped = unitsOf(prepared(parts))
			A.falsy(capped, what)
			A.truthy(2 * units <= Geo.VERDICT_WORK_MAX, what .. ": " .. units .. " units")
			if units > heaviest then
				heaviest, name = units, what
			end
		end
		for _, id in ipairs(Blueprints.order) do
			see(Blueprints.core(id).parts, id)
		end
		for _, set in ipairs({ Fixtures.calibration(), Fixtures.regression(), Fixtures.perf() }) do
			for _, b in ipairs(set) do
				if b.parts then
					see(b.parts, b.name)
				elseif b.fixture then
					see(b.fixture.parts, b.fixture.name)
				end
			end
		end
		A.eq(string.sub(name, 1, 2), "P1", "the heaviest is P1")
	end)

	-- Every design of 20 parts or more (1,083; the heaviest, 5 wrap rings over C09, 104,573 units) and every 4th of the
	-- rest (the heaviest of them 56,666): 9,153 designs in 58 s, where all 33,389 take 191.
	t.slow("(f) the plausible designs stay at least 2 × under VERDICT_WORK_MAX: all of 20 parts or more, every 4th of the rest", function()
		local count, heaviest = 0, 0
		for k, d in ipairs(Plausible.all()) do
			if #d.parts >= 20 or k % 4 == 0 then
				local units = unitsOf(prepared(d.parts))
				heaviest = math.max(heaviest, units)
				count += 1
				A.truthy(2 * units <= Geo.VERDICT_WORK_MAX, d.name .. ": " .. units .. " units")
			end
		end
		A.truthy(count > 9000, "designs: " .. count)
		A.truthy(heaviest > 100000, "the wrap rings over C09 are in the sweep: " .. heaviest)
	end)

	-- Each stops at the report that passes the cap and reports nothing after it (Cover's header), so it stops within one
	-- report of the cap, every unit reported.
	t.slow("(f) a design past the cap: no verdict, TooComplex, answered at once, nothing reported after the cap; capped in any order", function()
		A.truthy(#Worst.tooComplex >= 6, "designs past the cap: " .. #Worst.tooComplex)
		local rng = TestRng.new(Prop.baseSeed)
		for k, d in ipairs(Worst.tooComplex) do
			local core: any = { schema = 1, name = "worst", type = "Sword", parts = d.parts }
			-- the first 4 timed, the best of 3 runs, so that a GC step or another process does not time the design (quiet: 12–26 ms)
			local e: any, ms = nil, math.huge
			local runs = if k <= 4 then 3 else 1
			for _ = 1, runs do
				local parts = prepared(d.parts)
				local t0 = os.clock()
				e = Sampling.exposure(parts)
				ms = math.min(ms, (os.clock() - t0) * 1000)
			end
			A.truthy(e.capped, d.name .. ": capped")
			A.deepEq(e.cleaned, {}, d.name .. ": no verdict")
			local reported, after = 0, 0
			local seen = Sampling.exposure(prepared(d.parts), function(n: number)
				if reported > Geo.VERDICT_WORK_MAX then
					after += 1
				end
				reported += n
			end)
			A.eq(seen.verdictWork, e.verdictWork, d.name .. ": the same with spend")
			A.eq(reported, e.verdictWork, d.name .. ": every unit reported")
			A.eq(after, 0, d.name .. ": nothing reported after the report that passed the cap")
			A.truthy(e.verdictWork > Geo.VERDICT_WORK_MAX and e.verdictWork <= Geo.VERDICT_WORK_MAX + 4096, d.name .. ": stopped past the cap, at once: " .. e.verdictWork)
			if k <= 4 then
				A.truthy(ms <= Tol.ANALYSIS_LUNE_MAX_MS, d.name .. ": " .. ms .. " ms, the best of 3")
				local run = Analyze.run(core, { measureInvalid = true })
				A.eq(run.validation.ok, false)
				A.eq(run.validation.errors[#run.validation.errors].code, "TooComplex", d.name)
				A.eq(run.physics, nil, d.name .. ": measured never")
				local again = Sampling.exposure(prepared(shuffled(rng, d.parts)))
				A.truthy(again.capped, d.name .. ": capped in another order")
			end
		end
	end)

	-- What a model and a reading report through spend is their work, unit for unit: the checkpoints and the cap see it all.
	t.it("(f) a model and a reading report all their work through spend and no more: C09 and F3, every part", function()
		for _, core in ipairs({ H.ornate(), Blueprints.core("F3") }) do
			local parts = prepared(core.parts)
			for i = 1, #parts do
				local built = 0
				local m = Cover.model(parts[i], function(n: number)
					built += n
				end)
				A.eq(built, m.work, core.name .. " part " .. i .. ": the model's reports")
				local _, higher, hm = H.hidersOf(parts, i)
				local read = 0
				local _, used = Cover.shown(m, hm, higher, math.huge, math.huge, function(n: number)
					read += n
				end)
				A.eq(read, used, core.name .. " part " .. i .. ": the reading's reports")
			end
		end
	end)

	t.it("(f) units depend on no order: P1 and the slowest valid designs, the same total in 3 orders", function()
		local rng = TestRng.new(Prop.baseSeed)
		local designs: { any } = { H.p1().parts }
		for k = 1, math.min(2, #Worst.valid) do
			table.insert(designs, Worst.valid[k].parts)
		end
		for _, parts in ipairs(designs) do
			local units, capped = unitsOf(prepared(parts))
			A.falsy(capped)
			for _ = 1, 3 do
				A.eq((unitsOf(prepared(shuffled(rng, parts)))), units, "the same units")
			end
		end
	end)

	-- The units are the cap's outcome (Cover's header: the weights move with BALANCE_VERSION), so their totals are pinned: a
	-- charge dropped or doubled anywhere in the models, the looks or the readings moves one of these.
	t.it("(f) the units of P1, P4, C09, F3, the slowest valid design and two attack designs, to the unit", function()
		local pins: { { any } } = {
			{ "P1", H.p1().parts, 330993.125 },
			{ "C09", H.ornate().parts, 17511.625 },
			{ "F3", Blueprints.core("F3").parts, 10973.25 },
			{ Worst.valid[1].name, Worst.valid[1].parts, 687304.125 },
			{ Attacks[3].name, Attacks[3].parts, 23687.25 },
			{ Attacks[15].name, Attacks[15].parts, 6801 },
		}
		for _, perf in ipairs(Fixtures.perf()) do
			if string.sub(perf.name, 1, 2) == "P4" then
				table.insert(pins, { "P4", perf.parts, 172903 } :: { any })
			end
		end
		A.eq(#pins, 7, "the pinned designs")
		A.eq(Worst.valid[1].units, 687304.125, "worst_designs.luau's own count")
		for _, pin in ipairs(pins) do
			local units, capped = unitsOf(prepared(pin[2]))
			A.falsy(capped, pin[1])
			A.eq(units, pin[3], pin[1] .. ": units")
		end
	end)

	-- Checkpoints and the cap come through spend: a model reports as it is built and a reading once SPEND_EVERY units have
	-- built up, at the next facet, half-space, line clipped or split, line or edge tested, polygon, piece or hider, so no
	-- single report runs long: the largest, over the fixtures, the attack designs and worst_designs.luau, 1,088 units (2,335
	-- while a flat face read a Ball on its 128 half-spaces, not its circle's 32 lines; 3,570 before the third round's rules
	-- hid tclimb_1.json #5's parts whole), what a test that ends early charges for the lines it skipped (E-S2.12). Reported at
	-- each piece rather than each line, a Cylinder's cap clipped by most of a small Ball's 128 lines made one report of 5,362
	-- units alone and 5,047 in V1's valid sword; reported at each hider and each polygon cut alone, 9,190; without the
	-- report in a run of polygons kept whole, 38,082 past the cap.
	-- A part's look can pass the cap before its reading starts: the reading then reads and reports nothing (Sampling makes
	-- the design TooComplex at that report, §4.4).
	t.it("(f) a reading entered past the budget does nothing and reports nothing", function()
		local parts = prepared(H.ornate().parts)
		local m = models(parts)
		for i = 1, #parts do
			if m[i] then
				local _, higher, hm = H.hidersOf(parts, i, m)
				local calls = 0
				local shown, used, over = Cover.shown(m[i], hm, higher, 0, -0.125, function(_: number)
					calls += 1
				end)
				A.eq(over, true, "part " .. i .. ": over")
				A.eq(used, 0, "part " .. i .. ": no work")
				A.eq(calls, 0, "part " .. i .. ": no report")
				A.eq(shown, if #hm == 0 then m[i].total else 0, "part " .. i .. ": no area")
			end
		end
	end)

	-- A plate ringed by 20 Balls at its height: each face's box meets the Balls' and each Ball's circle is projected on 32
	-- lines (80 units a Ball on a face; 320 on its 128 half-spaces before), its pieces mostly empty. No test here ends
	-- early, so a report is SPEND_EVERY and one step at most (§4.9; 267 units at most): the projection and the pieces report
	-- as they go.
	t.it("(f) a plate ringed by 20 Balls reports in stretches of SPEND_EVERY and one step", function()
		local list = { H.part(1, "Blade", "Block", "Iron", { 0, 2, 0 }, H.I, { 0.6, 0.02, 0.6 }) }
		for _, t in ipairs({ -0.24, -0.12, 0, 0.12, 0.24 }) do
			for _, at in ipairs({ { 0.36, t }, { -0.36, t }, { t, 0.36 }, { t, -0.36 } }) do
				table.insert(list, H.part(#list + 1, "Guard", "Ball", "Iron", { at[1], 2, at[2] }, H.I, { 0.1, 0.1, 0.1 }))
			end
		end
		local parts = prepared(list)
		local m = models(parts)
		local _, higher, hm = H.hidersOf(parts, 1, m)
		A.truthy(#hm >= 20, "the Balls are its hiders: " .. #hm)
		local most, total = 0, 0
		local _, used = Cover.shown(m[1], hm, higher, math.huge, math.huge, function(n: number)
			most = math.max(most, n)
			total += n
		end)
		A.eq(total, used, "every unit reported")
		A.truthy(most <= 512, "the largest single report: " .. most)
	end)

	-- A puck r 0.1, 0.1 long (the tilted case's), tangent to the rim of 20 disks r 0.8 + 1e-7·(k − 1) on one centre (Guard
	-- Cylinders along Z, 0.5 long), turned 60° about the radius and leaned 45° about the tangent, its farthest point 1e-6
	-- out of the largest: against each disk rule A leaves a cap open, searched and not held, 28.5 units a test and 570
	-- before its first facet, so the rule-A loop reports at each round hider (§4.9; V1). The largest report here is
	-- 333.625 units, a cap facet's tests against a disk on top of 253; without the loop's report the first is 579.125.
	t.it("(f) a run of searched cap rims reports in stretches of SPEND_EVERY and one test", function()
		local alpha = math.rad(30)
		local rx, ry = math.sin(alpha), math.cos(alpha)
		local list: { any } = {}
		for k = 1, 20 do
			local R = 0.8 + 1e-7 * (k - 1)
			table.insert(list, H.part(k, "Guard", "Cylinder", "Iron", { 0, 2, 0 }, H.Y90, { 0.5, 2 * R, 2 * R }))
		end
		local q = Quat.hemisphere(Quat.normalize(Quat.mul(H.axisAngle(-ry, rx, 0, 45), Quat.mul(H.axisAngle(rx, ry, 0, 60),
			H.axisAngle(0, 0, 1, math.deg(math.atan2(-rx, ry)))))))
		local function at(y0: number): any
			return H.part(21, "Blade", "Cylinder", "Iron", { y0 * rx, 2 + y0 * ry, 0 }, q, { 0.1, 0.2, 0.2 })
		end
		-- its farthest point 1e-6 out of the largest disk, by secant steps along the radius
		local y0 = 0.8 - 0.1 - 0.02
		local largest = H.prepare(list[20], 20)
		for _ = 1, 6 do
			local below, above = Brute.standsOut(H.prepare(at(y0), 21), largest)
			y0 += 1e-6 - (below + above) / 2
		end
		table.insert(list, at(y0))
		local parts = prepared(list)
		local m = models(parts)
		local _, higher, hm = H.hidersOf(parts, 21, m)
		A.eq(#hm, 20, "the disks are its hiders")
		local most, total = 0, 0
		local shown, used = Cover.shown(m[21], hm, higher, math.huge, math.huge, function(n: number)
			most = math.max(most, n)
			total += n
		end)
		A.truthy(shown > 0, "the puck stands out of every disk: it reads " .. shown)
		A.eq(total, used, "every unit reported")
		A.truthy(used >= 20 * 28.5, "a cap searched against each disk: " .. used .. " units")
		A.truthy(most <= 512, "the largest single report: " .. most)
	end)

	-- The stop at the budget, at every kind of step: C09's parts, the plate ringed by Balls and a Cylinder's cap under a
	-- Ball, each read with budgets swept over its whole reading. The reading stops at the first report past the budget,
	-- reports nothing after it and says so; under its total it reads to the end.
	t.it("(f) a reading stops at the first report past its budget, whatever step passes it", function()
		local lists: { { Prepared } } = { prepared(H.ornate().parts) }
		local ring = { H.part(1, "Blade", "Block", "Iron", { 0, 2, 0 }, H.I, { 0.6, 0.02, 0.6 }) }
		for _, t in ipairs({ -0.24, -0.12, 0, 0.12, 0.24 }) do
			for _, at in ipairs({ { 0.36, t }, { -0.36, t }, { t, 0.36 }, { t, -0.36 } }) do
				table.insert(ring, H.part(#ring + 1, "Guard", "Ball", "Iron", { at[1], 2.005, at[2] }, H.I, { 0.1, 0.1, 0.1 }))
			end
		end
		table.insert(lists, prepared(ring))
		table.insert(lists, prepared({
			H.part(1, "Blade", "Block", "Iron", { 0, 1, 0 }, H.I, { 0.7, 0.6, 0.65 }),
			H.part(2, "Blade", "Cylinder", "Iron", { 0, 1.006, 0 }, H.Z90, { 0.6, 0.4, 0.4 }),
			H.part(3, "Guard", "Ball", "Iron", { 0, 1.306, 0 }, H.I, { 0.08, 0.08, 0.08 }),
		}))
		for _, parts in ipairs(lists) do
			local m = models(parts)
			for i = 1, #parts do
				if m[i] then
					local _, higher, hm = H.hidersOf(parts, i, m)
					local _, total = Cover.shown(m[i], hm, higher, math.huge, math.huge)
					local step = math.max(1, math.floor(total / 23))
					for budget = 0, total + step, step do
						local reported, after = 0, 0
						local _, used, over = Cover.shown(m[i], hm, higher, math.huge, budget, function(n: number)
							if reported > budget then
								after += 1
							end
							reported += n
						end)
						A.eq(after, 0, "part " .. i .. ", budget " .. budget .. ": nothing reported after the report past it")
						A.eq(reported, used, "part " .. i .. ", budget " .. budget .. ": every unit reported")
						A.eq(over, used > budget, "part " .. i .. ", budget " .. budget .. ": over")
						if budget >= total then
							A.eq(used, total, "part " .. i .. ", budget " .. budget .. ": read to the end")
						end
					end
				end
			end
		end
	end)

	t.it("(f) the verdict reports its units in short stretches: C09, the slowest valid designs, 4 past the cap, a cap under a Ball", function()
		local designs: { any } = { H.ornate().parts }
		for k = 1, 3 do
			table.insert(designs, Worst.valid[k].parts)
		end
		for k = 1, 4 do
			table.insert(designs, Worst.tooComplex[k].parts)
		end
		local function biggest(parts: { any }): number
			local most = 0
			Sampling.exposure(prepared(parts), function(n: number)
				most = math.max(most, n)
			end)
			return most
		end
		for _, parts in ipairs(designs) do
			local most = biggest(parts)
			A.truthy(most <= 4096, "the largest single report: " .. most)
		end
		-- a Cylinder R 0.2 whose cap stands 0.006 proud of a Block, a Ball r 0.04 centred on the cap; V1's sword: F5's hilt, a
		-- Block 0.7 × 0.6 × 0.58 with a Cylinder R 0.15 sunk in it 0.004 proud, a Ball r 0.04 on its cap, a blade beside them
		local alone = {
			H.part(1, "Blade", "Block", "Iron", { 0, 1, 0 }, H.I, { 0.7, 0.6, 0.65 }),
			H.part(2, "Blade", "Cylinder", "Iron", { 0, 1.006, 0 }, H.Z90, { 0.6, 0.4, 0.4 }),
			H.part(3, "Guard", "Ball", "Iron", { 0, 1.306, 0 }, H.I, { 0.08, 0.08, 0.08 }),
		}
		local sword = {
			H.part(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, H.I, { 0.26, 0.26, 0.26 }),
			H.part(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, H.I, { 0.16, 0.9, 0.16 }),
			H.part(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, H.I, { 1, 0.18, 0.24 }),
			H.part(4, "Blade", "Block", "Iron", { 0, 1.68, 0 }, H.I, { 0.7, 0.6, 0.58 }),
			H.part(5, "Blade", "Cylinder", "Iron", { 0, 1.684, 0 }, H.Z90, { 0.6, 0.3, 0.3 }),
			H.part(6, "Guard", "Ball", "Iron", { 0, 1.984, 0 }, H.I, { 0.08, 0.08, 0.08 }),
			H.part(7, "Blade", "Block", "Iron", { 0.27, 3.18, 0 }, H.I, { 0.16, 2.4, 0.06 }),
		}
		A.truthy(Analyze.run(H.core("cap under a Ball", sword)).validation.ok, "V1's sword is valid")
		for _, parts in ipairs({ alone, sword }) do
			local most = biggest(parts)
			A.truthy(most <= 4096, "a cap clipped by a Ball's lines, one report: " .. most)
		end
	end)
end)
