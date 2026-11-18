--!nocheck
-- m3-plan-r2: g summed in Definitions/Steps' order (FactorId order: Sharpening As .30, SC .20, EL .50) and quantized with
-- Util/Quantize, against the emulator's g (its Sharpening sums EL, As, SC), on every fixture in rank order. Prints the
-- fixtures where g or d differ.
--   lune run <abs>/proto/gorder.luau
local L = require("./lib")
local Steps = require("../repo/src/shared/Definitions/Steps")
local Quantize = require("../repo/src/shared/Util/Quantize")
local fmt = string.format

local function q(x)
	return Quantize.q(x, Quantize.SCALAR_SCALE)
end

local n, moved = 0, 0
for _, f in ipairs(L.fixtures()) do
	local R = L.run(L.inRankOrder(f.b))
	if R.steps then
		for _, s in ipairs(R.steps) do
			local xs = {}
			for _, v in ipairs(s.factors) do
				xs[v.factor] = v.x
			end
			local sum = 0
			for _, fw in ipairs(Steps.get(s.step).factorWeights) do
				sum += fw.w * xs[fw.factor]
			end
			local g = q(sum)
			local d = q(1 - (1 - q(0)) * (1 - g))
			n += 1
			if g ~= s.g or d ~= s.d then
				moved += 1
				print(fmt("%-12s %-10s emulator g %.4f d %.4f | Steps order g %.4f d %.4f (sums %.17g)", f.id, s.step, s.g, s.d, g, d, sum))
			end
		end
	end
end
print(fmt("%d steps, %d differ", n, moved))
