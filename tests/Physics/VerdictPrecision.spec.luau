--!strict
-- How close the Enclosed verdict comes to the truth (SPEC §4.4, E-S2.11, E-S2.12). VisibleOracle against closed forms, then the
-- verdict against VisibleOracle on a sweep of the plausible families and the attack designs: on these, the rule cleans nothing
-- that really shows and keeps nothing that really does not. The bounds are a little wider than what the whole of those sets
-- measures.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Prop = require("../lib/Prop")
local TestRng = require("../lib/TestRng")
local Attacks = require("./CoverAttacks")
local Oracle = require("./VisibleOracle")
local Plausible = require("./PlausibleDesigns")
local Balance = require("../../src/shared/Definitions/Balance")
local Quat = require("../../src/shared/Blueprint/Quat")
local Sampling = require("../../src/shared/Physics/Sampling")
local Shapes = require("../../src/shared/Physics/Shapes")

local DELTA = Balance.Geometry.HIDE_OFFSET
local PI = math.pi
local I = { 0, 0, 0, 1 }

local function axisAngle(ax: number, ay: number, az: number, deg: number): { number }
	local h = math.rad(deg) / 2
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	return Quat.normalize({ ax / n * math.sin(h), ay / n * math.sin(h), az / n * math.sin(h), math.cos(h) })
end

local TURNS = { I, axisAngle(1, 2, 3, 37), axisAngle(-2, 1, 0.5, 71), axisAngle(0, 0, 1, 22.5), axisAngle(1, 1, 0, 45) }

local function solid(shape: string, pos: { number }, rot: { number }, size: { number }): any
	return { shape = shape, pos = pos, rot = rot, size = size, slot = "Blade", material = "Iron" }
end

-- a host whose top plane is y = c, far wider than the part
local function hostBelow(c: number): any
	return solid("Block", { 0, c - 2, 0 }, I, { 8, 4, 8 })
end

