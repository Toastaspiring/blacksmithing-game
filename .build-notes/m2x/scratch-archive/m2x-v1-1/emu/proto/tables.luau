--!strict
-- Markdown fixture tables for the S2 appendix (physics, 8 factors per work set, steps).
local Analyze = require("./analyze")
local Fx = require("./fixtures")
local fmt = string.format
local FACTORS = Analyze.FACTORS
local list = {}
for _, b in ipairs(Fx.golden()) do table.insert(list, b) end
for _, b in ipairs(Fx.calibration()) do table.insert(list, b) end
local R = {}
for i, b in ipairs(list) do R[i] = Analyze.run(b) end
local function short(n: string): string
	return (string.gsub(n, " %(.*", ""))
end
print("#### Physics (mass in kg = mu; Iron 7.87, Steel 7.85)")
print("| Fixture | parts (kept) | mass | volume st³ | balance | reach | blade length | edge (main chain) | cutIndex |")
print("|---|---|---|---|---|---|---|---|---|")
for i, r in ipairs(R) do
	local p = r.physics
	local k = 0
	for _, f in ipairs(p.kept) do if f then k += 1 end end
	print(fmt("| %s | %d (%d) | %.4f | %.5f | %.3f | %.3f | %.3f | %.3f | %.2f |", r.name, r.parts, k, p.mass, p.volume, p.balance, p.reach, p.bladeLength, r.edge.length, r.edge.cutIndex))
end
for _, key in ipairs({ "All", "Blade" }) do
	print(fmt("\n#### Factors on work set %s (raw / x)", if key == "All" then "All (Smelting, Hammering)" else "{Blade} (Sharpening)"))
	local h = "| Fixture |"
	local sep = "|---|"
	for _, f in ipairs(FACTORS) do h ..= " " .. f .. " |"; sep ..= "---|" end
	print(h)
	print(sep)
	for _, r in ipairs(R) do
		local F = r.sets[key]
		local line = "| " .. r.name .. " |"
		for _, f in ipairs(FACTORS) do
			line ..= fmt(" %.4g / %.3f |", F.raw[f], F.x[f])
		end
		print(line)
	end
end
print("\n#### Steps (g / d -> tier; tierRaw in brackets when it differs)")
print("| Fixture | Smelting | Hammering | Sharpening | tiers |")
print("|---|---|---|---|---|")
for _, r in ipairs(R) do
	local c, t = {}, {}
	for _, s in ipairs(r.steps) do
		table.insert(c, fmt("%.4f / %.4f %s%s", s.g, s.d, s.tier, if s.tierRaw ~= s.tier then " (" .. s.tierRaw .. ")" else ""))
		table.insert(t, string.sub(s.tier, 1, 1))
	end
	print(fmt("| %s | %s | %s |", r.name, table.concat(c, " | "), table.concat(t, "/")))
end
