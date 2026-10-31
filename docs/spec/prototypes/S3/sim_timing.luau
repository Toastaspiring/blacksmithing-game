--!strict
-- S3 prototype: TimingStrike bots
local TS = require("./TimingStrike")
local Params = require("./Params")
local Bots = require("./Bots")
local process = require("@lune/process")
local N = tonumber(process.args[1]) or 2000

type Prof = { sigma: number, bias: number, lapse: number, fps: number, quant: boolean }
local PROFILES: { [string]: Prof } = {
	elite = { sigma = 12, bias = 0, lapse = 0.0, fps = 60, quant = true },
	elite240 = { sigma = 10, bias = 0, lapse = 0.0, fps = 240, quant = true },
	good = { sigma = 25, bias = 5, lapse = 0.02, fps = 60, quant = true },
	poor = { sigma = 45, bias = 15, lapse = 0.05, fps = 60, quant = true },
	noisyCheat = { sigma = 4, bias = 0, lapse = 0, fps = 60, quant = false },
}

-- first frame time >= t
local function quantize(frames: { number }, t: number): number
	-- binary search
	local lo, hi = 1, #frames
	if t <= frames[1] then
		return frames[1]
	end
	while lo < hi do
		local mid = (lo + hi) // 2
		if frames[mid] < t then
			lo = mid + 1
		else
			hi = mid
		end
	end
	return frames[lo]
end

local function human(pat: TS.Pattern, prof: Prof, seed: number): { number }
	local r = Bots.rng(seed, "ts-human")
	local frames = Bots.frames(r, pat.durationMs + 500, prof.fps, 0.003)
	local frameMs = 1000 / prof.fps
	local presses = {}
	local p = pat.p
	local sigma = prof.sigma * (1 + 0.2 * math.max(0, 1000 / p.beatMs - 1)) * (1 + p.tempoJitter)
	for _, c in pat.cycles do
		if r:nextFloat() < prof.lapse then
			if r:nextFloat() < 0.5 then
				local t = c.target + r:range(-300, 300)
				table.insert(presses, t)
			end -- else: no press at all
		else
			-- humans learn to compensate the mean frame delay (half a frame)
			local t = c.target + prof.bias + sigma * Bots.gauss(r) - (if prof.quant then frameMs / 2 else 0)
			table.insert(presses, t)
		end
	end
	table.sort(presses)
	local out = {}
	for _, t in presses do
		local q
		if prof.quant then
			q = quantize(frames, t)
		else
			q = math.floor(t + 0.5)
		end
		q = math.clamp(q, 0, pat.durationMs)
		if #out == 0 or q >= out[#out] then
			table.insert(out, q)
		end
	end
	return out
end

local function exact(pat: TS.Pattern): { number }
	local out = {}
	for _, c in pat.cycles do
		table.insert(out, c.target)
	end
	return out
end

local function spammer(pat: TS.Pattern, period: number): { number }
	local out = {}
	local t = 0
	while t <= pat.durationMs do
		table.insert(out, t)
		t += period
	end
	return out
end

local function metronome(pat: TS.Pattern): { number }
	-- ignores the seeded offset: always presses at the mean offset of each cycle
	local out = {}
	local p = pat.p
	for _, c in pat.cycles do
		table.insert(out, c.start + math.floor((p.offsetMin + p.offsetMax) / 2 * c.period + 0.5))
	end
	return out
end

local function batch(label: string, material: string, tier: string, factors: { [string]: number }?, bot: string)
	local p = Params.resolve("TimingStrike", material, tier, factors)
	local scores, passes, flags = {}, {}, {}
	for i = 1, N do
		local pat = TS.generate((i * 2654435761 + 12345) % 4294967296, p)
		local presses
		if bot == "exact" then
			presses = exact(pat)
		elseif bot == "spam50" then
			presses = spammer(pat, 50)
		elseif bot == "spam150" then
			presses = spammer(pat, 150)
		elseif bot == "metronome" then
			presses = metronome(pat)
		else
			presses = human(pat, PROFILES[bot], i * 7919 + 3)
		end
		local res = TS.replay(pat, presses)
		scores[i], passes[i], flags[i] = res.score, res.passed, #res.flags > 0
	end
	print(Bots.row(string.format("%s %s/%s", label, material, tier), Bots.stats(scores, passes, flags)))
end

print(Bots.HEADER)
for _, tier in { "Normal", "Hard" } do
	for _, bot in { "exact", "noisyCheat", "elite", "elite240", "good", "poor", "metronome", "spam50", "spam150" } do
		batch(bot, "Iron", tier, nil, bot)
	end
end
for _, bot in { "elite", "good", "poor" } do
	batch(bot .. " Steel", "Steel", "Hard", nil, bot)
	batch(bot .. " complex(all=1)", "Steel", "Hard", { Thinness = 1, PartCount = 1, Asymmetry = 1 }, bot)
end
for _, tier in { "Normal", "Hard" } do
	local p = Params.resolve("TimingStrike", "Iron", tier, nil)
	local pat = TS.generate(1, p)
	print(tier, "strikes", p.strikes, "beat", p.beatMs, "W", pat.W, "M", pat.M, "dur", pat.durationMs, "jitter", p.tempoJitter)
end
