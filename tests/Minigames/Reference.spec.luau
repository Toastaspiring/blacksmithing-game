--!strict
-- Minigames/Reference (SPEC §6.13, E-S3.2; M4's D1, D11 and D14, its plan [6.3] "Reference"): the build against the S3
-- prototype (docs/spec/prototypes/S3/v2/), Lune only, t.slow (plain L3).
-- Parity: Bots.run with the prototype's seeds (salt 1, i = 1…100: Sim.run's) gives exactly the first 100 scores of each
-- of the 48 cells of the shipped S3-score-distributions.luau, the distributions S4 tunes rarity on and E-S3.2's table
-- came from. With it, every fixed-seed statistic of L3 (T-MG-03 to T-MG-12) is the prototype's, known before the build
-- (D11). Each of those 4,800 timelines is also honest (judged Ok, within L6's cap) and, fed to the prototype's own
-- session, gives the build's unquantized sums. Scores only: the records differ in ways that move none (Bots' header).
-- E-S3.2's table, as MinigamesHelpers.ES32 copies it for T-MG-04's bands, is those distributions' mean and SD per cell.
-- Full precision (D1): resolved params, pattern arrays and the sessions' unquantized sums equal the prototype's to the
-- bit, so a regrouped expression shows here even where no hash and no q-score can see it.
-- A mismatch is a porting bug until shown otherwise; the one cause outside the code is this machine's libm, which the
-- bots use (Box–Muller and the OU process): Minigames/Bots' canary says whether it changed.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Edges = require("../fixtures/Edges")
local H = require("./MinigamesHelpers")
local DT = require("../../src/shared/Definitions/Types")
local Bots = require("../../src/shared/Minigames/Bots")
local HoldZone = require("../../src/shared/Minigames/HoldZone")
local Minigames = require("../../src/shared/Minigames/Minigames")
local Params = require("../../src/shared/Minigames/Params")
local PrecisionTrace = require("../../src/shared/Minigames/PrecisionTrace")
local TimingStrike = require("../../src/shared/Minigames/TimingStrike")
local Types = require("../../src/shared/Minigames/Types")

-- Through a cast, so luau-lsp stays out of the prototype's loose types: it is reference data, not game code.
local Distributions: any = (require :: any)("../../docs/spec/prototypes/S3/v2/out/S3-score-distributions")
local ProtoParams: any = (require :: any)("../../docs/spec/prototypes/S3/v2/Params")
local ProtoHZ: any = (require :: any)("../../docs/spec/prototypes/S3/v2/HoldZone")
local ProtoTS: any = (require :: any)("../../docs/spec/prototypes/S3/v2/TimingStrike")
local ProtoPT: any = (require :: any)("../../docs/spec/prototypes/S3/v2/PrecisionTrace")
local ProtoSim: any = (require :: any)("../../docs/spec/prototypes/S3/v2/Sim")

type StepSpec = Types.StepSpec
type MinigameResult = Types.MinigameResult

local PARITY_RUNS = 100
local TIERS_ALL: { DT.TierId } = { "Normal", "Hard", "Expert", "Master", "Hell" }

-- a double as the prototype printed it, for messages
local function g(x: number): string
	return string.format("%.17g", x)
end

-- the prototype's pattern for the build's spec: its params resolved again by the prototype, the trace on its own
-- arming blade (Sim.source), which Edges.arming copies
local function protoPattern(spec: StepSpec, material: string, tier: string, x: number): any
	local p = ProtoParams.resolve(spec.family, material, tier, ProtoParams.refFactors(x))
	if spec.family == "HoldZone" then
		return ProtoHZ.generate(spec.seed, p)
	elseif spec.family == "TimingStrike" then
		return ProtoTS.generate(spec.seed, p)
	end
	return ProtoPT.generate(spec.seed, p, ProtoSim.source("arming", p.pacerSpeed))
end

