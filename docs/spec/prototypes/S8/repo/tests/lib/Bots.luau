--!strict
-- tests/lib/Bots.luau — input generators for minigame replay tests. PROTOTYPE (S8):
-- shown for the toy TimingStrike; the real suite adds HoldZone / PrecisionTrace policies
-- that drive each family's incremental simulation (S3 API).
local TestRng = require("./TestRng")

export type Profile = {
	id: string,
	timingSdMs: number, -- σ of press-time error around the ideal moment
	biasMs: number, -- mean press-time error (humans are usually late)
	fps: number?, -- input is seen at the next frame boundary; nil = no quantization (cheat)
	missRate: number, -- probability a press is skipped
}

local Bots = {}

Bots.Profiles = {
	Perfect = { id = "Perfect", timingSdMs = 0, biasMs = 0, fps = nil, missRate = 0 } :: Profile,
	GoodHuman = { id = "GoodHuman", timingSdMs = 25, biasMs = 5, fps = 60, missRate = 0.01 } :: Profile,
	AverageHuman = { id = "AverageHuman", timingSdMs = 45, biasMs = 10, fps = 60, missRate = 0.03 } :: Profile,
	PoorHuman = { id = "PoorHuman", timingSdMs = 90, biasMs = 25, fps = 30, missRate = 0.10 } :: Profile,
}

-- Ideal press times -> integer-ms timeline perturbed by the profile.
function Bots.strikes(ideal: { number }, profile: Profile, rng: TestRng.TestRng): { { t: number } }
	local out = {}
	for _, t0 in ideal do
		if rng:float() < profile.missRate then continue end
		local t = t0 + profile.biasMs + (if profile.timingSdMs > 0 then rng:normal(0, profile.timingSdMs) else 0)
		if profile.fps then
			local frame = 1000 / (profile.fps :: number)
			local phase = rng:float() * frame
			t = math.ceil((t - phase) / frame) * frame + phase
		end
		table.insert(out, { t = math.max(0, math.floor(t + 0.5)) })
	end
	table.sort(out, function(a, b) return a.t < b.t end)
	return out
end

function Bots.spam(durationMs: number, everyMs: number): { { t: number } }
	local out = {}
	for t = 0, durationMs, everyMs do table.insert(out, { t = t }) end
	return out
end

return Bots
