--!strict
-- S3 prototype v2: inhuman-input checks: false positives on human bots, true positives on cheats.
local HZ = require("./HoldZone")
local TS = require("./TimingStrike")
local PT = require("./PrecisionTrace")
local Params = require("./Params")
local Bots = require("./Bots")
local Sim = require("./Sim")
local process = require("@lune/process")
local NTS = tonumber(process.args[1]) or 100000
local NPT = tonumber(process.args[2]) or 1000
print("## TimingStrike FP (human bots) and TP (cheats)")
for _, tier in { "Normal", "Hard" } do
	local p = Params.resolve("TimingStrike", "Iron", tier, Params.refFactors(0))
	for _, spec in { { "Elite", 240 }, { "Elite", 60 }, { "Good", 60 }, { "Average", 30 } } do
		local prof = Bots.variant((Bots.PROFILES :: any)[spec[1]], spec[2])
		local flagged, minSd = 0, math.huge
		for i = 1, NTS do
			local pat = TS.generate(Sim.seedOf(i, 7), p)
			local r = TS.replay(pat, Bots.tsHuman(pat, prof, i * 13 + 5, 0))
			if #r.flags > 0 then flagged += 1 end
		end
		print(string.format("%s %s@%d: flagged %d / %d", tier, spec[1], spec[2], flagged, NTS))
	end
	-- cheats
	local nC = 2000
	local fx, fn, sn = 0, 0, 0
	for i = 1, nC do
		local pat = TS.generate(Sim.seedOf(i, 8), p)
		local exact = {}
		for _, c in pat.cycles do table.insert(exact, c.target) end
		local r1 = TS.replay(pat, exact)
		if #r1.flags > 0 then fx += 1 end
		local rr = Bots.rng(i, "cheat")
		local noisy = {}
		for _, c in pat.cycles do table.insert(noisy, math.max(0, math.round(c.target + 4 * Bots.gauss(rr)))) end
		table.sort(noisy)
		local r2 = TS.replay(pat, noisy)
		if #r2.flags > 0 then fn += 1 end
		sn += r2.score
	end
	print(string.format("%s cheats: exact flagged %.1f%%; noisy sigma 4 ms flagged %.1f%% (mean score %.3f)", tier, fx / nC * 100, fn / nC * 100, sn / nC))
end
print("## PrecisionTrace FP margins (arming sword) and cheats")
for _, tier in { "Normal", "Hard" } do
	local p = Params.resolve("PrecisionTrace", "Iron", tier, Params.refFactors(0))
	local src = Sim.source("arming", p.pacerSpeed)
	for _, spec in { { "Elite", 240, 520 }, { "Elite", 60, 520 }, { "Elite", 30, 360 }, { "Good", 60, 520 } } do
		local prof = table.clone(Bots.variant((Bots.PROFILES :: any)[spec[1]], spec[2])) :: any
		prof.panelPx = spec[3]
		local flagged, minDev, minJerk = 0, math.huge, math.huge
		for i = 1, NPT do
			local pat = PT.generate(Sim.seedOf(i, 9), p, src)
			local smp = Bots.ptHuman(pat, prof, i * 17 + 3)
			local fl, info = PT.checks(pat, smp)
			if #fl > 0 then flagged += 1 end
			if info.devN >= PT.PRECISE_MIN_SAMPLES then minDev = math.min(minDev, info.meanDev) end
			if info.jerkN >= PT.SMOOTH_MIN_TRIPLETS then minJerk = math.min(minJerk, info.meanJerk) end
		end
		print(string.format("%s %s@%d/%dpx: flagged %d / %d; min mean deviation %.4f (threshold %.4f, x%.1f); min mean jerk %.5f (threshold %.4f, x%.0f)",
			tier, spec[1], spec[2], spec[3], flagged, NPT, minDev, PT.PRECISE_MEAN_DEV, minDev / PT.PRECISE_MEAN_DEV, minJerk, PT.SMOOTH_MEAN_JERK, minJerk / PT.SMOOTH_MEAN_JERK))
	end
	local nC = 200
	local res = { perfect = { 0, 0 }, noisy = { 0, 0 }, sparse = { 0, 0 } }
	for i = 1, nC do
		local pat = PT.generate(Sim.seedOf(i, 10), p, src)
		for key, cfg in { perfect = { 0, 20 }, noisy = { 0.004, 20 }, sparse = { 0, 200 } } do
			local r = PT.replay(pat, Bots.ptPerfect(pat, cfg[1], cfg[2], i))
			res[key][1] += r.score
			if #r.flags > 0 then res[key][2] += 1 end
		end
	end
	print(string.format("%s cheats: perfect %.3f flagged %.0f%% | noisy 0.004 %.3f flagged %.0f%% | sparse 200 ms %.3f flagged %.0f%%", tier,
		res.perfect[1] / nC, res.perfect[2] / nC * 100, res.noisy[1] / nC, res.noisy[2] / nC * 100, res.sparse[1] / nC, res.sparse[2] / nC * 100))
end
print("## HoldZone: presses per 1 s window (human pump) and cheats")
for _, tier in { "Normal", "Hard" } do
	local p = Params.resolve("HoldZone", "Iron", tier, Params.refFactors(0))
	for _, name in { "Elite", "Good", "Average" } do
		local prof = (Bots.PROFILES :: any)[name]
		local maxW, flagged = 0, 0
		for i = 1, 500 do
			local pat = HZ.generate(Sim.seedOf(i, 11), p)
			local ev, r = Bots.hzHuman(pat, prof, i, "pump")
			if #r.flags > 0 then flagged += 1 end
			local pr = {}
			for _, e in ev do if e.down then table.insert(pr, e.t) end end
			local j = 1
			for k = 1, #pr do
				while pr[k] - pr[j] >= 1000 do j += 1 end
				maxW = math.max(maxW, k - j + 1)
			end
		end
		print(string.format("%s %s pump: max presses in any 1 s window %d (flag at %d); flagged %d / 500", tier, name, maxW, HZ.RATE_MAX_PRESSES, flagged))
	end
	local sP, fP, maxP = 0, 0, 0
	for i = 1, 100 do
		local pat = HZ.generate(Sim.seedOf(i, 12), p)
		local ev, r = Bots.hzPerfect(pat)
		sP += r.score
		if #r.flags > 0 then fP += 1 end
		local pr = {}
		for _, e in ev do if e.down then table.insert(pr, e.t) end end
		local j = 1
		for k = 1, #pr do
			while pr[k] - pr[j] >= 1000 do j += 1 end
			maxP = math.max(maxP, k - j + 1)
		end
	end
	-- autoclicker: a press every 33 ms whenever the needle is below the zone (30/s)
	local pat = HZ.generate(1, p)
	local ev = {}
	local t = 0
	while t + 10 < pat.durationMs do table.insert(ev, { t = t, down = true }); table.insert(ev, { t = t + 10, down = false }); t += 33 end
	local ra = HZ.replay(pat, ev)
	print(string.format("%s Perfect (MPC, exact state): mean %.3f, max presses/s %d, flagged %d / 100; 30/s autoclicker flags: %s", tier, sP / 100, maxP, fP, table.concat(ra.flags, ",")))
end
