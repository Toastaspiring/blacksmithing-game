--!strict
-- S3 prototype: helpers for scripted bots (NOT authoritative code; may use libm freely).
local R = require("./Rng")
local Rng = R.Rng

local Bots = {}

function Bots.rng(seed: number, tag: string)
	return Rng.new(seed % 4294967296, tag)
end

function Bots.gauss(r: any): number
	local u1 = r:nextFloat()
	if u1 < 1e-12 then
		u1 = 1e-12
	end
	local u2 = r:nextFloat()
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

-- Ornstein-Uhlenbeck step: x' = -x/tau + sigma*sqrt(2/tau)*dW
function Bots.ou(r: any, x: number, mu: number, sigma: number, tauS: number, dtS: number): number
	local a = math.exp(-dtS / tauS)
	return mu + (x - mu) * a + sigma * math.sqrt(1 - a * a) * Bots.gauss(r)
end

-- 60 fps frame clock with jitter and occasional hitches; returns integer-ms frame times up to endMs
function Bots.frames(r: any, endMs: number, fps: number?, hitchRate: number?): { number }
	local f = {}
	local dt = 1000 / (fps or 60)
	local t = r:range(0, dt) -- random phase of GO vs frames
	while t <= endMs + dt do
		table.insert(f, math.floor(t))
		local step = dt + (r:nextFloat() - 0.5) * 2
		if r:nextFloat() < (hitchRate or 0.003) then
			step += r:range(30, 120)
		end
		t += step
	end
	return f
end

export type Stats = { mean: number, p10: number, p50: number, p90: number, pass: number, flag: number, n: number }

function Bots.stats(scores: { number }, passes: { boolean }, flags: { boolean }): Stats
	local s = table.clone(scores)
	table.sort(s)
	local n = #s
	local sum, pc, fc = 0, 0, 0
	for i = 1, n do
		sum += s[i]
		if passes[i] then
			pc += 1
		end
		if flags[i] then
			fc += 1
		end
	end
	local function q(p: number): number
		local idx = math.clamp(math.floor(p * (n - 1) + 0.5) + 1, 1, n)
		return s[idx]
	end
	return { mean = sum / n, p10 = q(0.10), p50 = q(0.5), p90 = q(0.90), pass = pc / n, flag = fc / n, n = n }
end

function Bots.row(label: string, st: Stats): string
	return string.format(
		"| %-34s | %5.3f | %5.3f | %5.3f | %5.3f | %5.1f%% | %5.1f%% |",
		label,
		st.mean,
		st.p10,
		st.p50,
		st.p90,
		st.pass * 100,
		st.flag * 100
	)
end

Bots.HEADER = "| bot / config                       |  mean |   p10 |   p50 |   p90 |  pass  | flagged|\n|---|---|---|---|---|---|---|"

return Bots
