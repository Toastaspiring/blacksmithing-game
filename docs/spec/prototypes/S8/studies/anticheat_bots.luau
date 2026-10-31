--!strict
-- S8 study: (A) false-positive / true-positive rates of an "inhumanly precise timing" check
-- for TimingStrike-like inputs under frame quantization; (B) expected score of a generic
-- linear-falloff timing score vs human timing noise; (C) the same idea for trace lateral error.
-- Run from proto/S8:  lune run studies/anticheat_bots
local TestRng = require("../repo/tests/lib/TestRng")
local rng = TestRng.new(0xA11CE)

-- Box–Muller (study only; bots in the real suite use TestRng:normal, which is transcendental-free)
local spare: number? = nil
local function gauss(): number
	if spare then local s = spare :: number; spare = nil; return s end
	local u1 = math.max(rng:float(), 1e-12)
	local u2 = rng:float()
	local r = math.sqrt(-2 * math.log(u1))
	spare = r * math.sin(2 * math.pi * u2)
	return r * math.cos(2 * math.pi * u2)
end

-- Registered error (integer ms) of one strike: true press = centre + bias + N(0, sd);
-- the client only sees input at the next frame boundary (random frame phase).
local function strikeError(sd: number, bias: number, fps: number?): number
	local e = bias + sd * gauss()
	if fps then
		local frame = 1000 / fps
		local phase = rng:float() * frame
		e = math.ceil((e - phase) / frame) * frame + phase
	end
	return math.floor(e + 0.5)
end

local function sampleSd(xs: { number }): (number, number)
	local n, mean = #xs, 0
	for _, x in xs do mean += x end
	mean /= n
	local ss = 0
	for _, x in xs do ss += (x - mean) * (x - mean) end
	return math.sqrt(ss / (n - 1)), mean
end

print("== A. flag rule: n strikes, sample SD of timing error < tau  (rate of flagged steps)")
local profiles = {
	{ name = "Elite human  sd12 240fps", sd = 12, bias = 3, fps = 240 },
	{ name = "Good human   sd25  60fps", sd = 25, bias = 5, fps = 60 },
	{ name = "Good human   sd25 240fps", sd = 25, bias = 5, fps = 240 },
	{ name = "Cheat exact (no noise)  ", sd = 0, bias = 0, fps = nil },
	{ name = "Cheat gauss sd3 no frame", sd = 3, bias = 0, fps = nil },
	{ name = "Cheat gauss sd5 no frame", sd = 5, bias = 0, fps = nil },
	{ name = "Cheat exact @60fps grid ", sd = 0, bias = 0, fps = 60 },
}
local TAUS = { 2, 3, 4, 5 }
for _, n in { 6, 8, 12 } do
	for _, prof in profiles do
		local trials = if prof.sd >= 12 then 200000 else 20000
		local flagged = table.create(#TAUS, 0)
		local errs = table.create(n, 0)
		for _ = 1, trials do
			for i = 1, n do errs[i] = strikeError(prof.sd, prof.bias, prof.fps) end
			local sd = sampleSd(errs)
			for ti, tau in TAUS do
				if sd < tau then flagged[ti] += 1 end
			end
		end
		local cells = {}
		for ti, tau in TAUS do
			table.insert(cells, string.format("tau=%d: %-9s", tau, if flagged[ti] == 0 then string.format("<%.0e", 1 / trials) else string.format("%.2e", flagged[ti] / trials)))
		end
		print(string.format("  n=%-2d %s  %s", n, prof.name, table.concat(cells, " ")))
	end
end

print("\n== B. generic linear-falloff strike score s = max(0, 1 - |e|/W): E[s] and hit rate P(|e|<=W)")
print("     (frame quantization 60 fps, bias +5 ms; 40k strikes per cell)")
local SDS = { 12, 25, 45, 90 }
local header = "      W\\sd "
for _, sd in SDS do header ..= string.format("   sd=%-3d       ", sd) end
print(header)
for _, W in { 60, 90, 120, 150 } do
	local row = string.format("  W=%-4d   ", W)
	for _, sd in SDS do
		local sum, hits, N = 0, 0, 40000
		for _ = 1, N do
			local e = math.abs(strikeError(sd, 5, 60))
			if e <= W then hits += 1; sum += 1 - e / W end
		end
		row ..= string.format("E=%.3f hit=%.2f ", sum / N, hits / N)
	end
	print(row)
end

print("\n== C. trace lateral error: OU noise (tau_c=150 ms) sampled at fps; flag if SD over >=60 samples < tau_px")
local function ouSeries(sdPx: number, fps: number, samples: number): { number }
	local dt = 1000 / fps
	local a = math.exp(-dt / 150)
	local x = sdPx * gauss()
	local out = table.create(samples, 0)
	for i = 1, samples do
		x = a * x + sdPx * math.sqrt(1 - a * a) * gauss()
		out[i] = math.floor(x * 10 + 0.5) / 10 -- 0.1 px resolution
	end
	return out
end
for _, prof in { { name = "Good human sd4px  60fps", sd = 4, fps = 60 }, { name = "Elite human sd2px 144fps", sd = 2, fps = 144 }, { name = "Cheat on-path sd0.2px  ", sd = 0.2, fps = 60 } } do
	local trials = 20000
	local flagged = { 0, 0, 0 }
	local tauPx = { 0.5, 0.75, 1.0 }
	for _ = 1, trials do
		local s = ouSeries(prof.sd, prof.fps, 90)
		local sd = sampleSd(s)
		for i, tp in tauPx do if sd < tp then flagged[i] += 1 end end
	end
	print(string.format("  %s  tau=0.5px: %.2e  tau=0.75px: %.2e  tau=1.0px: %.2e", prof.name, flagged[1] / trials, flagged[2] / trials, flagged[3] / trials))
end