-- Every closed form: a part (the first listed, unless `index` says) with the visible share it must have. A sunk part's probe
-- reaches further than its surface once the plane is below its centre: the share is taken at that plane.
local function closedForms(): { any }
	local out: { any } = {}
	local function add(what: string, parts: { any }, want: number, index: number?)
		table.insert(out, { what = what, parts = parts, want = want, index = index or 1 })
	end
	for _, r in ipairs({ 0.15, 0.05 }) do
		for _, f in ipairs({ 0.99, 0.95, 0.9, 0.8, 0.5, 0.2, 0, -0.5, -0.9 }) do
			local c = f * r
			local probed = if c >= 0 then c else c / (1 + DELTA / r)
			add("ball r " .. r .. ", plane at " .. f .. " r", { solid("Ball", { 0, 0, 0 }, I, { 2 * r, 2 * r, 2 * r }), hostBelow(c) }, math.max(0, (r - probed) / (2 * r)))
		end
	end
	for _, def in ipairs({ { 0.1, 1.0 }, { 0.03, 2.0 }, { 0.2, 0.05 } }) do
		local r, L = def[1], def[2]
		for _, f in ipairs({ 0.99, 0.95, 0.9, 0.7, 0.3, 0, -0.5, -0.9 }) do
			local c = f * r
			local probed = if c >= 0 then c else c / (1 + DELTA / r)
			local side = L * 2 * r * math.acos(math.clamp(probed / r, -1, 1))
			local cap = 2 * (r * r * math.acos(f) - c * math.sqrt(r * r - c * c))
			add("cylinder r " .. r .. " L " .. L .. ", plane at " .. f .. " r", { solid("Cylinder", { 0, 0, 0 }, I, { L, 2 * r, 2 * r }), hostBelow(c) },
				(side + cap) / (2 * PI * r * L + 2 * PI * r * r))
		end
	end
	-- a slot: two walls through the axis, at ±phi from +Z, leave an arc of the side; end blocks hide the caps
	for _, phi in ipairs({ 5, 10, 20, 30, 45 }) do
		local r, L = 0.1, 1.0
		local function wall(sign: number): any
			local q = axisAngle(1, 0, 0, sign * phi)
			local n = Quat.rotate(q, { 0, sign, 0 })
			return solid("Block", { 0, n[2] * 2, n[3] * 2 }, q, { 8, 4, 8 })
		end
		add("cylinder slot, half-angle " .. phi, { solid("Cylinder", { 0, 0, 0 }, I, { L, 2 * r, 2 * r }), wall(1), wall(-1),
			solid("Block", { L / 2 + 2, 0, 0 }, I, { 4, 4, 4 }), solid("Block", { -L / 2 - 2, 0, 0 }, I, { 4, 4, 4 }) },
			(L * 2 * r * math.rad(phi)) / (2 * PI * r * L + 2 * PI * r * r))
	end
	for _, t in ipairs({ 0.001, 0.002, 0.005, 0.01, 0.02, 0.05, 0.1 }) do
		local a, b, c = 0.3, 0.5, 0.04
		add("plate sunk to " .. t, { solid("Block", { 0, t - b / 2, 0 }, I, { a, b, c }), hostBelow(0) },
			(a * c + 2 * (a + c) * t) / (2 * (a * b + a * c + b * c)))
	end
	for _, f in ipairs({ 0.95, 0.8, 0.5, 0, -0.5, -0.9 }) do
		local hx, hy, hz = 0.2, 0.15, 0.1
		local c = f * hy
		local s = math.sqrt(hy * hy + hz * hz)
		local total = 4 * hx * hz + 4 * hx * hy + 4 * hx * s + 4 * hy * hz
		add("wedge, plane at " .. f .. " hy", { solid("Wedge", { 0, 0, 0 }, I, { 2 * hx, 2 * hy, 2 * hz }), hostBelow(c) },
			(2 * hx * (hy - c) + (hy - c) / (2 * hy) * 4 * hx * s + 2 * hz * (hy - c) * (hy - c) / (2 * hy)) / total)
	end
	-- coincident faces: A and B overlap by o along X, the same Y and Z ranges; the higher rank keeps what they share. Turned with
	-- the whole design, so that A, the left, stands first by something else on each turn: it is the rank that counts, not the left
	do
		local a, b, c, o = 0.6, 0.3, 0.1, 0.2
		local pair = { solid("Block", { -(a - o) / 2, 0, 0 }, I, { a, b + 0.002, c }), solid("Block", { (a - o) / 2, 0, 0 }, I, { a, b, c }) }
		local total = 2 * (a * (b + 0.002) + a * c + (b + 0.002) * c)
		local other = 2 * (a * b + a * c + b * c)
		add("the larger keeps coincident faces, loses its end", pair, (total - (b + 0.002) * c + (b + 0.002 - b) * c) / total)
		add("the smaller loses them and its end", pair, (other - b * c - o * (2 * b + 2 * c)) / other, 2)
	end
	-- Dust hides nothing: a speck on the sunk plate's top
	do
		local a, b, c, t = 0.3, 0.5, 0.04, 0.02
		add("a plate sunk to 0.02, a Dust speck on its top", { solid("Block", { 0, t - b / 2, 0 }, I, { a, b, c }), hostBelow(0), solid("Block", { 0, t + 0.025, 0 }, I, { 0.05, 0.05, 0.05 }) },
			(a * c + 2 * (a + c) * t) / (2 * (a * b + a * c + b * c)))
	end
	-- a gap below a plate: within the probe its bottom is hidden, past it not
	do
		local a, b, c = 0.3, 0.1, 0.4
		local total = 2 * (a * b + a * c + b * c)
		add("a plate 0.008 above a host", { solid("Block", { 0, b / 2 + 0.008, 0 }, I, { a, b, c }), hostBelow(0) }, (total - a * c) / total)
		add("a plate 0.014 above a host", { solid("Block", { 0, b / 2 + 0.014, 0 }, I, { a, b, c }), hostBelow(0) }, 1)
	end
	return out
end

