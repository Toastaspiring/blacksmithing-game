--!strict
-- S3 prototype v2: worked examples / golden values, resolved parameters, grade bands, HoldZone stroke curves.
local HZ = require("./HoldZone")
local TS = require("./TimingStrike")
local PT = require("./PrecisionTrace")
local Params = require("./Params")
local Blades = require("./Blades")
local function hex(h: number): string return string.format("0x%08X", h) end
print("## Resolved parameters (x = 0 | x = 1 for the step's design factors)")
for _, fam in { "HoldZone", "TimingStrike", "PrecisionTrace" } do
	for _, d in Params.DEFS[fam].params do
		local cells = {}
		for _, c in { { "Iron", "Normal" }, { "Iron", "Hard" }, { "Steel", "Normal" }, { "Steel", "Hard" } } do
			local a = Params.resolve(fam, c[1], c[2], Params.refFactors(0))[d.name]
			local b = Params.resolve(fam, c[1], c[2], Params.refFactors(1))[d.name]
			table.insert(cells, if a == b then string.format("%g", a) else string.format("%g|%g", a, b))
		end
		print(string.format("%s.%s: IN %s  IH %s  SN %s  SH %s", fam, d.name, cells[1], cells[2], cells[3], cells[4]))
	end
end
print("## TimingStrike grade bands (ms) at x = 0 and x = 1")
for _, c in { { "Iron", "Normal" }, { "Iron", "Hard" }, { "Steel", "Hard" } } do
	for _, x in { 0, 1 } do
		local p = Params.resolve("TimingStrike", c[1], c[2], Params.refFactors(x))
		local pat = TS.generate(1, p)
		local W, core, e = pat.W, pat.core, p.edgePoints
		local function at(pts: number): number return core + (1 - pts) / (1 - e) * (W - core) end
		print(string.format("%s/%s x=%d: W %d core %.1f M %d | Perfect (>=0.9) <= %.1f | Good (>=0.6) <= %.1f | Ok <= %d | edge points %.2f", c[1], c[2], x, W, core, pat.M, at(0.9), at(0.6), W, e))
	end
