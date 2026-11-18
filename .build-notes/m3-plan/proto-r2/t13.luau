--!nocheck
-- m3-plan-r2: T-DIF-13's relation contracts (E-S2.5, E-S2.7, §5.6) on the snapshot, through the emulator in the measure's
-- rank order, the build's verdict deciding: X01/X02 against their union blades (|ΔD|), X03 against F4 (ΔThinness), X05 and
-- X07 against F5 (|ΔG|), X06's Asymmetry against the 120-probe oracle (CFG ASYM_N_MIN 120, ASYM_WORK 1e9, N_MAX_AXIS 400,
-- v2/run.luau's asymOracle), A25/A26/A27 against their bases, C10/C11 against C01.
--   lune run <abs>/proto/t13.luau
local L = require("./lib")
local CFG = L.Emu.CFG
local fmt = string.format

local function run(id)
	return L.run(L.inRankOrder(L.find(id)))
end
local function stepOf(R, name)
	for _, s in ipairs(R.steps) do
		if s.step == name then
			return s
		end
	end
	error(name)
end
local function factor(s, f)
	for _, v in ipairs(s.factors) do
		if v.factor == f then
			return v
		end
	end
	error(f)
end
local function worst(A, B, field, steps)
	local w = 0
	for i, s in ipairs(A.steps) do
		if steps == nil or steps[s.step] then
			w = math.max(w, math.abs(s[field] - B.steps[i][field]))
		end
	end
	return w
end

local F5, F4, F1, C01 = run("F5"), run("F4"), run("F1"), run("C01")
print(fmt("X01 vs its union blade (0.066): |ΔD| %.4f (bound 0.01)", worst(run("X01"), run("X01base"), "d")))
print(fmt("X02 vs its union blade (0.072): |ΔD| %.4f (bound 0.01)", worst(run("X02"), run("X02base"), "d")))
local x03 = run("X03")
print(fmt("X03 vs F4: Thinness All %.6f → %.6f, Blade %.6f → %.6f; Hammering %+.4f (bound ΔThinness 0.02)",
	factor(stepOf(F4, "Hammering"), "Thinness").raw, factor(stepOf(x03, "Hammering"), "Thinness").raw,
	factor(stepOf(F4, "Sharpening"), "Thinness").raw, factor(stepOf(x03, "Sharpening"), "Thinness").raw,
	stepOf(x03, "Hammering").d - stepOf(F4, "Hammering").d))
local w5, w7 = 0, 0
for _, f in ipairs(L.fixtures()) do
	if string.sub(f.id, 1, 3) == "X05" then
		w5 = math.max(w5, worst(run(f.id), F5, "g"))
	elseif string.sub(f.id, 1, 3) == "X07" then
		w7 = math.max(w7, worst(run(f.id), F5, "g"))
	end
end
print(fmt("X05 vs F5: |ΔG| max %.4f (bound 0.01); X07 vs F5: |ΔG| max %.4f (bound 0.01)", w5, w7))
local rows, w6 = {}, 0
for _, dx in ipairs({ "0.00", "0.01", "0.02", "0.03", "0.04", "0.05" }) do
	local R = run("X06-" .. dx)
	local a = factor(stepOf(R, "Sharpening"), "Asymmetry").raw
	local s1, s2, s3 = CFG.ASYM_N_MIN, CFG.ASYM_WORK, CFG.N_MAX_AXIS
	CFG.ASYM_N_MIN, CFG.ASYM_WORK, CFG.N_MAX_AXIS = 120, 1e9, 400
	local O = run("X06-" .. dx)
	CFG.ASYM_N_MIN, CFG.ASYM_WORK, CFG.N_MAX_AXIS = s1, s2, s3
	local o = factor(stepOf(O, "Sharpening"), "Asymmetry").raw
	w6 = math.max(w6, math.abs(a - o))
	table.insert(rows, fmt("%s %.3f/%.3f", dx, a, o))
end
print(fmt("X06 Asymmetry Blade, measured/oracle: %s; max error %.4f (bound 0.02)", table.concat(rows, ", "), w6))
print(fmt("A25 vs F1 |ΔD| %.4f (bound 0.01); A26 vs its base |ΔD| %.4f (0.02); A27 vs F1 Sharpening |ΔD| %.4f (0.02), Hammering %.4f → %.4f",
	worst(run("A25"), F1, "d"), worst(run("A26"), run("A26base"), "d"), worst(run("A27"), F1, "d", { Sharpening = true }),
	stepOf(F1, "Hammering").d, stepOf(run("A27"), "Hammering").d))
for _, id in ipairs({ "C10", "C11" }) do
	local R = run(id)
	local t = {}
	for i, s in ipairs(R.steps) do
		table.insert(t, fmt("%s %+.4f %s", string.sub(s.step, 1, 2), s.d - C01.steps[i].d, s.tier))
	end
	print(fmt("%s vs C01: %s (§5.6: at most +0.008, all Normal)", id, table.concat(t, ", ")))
end
