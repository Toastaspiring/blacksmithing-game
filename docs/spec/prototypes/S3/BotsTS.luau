--!strict
-- TimingStrike scripted bots (not authoritative code)
local TS = require("./TimingStrike")
local Bots = require("./Bots")

export type Prof = { sigma: number, bias: number, lapse: number, fps: number, quant: boolean }
local M = {}
M.PROFILES = {
	elite = { sigma = 12, bias = 0, lapse = 0.0, fps = 60, quant = true },
	elite240 = { sigma = 10, bias = 0, lapse = 0.0, fps = 240, quant = true },
	good = { sigma = 25, bias = 5, lapse = 0.02, fps = 60, quant = true },
	poor = { sigma = 45, bias = 15, lapse = 0.05, fps = 60, quant = true },
	noisyCheat = { sigma = 4, bias = 0, lapse = 0, fps = 60, quant = false },
} :: { [string]: Prof }

-- presses snap to the first frame at or after the intended time (input is read once per frame)
function M.human(pat: TS.Pattern, prof: Prof, seed: number): { number }
	local r = Bots.rng(seed, "ts-human")
	local frameMs = 1000 / prof.fps
	local phase = r:range(0, frameMs)
	local p = pat.p
	-- assumption: faster beats and irregular tempo inflate human timing error
	local sigma = prof.sigma * (1 + 0.2 * math.max(0, 1000 / p.beatMs - 1)) * (1 + p.tempoJitter)
	local raw = {}
	for _, c in pat.cycles do
		local t
		if r:nextFloat() < prof.lapse then
			if r:nextFloat() < 0.5 then
				t = c.target + r:range(-300, 300)
			end
		else
			t = c.target + prof.bias + sigma * Bots.gauss(r) - (if prof.quant then frameMs / 2 else 0)
		end
		if t then
			table.insert(raw, t)
		end
	end
	table.sort(raw)
	local out = {}
	for _, t in raw do
		local q
		if prof.quant then
			q = math.floor(math.ceil((t - phase) / frameMs) * frameMs + phase)
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

function M.exact(pat: TS.Pattern): { number }
	local out = {}
	for _, c in pat.cycles do
		table.insert(out, c.target)
	end
	return out
end

function M.spammer(pat: TS.Pattern, period: number): { number }
	local out = {}
	local t = 0
	while t <= pat.durationMs do
		table.insert(out, t)
		t += period
	end
	return out
end

function M.metronome(pat: TS.Pattern): { number }
	local out = {}
	local p = pat.p
	for _, c in pat.cycles do
		table.insert(out, c.start + math.floor((p.offsetMin + p.offsetMax) / 2 * c.period + 0.5))
	end
	return out
end

-- replays presses through a LIVE session (press on arrival, advance per 16 ms frame)
function M.live(pat: TS.Pattern, presses: { number }): TS.Result
	local s = TS.newSession(pat)
	local i = 1
	local f = 0
	while f <= pat.durationMs + 16 do
		while i <= #presses and presses[i] <= f do
			TS.press(s, presses[i])
			i += 1
		end
		TS.advance(s, f)
		f += 16
	end
	local res = TS.finish(s)
	res.flags = TS.checks(pat, res)
	return res
end

return M