-- the build's session and the prototype's, fed the same records, end on the same unquantized sums
local function sameSums(family: DT.FamilyId, P: any, Q: any, records: { any }, what: string)
	if family == "HoldZone" then
		local S = HoldZone.newSession(P)
		local s = ProtoHZ.newSession(Q)
		for _, r in ipairs(records) do
			HoldZone.push(S, r)
			ProtoHZ.push(s, { t = r.t, down = r.down })
		end
		HoldZone.finish(S)
		ProtoHZ.finish(s)
		if S.credit ~= s.credit or S.n ~= s.n or S.inZone ~= s.inZone then
			A.fail(string.format("%s: credit %s / n %d / inZone %d, the prototype's %s / %d / %d", what, g(S.credit), S.n,
				S.inZone, g(s.credit), s.n, s.inZone))
		end
	elseif family == "TimingStrike" then
		local S = TimingStrike.newSession(P)
		local s = ProtoTS.newSession(Q)
		for _, t in ipairs(records) do
			TimingStrike.push(S, t)
			ProtoTS.press(s, t)
		end
		TimingStrike.finish(S)
		ProtoTS.finish(s)
		local mine, theirs = 0, 0
		for i = 1, #P.cycles do
			local e, f = S.err[i], s.err[i]
			if e ~= f then
				A.fail(string.format("%s: span %d's error %s, the prototype's %s", what, i, tostring(e), tostring(f)))
			end
			if type(e) == "number" then
				mine += TimingStrike.points(P, e)
				theirs += ProtoTS.points(Q, f)
			end
		end
		if mine ~= theirs then
			A.fail(string.format("%s: Σ points %s, the prototype's %s", what, g(mine), g(theirs)))
		end
	else
		local S = PrecisionTrace.newSession(P)
		local s = ProtoPT.newSession(Q)
		for _, r in ipairs(records) do
			PrecisionTrace.push(S, r)
			ProtoPT.push(s, { t = r.t, u = r.u, v = r.v, grind = r.grind })
		end
		PrecisionTrace.finish(S)
		ProtoPT.finish(s)
		if S.accSum ~= s.accSum or S.paceSum ~= s.paceSum or S.nCovered ~= s.nCovered then
			A.fail(string.format("%s: accSum %s / paceSum %s / covered %d, the prototype's %s / %s / %d", what, g(S.accSum),
				g(S.paceSum), S.nCovered, g(s.accSum), g(s.paceSum), s.nCovered))
		end
	end
end

