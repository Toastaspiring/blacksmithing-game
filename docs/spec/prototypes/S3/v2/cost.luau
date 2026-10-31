--!strict
-- S3 prototype v2: path derivation and cost table (Lune ms; Studio estimate x2.6, RULINGS 2.14).
-- For every reference blade: sides, source points, path points, L, travel at Normal/Hard, fallback, generate() ms,
-- and decode + replay + checks ms for a 31 s worst-case trace timeline (one sample per 20 ms + grind flag).
local PT = require("./PrecisionTrace")
local Params = require("./Params")
local Blades = require("./Blades")
local Bots = require("./Bots")
local Timeline = nil -- codec cost measured separately below (pure byte loop)

local function ms(f: () -> ()): number
	local t = os.clock()
	f()
	return (os.clock() - t) * 1000
end

local pN = Params.resolve("PrecisionTrace", "Iron", "Normal", Params.refFactors(0.10))
local pH = Params.resolve("PrecisionTrace", "Iron", "Hard", Params.refFactors(0.30))
local pX = Params.resolve("PrecisionTrace", "Steel", "Hard", Params.refFactors(1.0))
print("| blade | chain pts | chain studs | sides | source pts | E | DP tol | path pts | L (u) | travel N / H (s) | fallback | generate ms (max of 20) | worst-case replay+checks ms |")
for _, key in Blades.ORDER do
	local b = (Blades :: any)[key]
	local sides = PT.sidesFromChains(b.chains, b.grip, b.axis)
	local src, info = PT.edgeToPanel(sides, b.grip, b.axis, pN.pacerSpeed)
	local genMax, pat, patH = 0, nil :: any, nil :: any
	for seed = 1, 20 do
		local g = ms(function()
			pat = PT.generate(seed, pN, src)
		end)
		genMax = math.max(genMax, g)
	end
	local srcH = PT.edgeToPanel(sides, b.grip, b.axis, pH.pacerSpeed)
	patH = PT.generate(1, pH, srcH)
	-- worst-case honest timeline: one sample per 20 ms over the whole duration, grinding, Average bot path
	local samples = Bots.ptHuman(pat, (Bots.PROFILES :: any).Average, 7)
	local rep = 0
	for _ = 1, 5 do
		rep = math.max(rep, ms(function()
			PT.replay(pat, samples)
		end))
	end
	print(string.format("| %s | %d | %.2f | %d | %s | %s | %s | %d | %.3f | %.1f / %.1f | %s | %.2f | %.2f (%d samples) |",
		key, #b.chains[1].points, b.chains[1].length, #sides, if src then tostring(#src // 2) else "-", if info and info.E then string.format("%.2f", info.E) else "-", if info and info.tol then string.format("%.3f", info.tol) else "-",
		#pat.pu, pat.L, pat.travelMs / 1000, patH.travelMs / 1000, tostring(pat.usedFallback), genMax, rep, #samples))
end
-- the longest legal trace: a source whose length hits the bound, at the slowest pacer (Iron/Normal x=0)
local p0 = Params.resolve("PrecisionTrace", "Iron", "Normal", Params.refFactors(0))
local src = PT.edgeToPanel(PT.sidesFromChains(Blades.saw.chains, Blades.saw.grip, Blades.saw.axis), Blades.saw.grip, Blades.saw.axis, p0.pacerSpeed)
local pat = PT.generate(3, p0, src)
local samples = {}
local t = 0
while t <= pat.durationMs do
	local u, v = PT.pointAt(pat, PT.pacerArc(pat, t))
	table.insert(samples, { t = t, u = math.round(u * PT.Q + 37), v = math.round(v * PT.Q - 21), grind = true })
	t += 20
end
local rep = 0
for _ = 1, 5 do
	rep = math.max(rep, ms(function()
		PT.replay(pat, samples)
	end))
end
print(string.format("longest: saw source at x=0 pacer %.3f: L %.3f travel %.1f s duration %.1f s, %d samples, replay+checks %.2f ms, generate %.2f ms",
	p0.pacerSpeed, pat.L, pat.travelMs / 1000, pat.durationMs / 1000, #samples, rep, ms(function() PT.generate(3, p0, src) end)))
