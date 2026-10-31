--!strict
-- S3 prototype v2: determinism and codec checks.
-- (1) live session == server replay == encode -> decode -> replay, per family, bots with random frame partitions;
-- (2) decode cost on the longest honest timelines; (3) malformed timelines rejected with the expected reason.
local HZ = require("./HoldZone")
local TS = require("./TimingStrike")
local PT = require("./PrecisionTrace")
local Params = require("./Params")
local Bots = require("./Bots")
local Sim = require("./Sim")
local Timeline = require("./Timeline")
local N = 150
local mism = { HoldZone = 0, TimingStrike = 0, PrecisionTrace = 0 }
local bytes = { HoldZone = {}, TimingStrike = {}, PrecisionTrace = {} }
local profs = { "Elite", "Good", "Average", "Poor" }
for i = 1, N do
	local prof = (Bots.PROFILES :: any)[profs[(i % 4) + 1]]
	local tier = if i % 2 == 0 then "Normal" else "Hard"
	local mat = if i % 3 == 0 then "Steel" else "Iron"
	local seed = Sim.seedOf(i, 99)
	-- HoldZone: live (bot drives the live session frame by frame) vs replay vs codec
	do
		local p = Params.resolve("HoldZone", mat, tier, Params.refFactors(0.2))
		local pat = HZ.generate(seed, p)
		local ev, live = Bots.hzHuman(pat, prof, i, "pump")
		local rep = HZ.replay(pat, ev)
		local b = Timeline.encode("HoldZone", pat.durationMs, pat.hash, ev)
		local dec, h = Timeline.decode(b, "HoldZone", pat.durationMs)
		local rep2 = HZ.replay(pat, dec)
		if live.score ~= rep.score or rep.score ~= rep2.score or h ~= pat.hash then
			mism.HoldZone += 1
		end
		table.insert(bytes.HoldZone, buffer.len(b))
	end
	-- TimingStrike: live = press per frame + advance(now), finish
	do
		local p = Params.resolve("TimingStrike", mat, tier, Params.refFactors(0.2))
		local pat = TS.generate(seed, p)
		local presses = Bots.tsHuman(pat, prof, i, 0)
		local s = TS.newSession(pat)
		local j = 1
		local now = 0
		while now <= pat.durationMs do
			now += 16 + (i % 7) -- arbitrary frame partition
			while j <= #presses and presses[j] <= now do
				TS.press(s, presses[j])
				j += 1
			end
			TS.advance(s, now)
		end
		local live = TS.finish(s)
		local rep = TS.replay(pat, presses)
		local b = Timeline.encode("TimingStrike", pat.durationMs, pat.hash, presses)
		local dec, h = Timeline.decode(b, "TimingStrike", pat.durationMs)
		local rep2 = TS.replay(pat, dec)
		if live.score ~= rep.score or rep.score ~= rep2.score or h ~= pat.hash then
			mism.TimingStrike += 1
		end
		table.insert(bytes.TimingStrike, buffer.len(b))
	end
	-- PrecisionTrace: live = push each sample when taken, advance to the latest sample time
	do
		local p = Params.resolve("PrecisionTrace", mat, tier, Params.refFactors(0.2))
		local pat = PT.generate(seed, p, Sim.source("arming", p.pacerSpeed))
		local smp = Bots.ptHuman(pat, prof, i)
		local s = PT.newSession(pat)
		for _, sm in smp do
			PT.push(s, sm)
			PT.advance(s, sm.t)
		end
		local live = PT.finish(s)
		local rep = PT.replay(pat, smp)
		local b = Timeline.encode("PrecisionTrace", pat.durationMs, pat.hash, smp)
		local dec, h = Timeline.decode(b, "PrecisionTrace", pat.durationMs)
		local rep2 = PT.replay(pat, dec)
		if live.score ~= rep.score or rep.score ~= rep2.score or h ~= pat.hash then
			mism.PrecisionTrace += 1
		end
		table.insert(bytes.PrecisionTrace, buffer.len(b))
	end
end
for _, f in { "HoldZone", "TimingStrike", "PrecisionTrace" } do
	local bs = bytes[f]
	table.sort(bs)
	local sum = 0
	for _, v in bs do sum += v end
	print(string.format("%s: %d runs, mismatches %d, timeline bytes min %d mean %.0f max %d", f, N, mism[f], bs[1], sum / #bs, bs[#bs]))
end
-- decode cost: longest honest PT timeline (31 s, 1551 records) and the caps
local recs = {}
for k = 0, 1550 do
	table.insert(recs, { t = k * 20, u = 20000 + k, v = 8000, grind = true })
end
local b = Timeline.encode("PrecisionTrace", 31000, 0, recs)
local t0 = os.clock()
for _ = 1, 20 do
	Timeline.decode(b, "PrecisionTrace", 31000)
end
print(string.format("PT decode 1551 records (%d B): %.3f ms", buffer.len(b), (os.clock() - t0) * 1000 / 20))
-- malformed
local function expect(name: string, bb: any, fam: string, dur: number, want: string)
	local r, code = Timeline.decode(bb, fam, dur)
	print(string.format("  %-14s -> %s %s", name, tostring(code), if r == nil and code == want then "ok" else "FAIL"))
end
print("malformed:")
expect("not a buffer", "abc", "HoldZone", 15000, "NotBuffer")
expect("short", buffer.create(5), "HoldZone", 15000, "Short")
local good = Timeline.encode("HoldZone", 15000, 7, { { t = 0, down = true }, { t = 100, down = false } })
local v = buffer.create(buffer.len(good)); buffer.copy(v, 0, good); buffer.writeu8(v, 0, 2)
expect("version", v, "HoldZone", 15000, "Version")
expect("family", good, "TimingStrike", 15000, "Family")
expect("duration", good, "HoldZone", 15010, "Duration")
local na = Timeline.encode("HoldZone", 15000, 7, { { t = 0, down = true }, { t = 100, down = true } })
expect("not alternating", na, "HoldZone", 15000, "NotAlternating")
local pe = Timeline.encode("TimingStrike", 1000, 7, { 500, 1200 })
expect("past end", pe, "TimingStrike", 1000, "PastEnd")
local ni = Timeline.encode("PrecisionTrace", 1000, 7, { { t = 0, u = 1, v = 1, grind = true }, { t = 0, u = 1, v = 1, grind = true } })
expect("not increasing", ni, "PrecisionTrace", 1000, "NotIncreasing")
local op = Timeline.encode("PrecisionTrace", 1000, 7, { { t = 0, u = 49153, v = 1, grind = true } })
expect("out of panel", op, "PrecisionTrace", 1000, "OutOfPanel")
