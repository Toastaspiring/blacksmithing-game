--!strict
-- S3 prototype: final bot tables, determinism checks, replay cost, payload sizes, false-positive estimates
local HZ = require("./HoldZone")
local TS = require("./TimingStrike")
local PT = require("./PrecisionTrace")
local Params = require("./Params")
local Timeline = require("./Timeline")
local Bots = require("./Bots")
local BHZ = require("./BotsHZ")
local BTS = require("./BotsTS")
local BPT = require("./BotsPT")
local process = require("@lune/process")

local SECTION = process.args[1] or "all"
local NHZ = tonumber(process.args[2]) or 300
local NTS = tonumber(process.args[3]) or 2000
local NPT = tonumber(process.args[4]) or 150

local function want(s: string): boolean
	return SECTION == "all" or SECTION == s
end

local CONFIGS = {
	{ "Iron/Normal", "Iron", "Normal", nil },
	{ "Iron/Hard", "Iron", "Hard", nil },
	{ "Steel/Hard", "Steel", "Hard", nil },
}
local COMPLEX = { Volume = 1, Thinness = 1, PartCount = 1, Asymmetry = 1, SurfaceComplexity = 1 }

local function seedOf(i: number, salt: number): number
	return (i * 2654435761 + salt) % 4294967296
end

