--!strict
-- S3 prototype: worked examples / golden values for the draft
local HZ = require("./HoldZone")
local TS = require("./TimingStrike")
local PT = require("./PrecisionTrace")
local Params = require("./Params")
local BPT = require("./BotsPT")

local function hex(n: number): string
	return string.format("0x%08X", n)
end

-- TimingStrike seed 1 Iron/Normal
do
	local p = Params.resolve("TimingStrike", "Iron", "Normal", nil)
	local pat = TS.generate(1, p)
	print("TimingStrike seed=1 Iron/Normal: N", #pat.cycles, "W", pat.W, "M", pat.M, "duration", pat.durationMs, "hash", hex(pat.hash))
	for i = 1, 4 do
		local c = pat.cycles[i]
		print(string.format("  cycle %d: start %d period %d target %d (offset %.3f)", i, c.start, c.period, c.target, (c.target - c.start) / c.period))
	end
	-- worked scoring: errors 0, +6, -15, +35, +79, miss, -81(miss), then perfect for the rest
	local errs = { 0, 6, -15, 35, 79, false, -81 }
	local presses = {}
	for i, c in pat.cycles do
		local e = errs[i]
		if e == nil then
			e = 0
		end
		if e ~= false then
			table.insert(presses, c.target + (e :: number))
		end
	end
	local res = TS.replay(pat, presses)
	local pts = {}
	for i = 1, 7 do
		local e = errs[i]
		table.insert(pts, string.format("%s->%.3f(%s)", tostring(e), TS.points(pat, if e == false then nil else e :: number), TS.grade(pat, if e == false then nil else e :: number)))
	end
	print("  worked: " .. table.concat(pts, " "), "score", res.score)
end

-- HoldZone seed 1 Iron/Normal
do
	local p = Params.resolve("HoldZone", "Iron", "Normal", nil)
	local pat = HZ.generate(1, p)
	local ks = {}
	for i = 1, math.min(6, #pat.keysT) do
		table.insert(ks, string.format("(%d ms, %.4f)", pat.keysT[i], pat.keysC[i]))
	end
	print("HoldZone seed=1 Iron/Normal keys:", #pat.keysT, table.concat(ks, " "), "hash", hex(pat.hash))
	-- trivial timelines
	print("  no input            ->", HZ.replay(pat, {}).score)
	print("  hold whole time     ->", HZ.replay(pat, { { t = 0, down = true } }).score)
	-- the temperature curve under full heat
	local s = HZ.newSession(pat)
	HZ.push(s, { t = 0, down = true })
	local marks = {}
	for _, t in { 500, 1000, 1500, 2000, 3000 } do
		HZ.advance(s, t)
		table.insert(marks, string.format("T(%d)=%.3f", t, s.T))
	end
	print("  full heat from GO:", table.concat(marks, " "))
	local s2 = HZ.newSession(pat)
	HZ.push(s2, { t = 0, down = true })
	HZ.push(s2, { t = 1000, down = false })
	local marks2 = {}
	for _, t in { 1000, 1200, 1500, 2000, 2500, 3000 } do
		HZ.advance(s2, t)
		table.insert(marks2, string.format("T(%d)=%.3f", t, s2.T))
	end
	print("  heat 0-1000 then release:", table.concat(marks2, " "))
end

-- PrecisionTrace longsword seed 1 Iron/Normal
do
	local p = Params.resolve("PrecisionTrace", "Iron", "Normal", nil)
	local src = PT.edgeToPanel(BPT.BLADES[1][2] :: any)
	local parts = {}
	for i = 1, #(src :: { number }), 2 do
		table.insert(parts, string.format("(%d,%d)", (src :: { number })[i], (src :: { number })[i + 1]))
	end
	print("PrecisionTrace longsword source (fixed-point):", table.concat(parts, " "))
	local pat = PT.generate(1, p, src)
	print("  path pts", #pat.pu, "L", string.format("%.4f", pat.L), "travel", pat.travelMs, "duration", pat.durationMs, "speed", string.format("%.4f", pat.speed), "hash", hex(pat.hash))
end
