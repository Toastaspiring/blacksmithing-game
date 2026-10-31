--!strict
local TS = require("./TimingStrike")
local Bots = require("./Bots")
local process = require("@lune/process")
local N = tonumber(process.args[1]) or 1500

type Prof = { sigma: number, bias: number, lapse: number, fps: number }
local PROFILES: { [string]: Prof } = {
	elite = { sigma = 12, bias = 0, lapse = 0.0, fps = 60 },
	good = { sigma = 25, bias = 5, lapse = 0.02, fps = 60 },
	poor = { sigma = 45, bias = 15, lapse = 0.05, fps = 60 },
}

local function human(pat: TS.Pattern, prof: Prof, seed: number): { number }
	local r = Bots.rng(seed, "ts-human")
	local frameMs = 1000 / prof.fps
	local phase = r:range(0, frameMs)
	local out = {}
	for _, c in pat.cycles do
		local t
		if r:nextFloat() < prof.lapse then
			if r:nextFloat() < 0.5 then
				t = c.target + r:range(-300, 300)
			end
		else
			t = c.target + prof.bias + prof.sigma * Bots.gauss(r) - frameMs / 2
		end
		if t then
			local q = math.floor(math.ceil((t - phase) / frameMs) * frameMs + phase)
			q = math.clamp(q, 0, pat.durationMs)
			if #out == 0 or q >= out[#out] then
				table.insert(out, q)
			end
		end
	end
	return out
end

local BASE = {
	strikes = 12, beatMs = 900, windowMs = 110, perfectFrac = 0.3, edgePoints = 0.35, tempoJitter = 0.08,
	offsetMin = 0.40, offsetMax = 0.75, missPadMs = 90, tailMs = 400, passThreshold = 0.5,
}
local function with(o: { [string]: number }): { [string]: number }
	local p = table.clone(BASE)
	for k, v in o do
		p[k] = v
	end
	return p
end

local CONFIGS = {
	{ "N W90 pf.12 e.25", with({ windowMs = 90, perfectFrac = 0.12, edgePoints = 0.25 }) },
	{ "N W80 pf.12 e.25", with({ windowMs = 80, perfectFrac = 0.12, edgePoints = 0.25 }) },
	{ "N W100 pf.10 e.20", with({ windowMs = 100, perfectFrac = 0.1, edgePoints = 0.2 }) },
	{ "H W70 pf.12 e.25 b765 j.12 15", with({ windowMs = 70, perfectFrac = 0.12, edgePoints = 0.25, beatMs = 765, tempoJitter = 0.12, strikes = 15 }) },
	{ "H W62 pf.12 e.25 b765 j.12 15", with({ windowMs = 62, perfectFrac = 0.12, edgePoints = 0.25, beatMs = 765, tempoJitter = 0.12, strikes = 15 }) },
	{ "H W78 pf.10 e.20 b765 j.12 15", with({ windowMs = 78, perfectFrac = 0.1, edgePoints = 0.2, beatMs = 765, tempoJitter = 0.12, strikes = 15 }) },
}

print(Bots.HEADER)
for _, cfg in CONFIGS do
	local label, p = cfg[1] :: string, cfg[2] :: { [string]: number }
	for _, bot in { "elite", "good", "poor" } do
		local scores, passes, flags = {}, {}, {}
		for i = 1, N do
			local pat = TS.generate((i * 2654435761 + 12345) % 4294967296, p)
			local res = TS.replay(pat, human(pat, PROFILES[bot], i * 7919 + 3))
			scores[i], passes[i], flags[i] = res.score, res.passed, #res.flags > 0
		end
		print(Bots.row(label .. " " .. bot, Bots.stats(scores, passes, flags)))
	end
end