-- Parity of one family's 16 cells: the scores, and per run an honest timeline and the prototype's sums
local function parity(family: DT.FamilyId)
	local cells = 0
	for _, c in Distributions.cells do
		if c.family == family then
			cells += 1
			local what = string.format("%s %s %s %s", c.family, c.tier, c.material, c.profile)
			local x = (Bots.BOT_REF_X :: any)[c.tier]
			local scores = Bots.run({
				family = family,
				material = c.material,
				tier = c.tier,
				profile = c.profile,
				n = PARITY_RUNS,
				edge = if family == "PrecisionTrace" then Edges.arming else nil,
				each = function(i: number, spec: StepSpec, P: any, records: { any }, result: MinigameResult)
					local run = what .. " run " .. i
					A.truthy(#records <= Minigames.recordCap(spec), run .. ": within the judge's cap (L6)")
					local judged = Minigames.judge(spec, P, Minigames.encode(spec, records), 0)
					A.eq(judged.status, "Ok", run .. ": judged Ok")
					A.eq(judged.rawScore, result.rawScore, run .. ": judge = replay")
					sameSums(family, P, protoPattern(spec, c.material, c.tier, x), records, run)
				end,
			})
			for i = 1, PARITY_RUNS do
				if scores[i] ~= c.scores[i] then
					A.fail(string.format("%s run %d: score %s, the shipped distribution's %s (a porting bug, or this machine's "
						.. "libm: see Minigames/Bots' canary)", what, i, g(scores[i]), g(c.scores[i])))
				end
			end
		end
	end
	A.eq(cells, 16, family .. ": 2 tiers × 2 materials × 4 profiles")
end

return Test.suite("Minigames/Reference", function(t)
	t.slow("parity: HoldZone's 16 cells, 100 runs each, score for score with the shipped distributions", function()
		parity("HoldZone")
	end)

	t.slow("parity: TimingStrike's 16 cells, 100 runs each, score for score with the shipped distributions", function()
		parity("TimingStrike")
	end)

	t.slow("parity: PrecisionTrace's 16 cells, 100 runs each, score for score with the shipped distributions", function()
		parity("PrecisionTrace")
	end)

	t.slow("E-S3.2's table as T-MG-04 reads it (MinigamesHelpers.ES32) is the shipped distributions' mean and SD per cell", function()
		local cells = 0
		for _, c in Distributions.cells do
			cells += 1
			local n = #c.scores
			local sum = 0
			for i = 1, n do
				sum += c.scores[i]
			end
			local mean = sum / n
			local ss = 0
			for i = 1, n do
				ss += (c.scores[i] - mean) * (c.scores[i] - mean)
			end
			local row = H.ES32[string.format("%s %s/%s", c.family, c.material, c.tier)][c.profile]
			local what = string.format("%s %s/%s %s", c.family, c.material, c.tier, c.profile)
			A.eq(string.format("%.3f", row[1]), string.format("%.3f", mean), what .. ": the mean, as E-S3.2 prints it")
			A.eq(string.format("%.3f", row[2]), string.format("%.3f", math.sqrt(ss / (n - 1))), what .. ": the SD")
		end
		A.eq(cells, 48, "every cell")
	end)

	t.slow("full precision: resolved params, 3 families × 2 materials × 5 tiers × x ∈ {0, 0.1, 0.3, 1}", function()
		for fi = 1, #H.FAMILIES do
			local family: DT.FamilyId = H.FAMILIES[fi]
			for mi = 1, #H.MATERIALS do
				local material: DT.MaterialId = H.MATERIALS[mi]
				for ti = 1, #TIERS_ALL do
					local tier: DT.TierId = TIERS_ALL[ti]
					for _, x in { 0, 0.1, 0.3, 1 } do
						local diff = Dump.firstDifference(Params.resolve(family, material, tier, Params.refFactors(x)),
							ProtoParams.resolve(family, material, tier, ProtoParams.refFactors(x)))
						if diff then
							A.fail(string.format("%s %s/%s x = %s: %s", family, material, tier, tostring(x), diff))
						end
					end
				end
			end
		end
	end)

	t.slow("full precision: pattern arrays, seeds 1…20 per family, tier and material, to the bit", function()
		for fi = 1, #H.FAMILIES do
			local family: DT.FamilyId = H.FAMILIES[fi]
			for ti = 1, #H.TIERS do
				local tier: DT.TierId = H.TIERS[ti]
				for mi = 1, #H.MATERIALS do
					local material: DT.MaterialId = H.MATERIALS[mi]
					local x = (Bots.BOT_REF_X :: any)[tier]
					for seed = 1, 20 do
						local what = string.format("%s %s/%s seed %d", family, material, tier, seed)
						local spec, P = H.prepared(family, material, tier, x, seed,
							if family == "PrecisionTrace" then Edges.arming else nil)
						local Q = protoPattern(spec, material, tier, x)
						local mine: any, theirs: any
						if family == "HoldZone" then
							mine = { P.keysT, P.keysC, P.durationMs, P.rampMs, P.hash }
							theirs = { Q.keysT, Q.keysC, Q.durationMs, Q.rampMs, Q.hash }
						elseif family == "TimingStrike" then
							local cycles: { any } = {}
							for i, c in ipairs(P.cycles) do
								cycles[i] = { start = c.start, period = c.period, target = c.target }
							end
							mine = { cycles, P.M, P.W, P.core, P.durationMs, P.hash }
							theirs = { Q.cycles, Q.M, Q.W, Q.core, Q.durationMs, Q.hash }
						else
							mine = { P.pu, P.pv, P.arc, P.L, P.speed, P.leadInMs, P.travelMs, P.durationMs, P.usedFallback, P.hash }
							theirs = { Q.pu, Q.pv, Q.arc, Q.L, Q.speed, Q.leadInMs, Q.travelMs, Q.durationMs, Q.usedFallback, Q.hash }
						end
						local diff = Dump.firstDifference(mine, theirs)
						if diff then
							A.fail(what .. ": " .. diff)
						end
					end
				end
			end
		end
	end)
end)