local function flagNames(list: { { string } }): string
	local count: { [string]: number } = {}
	for _, fl in list do
		for _, f in fl do
			count[f] = (count[f] or 0) + 1
		end
	end
	local out = {}
	for f, c in count do
		table.insert(out, string.format("%s %.1f%%", f, 100 * c / #list))
	end
	table.sort(out)
	return table.concat(out, ", ")
end

-------------------------------------------------------------------------- params
if want("params") then
	for _, fam in { "HoldZone", "TimingStrike", "PrecisionTrace" } do
		print("\n### resolved params: " .. fam)
		local keys = {}
		for k in Params.DEFS[fam] do
			table.insert(keys, k)
		end
		table.sort(keys)
		print("| param | Iron/Normal | Iron/Hard | Steel/Normal | Steel/Hard | Steel/Hard complex |")
		print("|---|---|---|---|---|---|")
		local sets = {
			Params.resolve(fam, "Iron", "Normal", nil),
			Params.resolve(fam, "Iron", "Hard", nil),
			Params.resolve(fam, "Steel", "Normal", nil),
			Params.resolve(fam, "Steel", "Hard", nil),
			Params.resolve(fam, "Steel", "Hard", COMPLEX),
		}
		for _, k in keys do
			local row = { k }
			for _, s in sets do
				table.insert(row, string.format("%.4g", s[k]))
			end
			print("| " .. table.concat(row, " | ") .. " |")
		end
	end
end

-------------------------------------------------------------------------- HoldZone
if want("hz") then
	print("\n### HoldZone bots (N=" .. NHZ .. " per row)")
	print(Bots.HEADER)
	local function run(label: string, mat: string, tier: string, factors: any, bot: string)
		local p = Params.resolve("HoldZone", mat, tier, factors)
		local scores, passes, flags, fl = {}, {}, {}, {}
		local pressRate = 0
		for i = 1, NHZ do
			local pat = HZ.generate(seedOf(i, 1), p)
			local ev, res
			if bot == "pwm10" then
				ev, res = BHZ.pwm(pat)
			elseif bot == "mpcExact" then
				ev, res = BHZ.mpc(pat, 0)
			elseif bot == "mpcHuman" then
				ev, res = BHZ.mpc(pat, 100)
			else
				ev, res = BHZ.human(pat, BHZ.PROFILES[bot], i * 7919 + 17)
			end
			local pr = 0
			for _, e in ev do
				if e.down then
					pr += 1
				end
			end
			pressRate += pr / (pat.durationMs / 1000)
			scores[i], passes[i], flags[i], fl[i] = res.score, res.passed, #res.flags > 0, res.flags
		end
		print(Bots.row(label .. " " .. mat .. "/" .. tier, Bots.stats(scores, passes, flags)) .. string.format(" presses/s %.1f %s", pressRate / NHZ, flagNames(fl)))
	end
	for _, c in CONFIGS do
		for _, bot in { "pwm10", "mpcExact", "mpcHuman", "elite", "good", "poor" } do
			run(bot, c[2], c[3], c[4], bot)
		end
	end
	for _, bot in { "elite", "good", "poor" } do
		run(bot .. " complex", "Steel", "Hard", COMPLEX, bot)
	end
end

-------------------------------------------------------------------------- TimingStrike
if want("ts") then
	print("\n### TimingStrike bots (N=" .. NTS .. " per row)")
	print(Bots.HEADER)
	local function run(label: string, mat: string, tier: string, factors: any, bot: string)
		local p = Params.resolve("TimingStrike", mat, tier, factors)
		local scores, passes, flags, fl = {}, {}, {}, {}
		for i = 1, NTS do
			local pat = TS.generate(seedOf(i, 2), p)
			local presses
			if bot == "exact" then
				presses = BTS.exact(pat)
			elseif bot == "spam50" then
				presses = BTS.spammer(pat, 50)
			elseif bot == "metronome" then
				presses = BTS.metronome(pat)
			else
				presses = BTS.human(pat, BTS.PROFILES[bot], i * 7919 + 3)
			end
			local res = TS.replay(pat, presses)
			scores[i], passes[i], flags[i], fl[i] = res.score, res.passed, #res.flags > 0, res.flags
		end
		print(Bots.row(label .. " " .. mat .. "/" .. tier, Bots.stats(scores, passes, flags)) .. " " .. flagNames(fl))
	end
	for _, c in CONFIGS do
		for _, bot in { "exact", "noisyCheat", "elite", "good", "poor", "metronome", "spam50" } do
			run(bot, c[2], c[3], c[4], bot)
		end
	end
	for _, bot in { "elite", "good", "poor" } do
		run(bot .. " complex", "Steel", "Hard", COMPLEX, bot)
	end
end

-------------------------------------------------------------------------- PrecisionTrace
local SOURCES: { [string]: { number }? } = {}
for _, b in BPT.BLADES do
	SOURCES[b[1] :: string] = PT.edgeToPanel(b[2] :: any)
end
local LONG = "longsword (2 edges, 3.6 st)"
local FLAM = "flamberge (wavy, voxel 0.05 st)"

if want("ptpath") then
	print("\n### PrecisionTrace path derivation (seed 42)")
	print("| blade edge | source pts | path pts | L (panel u) | travel Normal (ms) | travel Hard (ms) | fallback | generate (ms) |")
	print("|---|---|---|---|---|---|---|---|")
	local pN = Params.resolve("PrecisionTrace", "Iron", "Normal", nil)
	local pH = Params.resolve("PrecisionTrace", "Iron", "Hard", nil)
	for _, b in BPT.BLADES do
		local name = b[1] :: string
		local src = SOURCES[name]
		local t0 = os.clock()
		local pat = PT.generate(42, pN, src)
		local gen = (os.clock() - t0) * 1000
		local patH = PT.generate(42, pH, src)
		print(string.format("| %s | %d | %d | %.2f | %d | %d | %s | %.1f |", name, if src then #src // 2 else 0, #pat.pu, pat.L, pat.travelMs, patH.travelMs, if pat.usedFallback then "yes" else "no", gen))
	end
end

if want("pt") then
	print("\n### PrecisionTrace bots (N=" .. NPT .. " per row; longsword unless noted)")
	print(Bots.HEADER)
	local function run(label: string, mat: string, tier: string, factors: any, bot: string, blade: string)
		local p = Params.resolve("PrecisionTrace", mat, tier, factors)
		local scores, passes, flags, fl = {}, {}, {}, {}
		local A, P, C = 0, 0, 0
		for i = 1, NPT do
			local pat = PT.generate(seedOf(i, 3), p, SOURCES[blade])
			local samples
			if bot == "perfect" then
				samples = BPT.perfect(pat, 0, 20, i)
			elseif bot == "perfectNoisy" then
				samples = BPT.perfect(pat, 0.004, 20, i)
			elseif bot == "sparse200" then
				samples = BPT.perfect(pat, 0, 200, i)
			else
				samples = BPT.human(pat, BPT.PROFILES[bot], i * 7919 + 5)
			end
			local res = PT.replay(pat, samples)
			scores[i], passes[i], flags[i], fl[i] = res.score, res.passed, #res.flags > 0, res.flags
			A += res.accuracy
			P += res.pacing
			C += res.coverage
		end
		print(Bots.row(label .. " " .. mat .. "/" .. tier, Bots.stats(scores, passes, flags)) .. string.format(" A %.2f P %.2f C %.2f %s", A / NPT, P / NPT, C / NPT, flagNames(fl)))
	end
	for _, c in CONFIGS do
		for _, bot in { "perfect", "perfectNoisy", "sparse200", "elite", "good", "poor" } do
			run(bot, c[2], c[3], c[4], bot, LONG)
		end
	end
	for _, bot in { "elite", "good", "poor" } do
		run(bot .. " flamberge complex", "Steel", "Hard", COMPLEX, bot, FLAM)
	end
end

-------------------------------------------------------------------------- determinism + codec + cost
if want("det") then
	print("\n### determinism: live session vs server replay vs encode->decode->replay")
	local mism = { HoldZone = 0, TimingStrike = 0, PrecisionTrace = 0 }
	local runs = 60
	local bytes = { HoldZone = {}, TimingStrike = {}, PrecisionTrace = {} }
	local cost = { HoldZone = 0, TimingStrike = 0, PrecisionTrace = 0 }
	for i = 1, runs do
		local tier = if i % 2 == 0 then "Hard" else "Normal"
		-- HoldZone
		do
			local pat = HZ.generate(seedOf(i, 11), Params.resolve("HoldZone", "Iron", tier, nil))
			local ev, live = BHZ.human(pat, BHZ.PROFILES.good, i)
			local b = Timeline.encode("HoldZone", pat.durationMs, pat.hash, ev)
			table.insert(bytes.HoldZone, buffer.len(b))
			local dec, h = Timeline.decode(b, "HoldZone", pat.durationMs)
			assert(dec, h)
			local t0 = os.clock()
			local rep = HZ.replay(pat, dec)
			cost.HoldZone += os.clock() - t0
			if rep.score ~= live.score or h ~= pat.hash then
				mism.HoldZone += 1
			end
		end
		-- TimingStrike
		do
			local pat = TS.generate(seedOf(i, 12), Params.resolve("TimingStrike", "Iron", tier, nil))
			local presses = BTS.human(pat, BTS.PROFILES.good, i)
			local live = BTS.live(pat, presses)
			local b = Timeline.encode("TimingStrike", pat.durationMs, pat.hash, presses)
			table.insert(bytes.TimingStrike, buffer.len(b))
			local dec, h = Timeline.decode(b, "TimingStrike", pat.durationMs)
			assert(dec, h)
			local t0 = os.clock()
			local rep = TS.replay(pat, dec)
			cost.TimingStrike += os.clock() - t0
			if rep.score ~= live.score or h ~= pat.hash then
				mism.TimingStrike += 1
			end
		end
		-- PrecisionTrace
		do
			local pat = PT.generate(seedOf(i, 13), Params.resolve("PrecisionTrace", "Iron", tier, nil), SOURCES[LONG])
			local samples = BPT.human(pat, BPT.PROFILES.good, i)
			local live = BPT.live(pat, samples)
			local b = Timeline.encode("PrecisionTrace", pat.durationMs, pat.hash, samples)
			table.insert(bytes.PrecisionTrace, buffer.len(b))
			local dec, h = Timeline.decode(b, "PrecisionTrace", pat.durationMs)
			assert(dec, h)
			local t0 = os.clock()
			local rep = PT.replay(pat, dec)
			cost.PrecisionTrace += os.clock() - t0
			if rep.score ~= live.score or h ~= pat.hash then
				mism.PrecisionTrace += 1
			end
		end
	end
	print("| family | runs | live/replay/codec mismatches | replay+checks cost (ms, mean) | timeline bytes (min / mean / max) | max allowed bytes |")
	print("|---|---|---|---|---|---|")
	for _, fam in { "HoldZone", "TimingStrike", "PrecisionTrace" } do
		local bs = bytes[fam]
		local mn, mx, sm = math.huge, 0, 0
		for _, v in bs do
			mn, mx, sm = math.min(mn, v), math.max(mx, v), sm + v
		end
		print(string.format("| %s | %d | %d | %.2f | %d / %d / %d | %d |", fam, runs, mism[fam], cost[fam] / runs * 1000, mn, sm // #bs, mx, Timeline.HEADER_BYTES + Timeline.MAX_RECORDS[fam] * Timeline.RECORD_BYTES[fam]))
	end
	-- malformed inputs
	local pat = TS.generate(5, Params.resolve("TimingStrike", "Iron", "Normal", nil))
	local good = Timeline.encode("TimingStrike", pat.durationMs, pat.hash, { 100, 200 })
	local bad = buffer.create(buffer.len(good))
	buffer.copy(bad, 0, good)
	buffer.writeu32(bad, 4, pat.durationMs + 1)
	print("decode wrong duration ->", select(2, Timeline.decode(bad, "TimingStrike", pat.durationMs)))
	print("decode wrong family ->", select(2, Timeline.decode(good, "HoldZone", pat.durationMs)))
	local hz = Timeline.encode("HoldZone", 15000, 0, { { t = 10, down = true }, { t = 20, down = true } })
	print("decode HoldZone not alternating ->", select(2, Timeline.decode(hz, "HoldZone", 15000)))
	local past = Timeline.encode("TimingStrike", 1000, 0, { 500, 1200 })
	print("decode past end ->", select(2, Timeline.decode(past, "TimingStrike", 1000)))
end

-------------------------------------------------------------------------- false positives
if want("fp") then
	print("\n### false-positive estimate for the inhuman-input flags")
	local NFP = tonumber(process.args[5]) or 200000
	for _, tier in { "Normal", "Hard" } do
		for _, prof in { "elite", "elite240", "good" } do
			local p = Params.resolve("TimingStrike", "Iron", tier, nil)
			local flagged = 0
			local lowVar, exact = 0, 0
			for i = 1, NFP do
				local pat = TS.generate(seedOf(i, 77), p)
				local res = TS.replay(pat, BTS.human(pat, BTS.PROFILES[prof], i * 31 + 7))
				if #res.flags > 0 then
					flagged += 1
				end
				for _, f in res.flags do
					if f == "TS_LowVariance" then
						lowVar += 1
					elseif f == "TS_ExactHits" then
						exact += 1
					end
				end
			end
			print(string.format("TimingStrike %s %s: flagged %d / %d (LowVariance %d, ExactHits %d)", tier, prof, flagged, NFP, lowVar, exact))
		end
	end
	-- HoldZone: max presses in any 1 s window for human bots
	local maxRate = 0
	for i = 1, 300 do
		local pat = HZ.generate(seedOf(i, 78), Params.resolve("HoldZone", "Iron", "Hard", nil))
		local ev = BHZ.human(pat, BHZ.PROFILES.elite, i)
		local presses = {}
		for _, e in ev do
			if e.down then
				table.insert(presses, e.t)
			end
		end
		local j = 1
		for k = 1, #presses do
			while presses[k] - presses[j] >= 1000 do
				j += 1
			end
			maxRate = math.max(maxRate, k - j + 1)
		end
	end
	print("HoldZone elite human: max presses in any 1000 ms window over 300 runs =", maxRate, "(flag at >= " .. HZ.RATE_MAX_PRESSES .. ")")
	-- PrecisionTrace elite: flags over many runs + min observed mean deviation / jerk
	local NP = tonumber(process.args[6]) or 400
	local minDev, minJerk, flagged = math.huge, math.huge, 0
	for i = 1, NP do
		local tier = if i % 2 == 0 then "Hard" else "Normal"
		local pat = PT.generate(seedOf(i, 79), Params.resolve("PrecisionTrace", "Iron", tier, nil), SOURCES[LONG])
		local samples = BPT.human(pat, BPT.PROFILES.elite, i * 13 + 1)
		local fl, m = PT.checks(pat, samples)
		if #fl > 0 then
			flagged += 1
		end
		minDev = math.min(minDev, m.meanDev)
		minJerk = math.min(minJerk, m.meanJerk)
	end
	print(string.format("PrecisionTrace elite: flagged %d / %d; min mean deviation %.4f (flag < %.4f); min mean jerk %.5f (flag < %.5f)", flagged, NP, minDev, PT.PRECISE_MEAN_DEV, minJerk, PT.SMOOTH_MEAN_JERK))
end
