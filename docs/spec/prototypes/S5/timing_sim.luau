--!strict
-- Monte-Carlo of the step submission window (Lune 0.8.9): lune run timing_sim.luau
-- Revised (R3-20): the RTT allowance A = min(2 * median(ping samples), RTT_ALLOW_MAX_MS), samples taken at t_open and
-- every 250 ms while the step plays, instead of one sample at t_open. Both rules are reported for comparison.
math.randomseed(20261031)

local function normal(): number
	local u1 = math.max(math.random(), 1e-12)
	local u2 = math.random()
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end
local function uniform(a: number, b: number): number
	return a + (b - a) * math.random()
end
local function median(xs: { number }): number
	table.sort(xs)
	local n = #xs
	return if n % 2 == 1 then xs[(n + 1) // 2] else (xs[n // 2] + xs[n // 2 + 1]) / 2
end

-- Latency model (ms). Assumptions, not measurements:
--  per-player base RTT ~ lognormal(median 120 ms, sigma 0.6)      -> p90 ~260 ms, p99 ~490 ms
--  each ping sample and the submission RTT: base x lognormal(0, 0.25); 2 % of submissions carry a spike of +0.3..4 s
--  1 % of submissions are delayed by a client hitch of 0.1..1.5 s
--  server/client frame quantization 3 x U(0, 16.7) ms; client clock drift +-100 ppm
local FRAME = 1000 / 60
local COUNTDOWN, SWEEP = 3000, 250

local function sample(D: number): (number, number, number)
	local base = 120 * math.exp(0.6 * normal())
	local pings = {}
	local k = (COUNTDOWN + D) // SWEEP + 1
	for i = 1, k do
		pings[i] = base * math.exp(0.25 * normal())
	end
	local pingOpen = pings[1]
	local rtt = base * math.exp(0.25 * normal())
	if math.random() < 0.02 then
		rtt += uniform(300, 4000)
	end
	local hitch = if math.random() < 0.01 then uniform(100, 1500) else 0
	local frames = uniform(0, FRAME) + uniform(0, FRAME) + uniform(0, FRAME)
	local drift = D * uniform(-100e-6, 100e-6)
	return D + rtt + hitch + frames + drift, pingOpen, median(pings)
end

local N = 400000
local RTT_ALLOW_MAX, EARLY_TOL = 2000, 250
local LATES = { 1000, 1500, 2500, 5000, 10000 }
for _, D in { 7000, 15000, 31000 } do
	local fpOpen, fpMed = {}, {}
	for i = 1, #LATES do
		fpOpen[i], fpMed[i] = 0, 0
	end
	local early = 0
	for _ = 1, N do
		local e, pOpen, pMed = sample(D)
		local aOpen = math.min(2 * pOpen, RTT_ALLOW_MAX)
		local aMed = math.min(2 * pMed, RTT_ALLOW_MAX)
		for i, L in LATES do
			if e > D + L + aOpen then fpOpen[i] += 1 end
			if e > D + L + aMed then fpMed[i] += 1 end
		end
		if e < D - EARLY_TOL then
			early += 1
		end
	end
	print(string.format("D = %d ms, N = %d honest submissions: early false positives %d", D, N, early))
	for i, L in LATES do
		print(string.format("  tolerance %5d ms: beyond D + tol + A   A(open) %.4f %%   A(median) %.4f %%", L, fpOpen[i] / N * 100, fpMed[i] / N * 100))
	end
end

-- Slow-motion cheater: plays at speed 1/k and reports real-time timestamps.
-- Flagged iff (k - 1) * D > LATE_SOFT + A - rtt; timed out iff (k - 1) * D > LATE_HARD + A - rtt.
-- A sustained ping inflation to >= 1000 ms raises A to its 2000 ms cap under either rule; a one-sample spike at
-- t_open only does so under the old rule.
print("slow motion k beyond which a step is flagged (LATE_SOFT 1500) / timed out (LATE_HARD 5000):")
for _, d in { 7000, 11500, 15000, 31000 } do
	local kFlag = 1 + (1500 + 200 - 100) / d
	local kFlagInfl = 1 + (1500 + 2000 - 1000) / d
	local kOut = 1 + (5000 + 200 - 100) / d
	local kOutInfl = 1 + (5000 + 2000 - 1000) / d
	print(string.format("  D = %5d ms: flagged k > %.3f (ping 100) / %.3f (ping held at 1 s); timed out k > %.3f / %.3f", d, kFlag, kFlagInfl, kOut, kOutInfl))
end