local function prepared(parts: { any }, q: { number }): { any }
	local out = table.create(#parts)
	for i, p in ipairs(parts) do
		local turned = solid(p.shape, Quat.rotate(q, { p.pos[1], p.pos[2], p.pos[3] }), Quat.normalize(Quat.mul(q, p.rot)), p.size)
		turned.id = i
		out[i] = Shapes.prepare(turned, i)
	end
	return out
end

-- Worst error, in share of the surface.
local function checkClosedForms(turns: number, points: number, tolerance: number)
	for _, form in ipairs(closedForms()) do
		for t = 1, turns do
			local parts = prepared(form.parts, TURNS[t])
			local _, _, hider = Oracle.flags(parts)
			A.near(Oracle.measure(parts, form.index, hider, points), form.want, tolerance, form.what .. ", turn " .. t)
		end
	end
end

-- Cleaned at this true share or above, or kept below that one, is a wrong verdict. All 33,389 plausible designs measure
-- 3.615 % (a Ball in a pommel housing, read on its model with the probe's spread) and 2.002 % (a fuller's core, kept as
-- it should be); the attack designs 0 wrong (E-S2.12). Fullers, combs, walls, ribbed bars, cages, grilles and tilings
-- are among them. The coarse lattice settles a share farther than COARSE_SLACK from the bound it is checked against;
-- the fine one decides the rest.
local CLEANED_UNDER = 0.04
local KEPT_FROM = 0.019
local COARSE_SLACK = 0.01
local SWEEP_SHARE = 0.1

-- A tenth of the plausible families, by the seed, and every attack design.
local function sweep()
	local rng = TestRng.new(Prop.baseSeed)
	local designs, checked = 0, 0
	local list: { any } = {}
	for _, d in ipairs(Plausible.all()) do
		if rng:float() < SWEEP_SHARE then
			table.insert(list, d)
		end
	end
	for _, d in ipairs(Attacks) do
		table.insert(list, { name = d.name, parts = d.parts })
	end
	for _, d in ipairs(list) do
		designs += 1
		local parts = table.create(#d.parts)
		for i, part in ipairs(d.parts) do
			parts[i] = Shapes.prepare(part, i)
		end
		local kept = Sampling.exposure(parts).kept
		local isCopy, isDust, hider = Oracle.flags(parts)
		for i = 1, #parts do
			if not isCopy[i] and not isDust[i] then
				checked += 1
				local rough = Oracle.measure(parts, i, hider, Oracle.COARSE_POINTS)
				local what = d.name .. ", part " .. i .. " (" .. tostring(d.parts[i].label) .. ")"
				if kept[i] and rough < KEPT_FROM + COARSE_SLACK then
					A.truthy(Oracle.share(parts, i, hider) >= KEPT_FROM, what .. " is kept and does not show")
				elseif not kept[i] and rough > CLEANED_UNDER - COARSE_SLACK then
					A.truthy(Oracle.share(parts, i, hider) < CLEANED_UNDER, what .. " is cleaned and shows")
				end
			end
		end
	end
	A.truthy(designs > SWEEP_SHARE * 20000, "designs swept: " .. designs)
	A.truthy(checked > 8 * designs, "parts checked: " .. checked)
end

return Test.suite("Physics/VerdictPrecision", function(t)
	t.it("E-S2.11 the oracle against closed forms: caps, arcs, a slot, a sunk plate, a cut wedge, coincident faces, the probe", function()
		checkClosedForms(2, Oracle.COARSE_POINTS, 0.003)
		-- and what hides for it: neither exact copies nor Dust
		local a = solid("Block", { 0, 0, 0 }, I, { 0.3, 0.3, 0.3 })
		local speck = solid("Block", { 0, 0.175, 0 }, I, { 0.05, 0.05, 0.05 })
		local isCopy, isDust, hider = Oracle.flags(prepared({ a, a, speck }, I))
		A.deepEq(isCopy, { false, true, false })
		A.deepEq(isDust, { false, false, true })
		A.deepEq(hider, { true, false, false })
	end)

	t.slow("E-S2.11 the oracle against closed forms, 5 whole-design turns, its fine lattice", function()
		checkClosedForms(#TURNS, Oracle.MIN_POINTS, 0.0003)
	end)

	t.slow("E-S2.12 the verdict against the oracle on a tenth of the plausible families and the attack designs: nothing that shows 4 % cleaned, nothing under 1.9 % kept", function()
		sweep()
	end)
end)
