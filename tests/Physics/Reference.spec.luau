--!strict
-- SPEC §4.1: "Sampling details are pinned by the reference prototype". M2 against docs/spec/prototypes/S2/v2/ on the
-- prototype's own fixtures: budgets, cleaning and every physics number, the sub-grid and overlap counts, and each surface
-- sample bit for bit. The build differs from the prototype on purpose in the rules §4.3, §4.4 and §4.5 state: exact copies,
-- the Enclosed verdict (per part, exact on its polyhedral model, no budget of its own), the measure of the kept parts alone
-- on a ladder of their own (the prototype's rule, once), a part with no volume of its own, the overlap budget's kept parts
-- first, no axis vote past 45°; the rank, where the prototype goes by index, for which it is handed the parts in rank order;
-- and in exact clipping's cut face, which MassProps builds from the plane so that faces nearly coplanar with a cut stay right
-- (it moves these cases by about 1e-15). Only two of these cases meet those rules in a number compared here, listed below,
-- and a design with cleaned parts counts its measure's samples on the kept parts alone: anything else that moves fails. The
-- prototype fills its 32 directions from math.cos and math.sin when it loads, so a libm that rounds differently from the one the
-- literals were generated with would show up here first.
-- The prototype keeps its own copy of the budgets: a retune of Balance.Geometry (§4.9's fallback, say) ends what this spec
-- can compare, and is the moment to retire it, not to edit the prototype.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local H = require("./PhysicsHelpers")
local Balance = require("../../src/shared/Definitions/Balance")
local WorkSet = require("../../src/shared/Blueprint/WorkSet")
local Analyze = require("../../src/shared/Physics/Analyze")
local Sampling = require("../../src/shared/Physics/Sampling")
local Shapes = require("../../src/shared/Physics/Shapes")

-- Through a cast, so luau-lsp stays out of the prototype's loose types: it is reference data, not game code.
local Proto: any = (require :: any)("../../docs/spec/prototypes/S2/v2/analyze")
local Fixtures: any = (require :: any)("../../docs/spec/prototypes/S2/v2/fixtures")
local Num: any = (require :: any)("../../docs/spec/prototypes/S2/v2/num")
local ProtoShapes: any = (require :: any)("../../docs/spec/prototypes/S2/v2/shapes")

local Geo = Balance.Geometry
local PHYSICS = { "mass", "volume", "guardPos", "balance", "balanceFromHand", "reach", "bladeLength", "totalLength", "comOffAxis" }
local ABS = 1e-12

-- The verdict differs on P1 alone (§4.4): 2 parts that show 2.09 and 5.59 % are kept, Enclosed in the prototype (part 2, which
-- shows 2.042 % and reads 2.042 % on its model, is kept by both). What follows from that row, and nothing else, is exempt below,
-- and pinned where it has a number of its own:
-- the measure's grid, finer than the prototype's over all parts, and what is read on it, SurfaceComplexity's areas and Joints'
-- contact rows; the volume probes' grid, kept parts only; and through ownership, kept parts first, the volume and everything
-- that weighs it.
local OWN_VERDICT: { [string]: { any } } = {
	P1 = {
		{ partId = 6, reason = "Enclosed" },
		{ partId = 8, reason = "Enclosed" },
		{ partId = 11, reason = "Enclosed" },
		{ partId = 12, reason = "Enclosed" },
		{ partId = 13, reason = "Enclosed" },
		{ partId = 15, reason = "Enclosed" },
		{ partId = 16, reason = "Enclosed" },
		{ partId = 18, reason = "Enclosed" },
		{ partId = 22, reason = "Enclosed" },
	},
}
-- A grip part past 45° from +Y has no vote (§4.5): the axis, and what is measured along it, differ. Mass, COM, reach and
-- the grip point do not.
local NO_VOTE: { [string]: boolean } = { P2 = true }
local ALONG_AXIS: { [string]: boolean } = {
	guardPos = true, balance = true, balanceFromHand = true, bladeLength = true, totalLength = true, comOffAxis = true,
}
local WEIGHED: { [string]: boolean } = { mass = true, volume = true, balance = true, balanceFromHand = true, comOffAxis = true }

-- The prototype's lower index keeps a coincident face, owns an overlap and spends a budget first, where the build's higher rank
-- in the measure does: on the parts in the measure's rank order the two rules are one.
local function inRankOrder(b: any): any
	local list: { any } = {}
	for i, part in ipairs(b.parts) do
		list[i] = Shapes.prepare(part, i)
	end
	local _, order = Sampling.measureRanked(list)
	local parts: { any } = {}
	for r, p in ipairs(order) do
		parts[r] = b.parts[p.index]
	end
	return { name = b.name, parts = parts }
end

local function byId(cleaned: { any }?): { any }
	local out = table.clone(cleaned or {})
	table.sort(out, function(a: any, c: any): boolean
		return a.partId < c.partId
	end)
	return out
end

local function agreeOn(blueprints: { any })
	for _, b in ipairs(blueprints) do
		local what = b.name
		local core: any = { schema = 1, name = what, type = "Sword", parts = b.parts }
		local mine = Analyze.run(core, { measureInvalid = true })
		local theirs = Proto.run(inRankOrder(b), { measureInvalid = true })
		local inOrder = Proto.run(b, { measureInvalid = true })
		local tag = string.sub(what, 1, 2)
		local _, exposure, owned = H.measure(core)
		local ownVerdict = OWN_VERDICT[tag]
		A.deepEq(mine.cleaned, ownVerdict or byId(theirs.cleaned), what .. " cleaned")
		A.eq(mine.validation.ok, inOrder.validation.ok, what .. " verdict")
		A.deepEq(mine.validation.errors, inOrder.validation.errors, what .. " errors")
		-- the measure's budgets: the prototype's where nothing is cleaned; else samples on the kept parts alone
		local kept = 0
		for i, part in ipairs(b.parts) do
			if exposure.kept[i] then
				kept += ProtoShapes.surfaceSamples(ProtoShapes.prepare(part, i), mine.budget.hSurf, Geo.NS_MAX).n
			end
		end
		A.eq(mine.budget.surfSamples, kept, what .. " surface samples")
		if #mine.cleaned == 0 then
			A.eq(mine.budget.surfSamples, theirs.surfSamples, what .. " surface samples, all parts")
		end
		if ownVerdict then
			A.truthy(mine.budget.hSurf < theirs.hSurf, what .. " the kept parts fit a finer grid")
		else
			A.eq(mine.budget.hSurf, theirs.hSurf, what .. " hSurf")
			A.eq(mine.budget.hVol, theirs.hVol, what .. " hVol")
			A.eq(mine.budget.volSamples, theirs.volSamples, what .. " volume samples")
		end
		local p: any, q: any = mine.physics, theirs.physics
		for _, field in ipairs(PHYSICS) do
			if not (NO_VOTE[tag] and ALONG_AXIS[field]) and not (ownVerdict and WEIGHED[field]) then
				A.near(p[field], q[field], ABS, what .. " " .. field)
			end
		end
		for k = 1, 3 do
			if not ownVerdict then
				A.near(p.com[k], q.com[k], ABS, what .. " COM")
			end
			A.near(p.gripPoint[k], q.gripPoint[k], ABS, what .. " grip point")
		end
		-- what the exemptions leave free: P1's on the build's kept row, by its own numbers; P2's the prototype's formulas on the
		-- build's axis, by the prototype's centre of mass and grip point
		if ownVerdict then
			A.eq(mine.budget.hSurf, 0.32000000000000001, what .. " hSurf")
			A.eq(mine.budget.hVol, 0.15000000000000002, what .. " hVol")
			A.eq(mine.budget.volSamples, 7245, what .. " volume samples")
			A.near(p.mass, 17.850935677033441, 1e-9, what .. " mass")
			A.near(p.volume, 2.2682256260525335, 1e-9, what .. " volume")
			A.near(p.com[2], 2.4926181549629498, 1e-9, what .. " COM y")
			A.near(p.com[1], 0.012006968545309067, 1e-9, what .. " COM x")
			A.near(p.com[3], 0.00044862872391563177, 1e-9, what .. " COM z")
			A.near(p.balance, 0.16822653163686932, 1e-9, what .. " balance")
			A.near(p.balanceFromHand, 0.41747511140832499, 1e-9, what .. " balanceFromHand")
			A.near(p.comOffAxis, 0.017139267321934232, 1e-9, what .. " comOffAxis")
			-- the measure on the kept row: what is read on its grid, and the overlap counts
			local area, touch = 0, 0
			for i = 1, #b.parts do
				area += exposure.exposedKept[i]
				for j = 1, #b.parts do
					touch += exposure.contact[i][j]
				end
			end
			A.near(area, 15.870818181818183, 1e-9, what .. " exposed area")
			A.near(touch, 1196.954500000001, 1e-9, what .. " contact rows")
			A.eq(exposure.subSampled, 58, what .. " patches sub-gridded")
			A.eq(owned.hOverlap, 0.20000000000000001, what .. " hOverlap")
			A.eq(owned.refinedCells, 6940, what .. " refined cells")
		end
		if NO_VOTE[tag] then
			-- parts 3 and 4 lean 45° and 50°: the first still has a vote, by the 0.00055° that 0.7071 leaves above 45°
			local ax, ay = -math.sqrt(0.5), math.sqrt(0.5)
			A.near(p.gripAxis[1], ax, ABS, what .. " grip axis x")
			A.near(p.gripAxis[2], ay, ABS, what .. " grip axis y")
			local dx, dy = q.com[1] - q.gripPoint[1], q.com[2] - q.gripPoint[2]
			A.near(p.balanceFromHand, dx * ax + dy * ay, ABS, what .. " balanceFromHand along the build's axis")
			A.near(p.comOffAxis, dx * ay - dy * ax, ABS, what .. " comOffAxis about the build's axis")
			A.near(p.balance, p.balanceFromHand - p.guardPos, ABS, what .. " balance")
			A.near(p.guardPos, 0.5497454358018049, 1e-9, what .. " guardPos")
			A.near(p.bladeLength, 2.1072627984509777, 1e-9, what .. " bladeLength")
			A.near(p.totalLength, 3.5802050204472708, 1e-9, what .. " totalLength")
		else
			for k = 1, 2 do
				A.near(p.gripAxis[k], q.gripAxis[k], ABS, what .. " grip axis")
			end
		end
		-- the counts behind them, where nothing is cleaned and so no rule of the build's own applies
		if #mine.cleaned == 0 then
			A.eq(exposure.subSampled, theirs.subSampled, what .. " patches sub-gridded")
			A.eq(owned.hOverlap, theirs.hOverlap, what .. " hOverlap")
			A.eq(owned.refinedCells, theirs.refinedCells, what .. " refined cells")
		end
		-- SurfaceComplexity (§5.2, M3) reads exposedKept over the owned volume, on a step's work set
		for _, step in ipairs(if ownVerdict then {} else theirs.steps or {}) do
			for _, factor in ipairs(step.factors) do
				if factor.factor == "SurfaceComplexity" and (step.step == "Hammering" or step.step == "Sharpening") then
					local selector: any = if step.step == "Hammering" then "All" else { "Blade" }
					local area, volume = 0, 0
					for _, i in ipairs(WorkSet.select(b.parts, exposure.kept, selector)) do
						area += exposure.exposedKept[i]
						volume += owned.ownedVolume[i]
					end
					local c = Num.cbrt(volume)
					A.near(area / (6 * c * c), factor.raw, ABS, what .. " " .. step.step .. " surface complexity")
				end
			end
		end
	end
end

return Test.suite("Physics/Reference", function(t)
	t.it("§4.1 M2 equals the prototype on its calibration swords", function()
		agreeOn(Fixtures.calibration())
	end)

	t.it("§4.1 M2 equals the prototype on its F1–F5", function()
		agreeOn(Fixtures.golden())
	end)

	t.it("§4.1 M2 equals the prototype on its cost fixtures P1–P5", function()
		agreeOn(Fixtures.perf())
	end)

	-- Of the prototype's fixtures only P1 has a cleaned list of its own (§4.4): the near copies, fins and hidden cores of these two
	-- groups, their bases and the validation cases clean what the prototype cleans.
	local function sameCleaned(blueprints: { any })
		for _, b in ipairs(blueprints) do
			local core: any = { schema = 1, name = b.name, type = "Sword", parts = b.parts }
			A.deepEq(Analyze.run(core, { measureInvalid = true }).cleaned, byId(Proto.run(inRankOrder(b), { measureInvalid = true }).cleaned), b.name)
		end
	end
	local function withBases(rows: { any }): { any }
		local out, seen = {}, {}
		for _, r in ipairs(rows) do
			for _, b in ipairs({ r.fixture, r.base }) do
				if not seen[b.name] then
					seen[b.name] = true
					table.insert(out, b)
				end
			end
		end
		return out
	end

	t.it("§4.4 the verdict cleans what the prototype cleans on its adversarial fixtures and their bases, and its validation cases", function()
		sameCleaned(withBases(Fixtures.adversarial()))
		sameCleaned(Fixtures.validation())
	end)

	t.it("§4.4 the verdict cleans what the prototype cleans on its regression fixtures X01–X07 and their bases", function()
		sameCleaned(withBases(Fixtures.regression()))
	end)

	-- §5: hidden parts cannot buy or dodge a tier. In the prototype they do, on these two: its D is the evidence that the
	-- rule is needed, and exposedKept is all a hidden part could reach D through (M3's T-DIF-04 checks D itself).
	local function namedFixture(prefix: string): any
		for _, b in ipairs(Fixtures.calibration()) do
			if string.sub(b.name, 1, #prefix) == prefix then
				return b
			end
		end
		error("no fixture " .. prefix)
	end
	local function hammering(parts: { any }, stepName: string): any
		for _, step in ipairs(Proto.run({ name = "x", parts = parts }).steps) do
			if step.step == stepName then
				return step
			end
		end
		error("no step " .. stepName)
	end
	local function bare(parts: { any }): { any }
		local out = {}
		for i, part in ipairs(parts) do
			out[i] = Shapes.prepare(part, i)
		end
		return out
	end
	local function flipCase(baseParts: { any }, filled: { any }, stepName: string, tierBefore: string, tierAfter: string,
		hSurfAfter: number)
		local before, after = Sampling.exposure(bare(baseParts)), Sampling.exposure(bare(filled))
		A.eq(hammering(baseParts, stepName).tier, tierBefore, "the prototype before")
		A.eq(hammering(filled, stepName).tier, tierAfter, "the prototype with the fill")
		A.eq(Proto.run({ name = "x", parts = filled }).hSurf, hSurfAfter, "the fill coarsens the prototype's grid")
		A.eq(#after.cleaned, #filled - #baseParts, "all the fill is cleaned")
		A.eq(after.surfSamples, before.surfSamples, "and not measured")
		H.sameKeptMeasure(after, before, #baseParts)
	end

	t.it("§5 9 enclosed blocks cannot buy Hard: C04 with a 0.075 blade, Normal in the build, Hard in the prototype", function()
		local base = {}
		local blade: any = nil
		for i, part in ipairs(namedFixture("C04").parts) do
			local copy = table.clone(part)
			copy.size = { part.size[1], part.size[2], part.size[3] }
			if part.label == "Blade" then
				copy.size[3] = 0.075
				blade = copy
			end
			base[i] = copy
		end
		local filled = table.clone(base)
		for k = 1, 9 do
			local f = 0.96 - 0.02 * k
			table.insert(filled, { id = 100 + k, slot = "Blade", shape = "Block", material = "Iron", pos = blade.pos,
				rot = blade.rot, size = { blade.size[1] * f, blade.size[2] * f, blade.size[3] * f } })
		end
		flipCase(base, filled, "Hammering", "Normal", "Hard", 0.08)
	end)

	t.it("§5 6 enclosed blocks cannot dodge Hard: C09 with a blade 0.05 longer, Hard in the build, Normal in the prototype", function()
		local delta = 0.05
		local base = {}
		local core: any = nil
		for i, part in ipairs(namedFixture("C09").parts) do
			local copy = table.clone(part)
			copy.pos = { part.pos[1], part.pos[2], part.pos[3] }
			copy.size = { part.size[1], part.size[2], part.size[3] }
			if part.label == "Core" then
				copy.pos[2] += delta / 2
				copy.size[2] += delta
				core = copy
			elseif string.sub(part.label, 1, 5) == "Bevel" then
				copy.pos[2] += delta / 2
				copy.size[1] += delta
			elseif string.sub(part.label, 1, 3) == "Tip" then
				copy.pos[2] += delta
			end
			base[i] = copy
		end
		local filled = table.clone(base)
		for k = 1, 6 do
			local g = 0.75 - 0.005 * k
			table.insert(filled, { id = 18 + k, slot = if k <= 5 then "Blade" else "Pommel", shape = "Block", material = "Iron",
				pos = core.pos, rot = H.I, size = { core.size[1] * g, core.size[2] * g, core.size[3] * g } })
		end
		flipCase(base, filled, "Sharpening", "Hard", "Normal", 0.06)
	end)

	t.it("PhysicsHelpers.ornate is the prototype's C09, until M3's fixture replaces it", function()
		local c09: any = nil
		for _, b in ipairs(Fixtures.calibration()) do
			if string.sub(b.name, 1, 3) == "C09" then
				c09 = b
			end
		end
		local mine = H.ornate()
		A.eq(#mine.parts, #c09.parts)
		for i, p in ipairs(mine.parts) do
			local q = c09.parts[i]
			A.deepEq({ p.id, p.slot, p.shape, p.material, p.pos, p.rot, p.size }, { q.id, q.slot, q.shape, q.material, q.pos, q.rot, q.size }, "part " .. i)
		end
	end)

	t.it("§4.3 every surface sample is the prototype's, bit for bit: 5 shapes × 8 sizes", function()
		local SIZES = { { 0.3, 0.5, 0.2 }, { 1.2, 0.05, 0.3 }, { 0.8, 0.06, 0.06 }, { 0.3, 0.2, 0.2 }, { 2, 0.9, 0.9 },
			{ 0.1, 0.1, 0.1 }, { 0.7, 0.7, 0.7 }, { 0.5, 0.3, 0.3 } }
		local FIELDS = { "x", "y", "z", "w", "nx", "ny", "nz", "e1x", "e1y", "e1z", "e2x", "e2y", "e2z" }
		for _, shape in ipairs({ "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }) do
			for _, s in ipairs(SIZES) do
				local size = if shape == "Ball" then { s[1], s[1], s[1] } elseif shape == "Cylinder" then { s[1], s[2], s[2] } else s
				local part = H.solid(1, shape, { 0.1, 2, -0.05 }, H.axisAngle(1, 2, 3, 40), size)
				local mine: any = Sampling.surfaceSamples(H.prepare(part), Geo.H_SURF)
				local theirs = ProtoShapes.surfaceSamples(ProtoShapes.prepare(part, 1), Geo.H_SURF, Geo.NS_MAX)
				A.eq(mine.n, theirs.n, shape .. " count")
				for _, field in ipairs(FIELDS) do
					for k = 1, mine.n do
						if mine[field][k] ~= theirs[field][k] then
							A.fail(string.format("%s %s[%d]: %.17g, the prototype's %.17g", shape, field, k, mine[field][k], theirs[field][k]))
						end
					end
				end
			end
		end
	end)

	t.it("§4.1 the unit circle's literals are the prototype's bits, and math.cos and math.sin's", function()
		for k = 0, 31 do
			local angle = 2 * Shapes.PI * k / 32
			A.eq(Sampling.COS[k + 1], Num.COS[k + 1], "COS " .. k)
			A.eq(Sampling.SIN[k + 1], Num.SIN[k + 1], "SIN " .. k)
			A.eq(Sampling.COS[k + 1], math.cos(angle), "COS " .. k)
			A.eq(Sampling.SIN[k + 1], math.sin(angle), "SIN " .. k)
		end
	end)
end)
