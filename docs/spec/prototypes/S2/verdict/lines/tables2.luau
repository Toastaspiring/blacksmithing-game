--!nocheck
-- E-S2.5 and E-S2.9's rows the rank moves: X01..X07 against their bases, C09's factors, and P3. Run in a harness folder.
local V = require("./v1")
local Fx = V.Fx
local fmt = string.format
for _, r in ipairs(Fx.regression()) do
	local f, b = r.fixture, r.base
	if f and b and f.parts and b.parts then
		local Ra, Rb = V.emu(V.copyParts(f.parts)), V.emu(V.copyParts(b.parts))
		if Ra.steps and Rb.steps then
			local w, tier = V.dDiff(Ra, Rb)
			local g = 0
			for i, s in ipairs(Ra.steps) do
				g = math.max(g, math.abs(s.g - Rb.steps[i].g))
			end
			print(fmt("%-40s dD %.4f dG %.4f %s | %s | base %s", string.sub(f.name, 1, 40), w, g, if tier then "TIER" else "", V.dline(Ra), string.sub(b.name, 1, 24)))
		end
	end
end
local parts, name = V.fixture("C09")
local R = V.emu(parts)
print(name)
local p = R.physics
for k, v in pairs(p or {}) do
	if type(v) == "number" then print(k, fmt("%.6g", v)) end
end
for _, s in ipairs(R.steps) do
	local t = {}
	for _, f in ipairs(s.factors) do
		table.insert(t, fmt("%s %.4g / %.3f", f.factor, f.raw, f.x))
	end
	print(s.step, fmt("g %.4f m %.3f d %.4f %s", s.g, s.m, s.d, s.tier), table.concat(t, " | "))
end