end
print("## TimingStrike golden: seed 1, Iron/Normal, x = 0")
do
	local p = Params.resolve("TimingStrike", "Iron", "Normal", Params.refFactors(0))
	local pat = TS.generate(1, p)
	local tg = {}
	for i = 1, 4 do table.insert(tg, string.format("%d (P %d)", pat.cycles[i].target, pat.cycles[i].period)) end
	print(string.format("N %d W %d core %.1f M %d duration %d hash %s; first targets %s", #pat.cycles, pat.W, pat.core, pat.M, pat.durationMs, hex(pat.hash), table.concat(tg, ", ")))
	-- presses: errors 0, +6, -15, +35, +79, none, -81, then exact
	local errs = { 0, 6, -15, 35, 79, false, -81 }
	local presses = {}
	for i, c in pat.cycles do
		local e = errs[i]
		if e == nil then e = 0 end
		if e ~= false then table.insert(presses, c.target + e) end
	end
	local r = TS.replay(pat, presses)
	local pts = {}
	for i = 1, 7 do
		local e = errs[i]
		table.insert(pts, if e == false then "miss" else string.format("%+d->%.4f", e, TS.points(pat, e :: number)))
	end
	print("points: " .. table.concat(pts, ", ") .. string.format(" | score %.4f meanErrMs %.2f", r.score, r.meanErrMs))
end
print("## PrecisionTrace golden: arming sword (S2 F1 main chain), seed 1, Iron/Normal, x = 0")
do
	local p = Params.resolve("PrecisionTrace", "Iron", "Normal", Params.refFactors(0))
	local b = Blades.arming
	local sides = PT.sidesFromChains(b.chains, b.grip, b.axis)
	local src = PT.edgeToPanel(sides, b.grip, b.axis, p.pacerSpeed) :: { number }
	local pts = {}
	for i = 1, #src, 2 do table.insert(pts, string.format("(%d,%d)", src[i], src[i + 1])) end
	local pat = PT.generate(1, p, src)
	print(string.format("sides %d (A %d pts, B %d pts); source %s", #sides, #sides[1], #sides[2], table.concat(pts, " ")))
	print(string.format("path %d pts, L %.4f, travel %d ms, duration %d ms, speed %.4f, hash %s", #pat.pu, pat.L, pat.travelMs, pat.durationMs, pat.speed, hex(pat.hash)))
	local fb = PT.generate(1, p, nil)
	print(string.format("fallback: %d pts, L %.4f, travel %d, hash %s", #fb.pu, fb.L, fb.travelMs, hex(fb.hash)))
	local bt = Blades.tilted
	local s2 = PT.edgeToPanel(PT.sidesFromChains(bt.chains, bt.grip, bt.axis), bt.grip, bt.axis, p.pacerSpeed) :: { number }
	local same = #s2 == #src
	for i = 1, #src do if s2[i] ~= src[i] then same = false end end
	print("tilted 30 deg grip gives the same source: " .. tostring(same))
end
print("## HoldZone golden: seed 1, Iron/Normal, x = 0")
do
	local p = Params.resolve("HoldZone", "Iron", "Normal", Params.refFactors(0))
	local pat = HZ.generate(1, p)
	local ks = {}
	for i = 1, math.min(5, #pat.keysT) do table.insert(ks, string.format("(%d, %.4f)", pat.keysT[i], pat.keysC[i])) end
	print(string.format("keys %d, first %s, hash %s", #pat.keysT, table.concat(ks, " "), hex(pat.hash)))
	-- scripted input: tap every 300 ms (press 80 ms) from GO
	local ev = {}
	local t = 0
	while t + 80 < pat.durationMs do
		table.insert(ev, { t = t, down = true }); table.insert(ev, { t = t + 80, down = false }); t += 300
	end
	local r = HZ.replay(pat, ev)
	print(string.format("taps every 300 ms: score %.4f inZone %.4f", r.score, r.inZone))
end
print("## HoldZone stroke model: steady temperature vs tap rate (Iron/Normal, full strokes every P ms)")
do
	local p = Params.resolve("HoldZone", "Iron", "Normal", Params.refFactors(0))
	for _, P in { 1000, 600, 400, 300, 250, 200, 150, 100 } do
		local pat = { p = p, keysT = { 0, 60000 }, keysC = { 0.5, 0.5 }, durationMs = 60000, rampMs = 0, hash = 0 }
		local s = HZ.newSession(pat :: any)
		s.hist = { T = {}, C = {} }
		local t = 0
		while t < 60000 do HZ.push(s, { t = t, down = true }); HZ.push(s, { t = t + 50, down = false }); t += P end
		HZ.advance(s, 60000)
		local sum, n, mn, mx = 0, 0, 1, 0
		for k = 4000, 5999 do sum += s.hist.T[k]; n += 1; mn = math.min(mn, s.hist.T[k]); mx = math.max(mx, s.hist.T[k]) end
		print(string.format("tap every %4d ms (%.1f/s): T mean %.3f ripple %.3f", P, 1000 / P, sum / n, mx - mn))
	end
	-- heat-up from cold at max flow (one full stroke per refill)
	local pat = { p = p, keysT = { 0, 60000 }, keysC = { 0.5, 0.5 }, durationMs = 10000, rampMs = 0, hash = 0 }
	local s = HZ.newSession(pat :: any)
	s.hist = { T = {}, C = {} }
	local t = 0
	while t < 10000 do HZ.push(s, { t = t, down = true }); HZ.push(s, { t = t + 50, down = false }); t += 250 end
	HZ.advance(s, 10000)
	print(string.format("max flow from cold: T(1 s) %.3f T(2 s) %.3f T(3 s) %.3f; one stroke from rest raises T by %.3f peak", s.hist.T[99], s.hist.T[199], s.hist.T[299], 0))
	local s1 = HZ.newSession(pat :: any)
	s1.hist = { T = {}, C = {} }
	HZ.push(s1, { t = 0, down = true }); HZ.push(s1, { t = 50, down = false })
	HZ.advance(s1, 5000)
	local pk, pkt = 0, 0
	for k = 0, 499 do if s1.hist.T[k] > pk then pk, pkt = s1.hist.T[k], k * 10 end end
	print(string.format("single full stroke from rest: peak T %.3f at %d ms", pk, pkt))
end
