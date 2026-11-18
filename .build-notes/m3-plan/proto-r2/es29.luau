--!nocheck
-- m3-plan-r2: E-S2.9's four tables (Physics, Factors on All, Factors on {Blade}, Steps) re-made on the snapshot, in
-- E-S2.9's own formats, for F1–F5 and C01–C15: physics from the snapshot's Analyze.run (M2), edge, cutIndex, factors and
-- steps from the emulator walking the measure's rank order ("rank", the plan) or the fixture's part order ("part", what
-- E-S2.9 and §5.5 were measured on). Diff the output against docs/spec/SPEC-evidence.md's E-S2.9 rows.
--   lune run <abs>/proto/es29.luau -- rank|part
local L = require("./lib")
local process = require("@lune/process")
local Analyze = require("../repo/src/shared/Physics/Analyze")
local fmt = string.format

local mode = process.args[1] or "rank"
local ROWS = { "F1", "F2", "F3", "F4", "F5", "C01", "C02", "C02s", "C04", "C05", "C06", "C07", "C08", "C09", "C10", "C11",
	"C12", "C13", "C14", "C15" }
local NAME = {
	F1 = "F1 ArmingSword", F2 = "F2 MinimalSword", F3 = "F3 Rapier", F4 = "F4 Cleaver", F5 = "F5 StarterSword",
	C02 = "C02 Arming (Iron)", C02s = "C02 Arming (Steel)",
}
local FULL = { Normal = "Normal", Hard = "Hard" }

local function g4(x)
	if x == 0 then
		return "0"
	end
	local s = fmt("%.4g", x)
	return s
end

local results = {}
for _, id in ipairs(ROWS) do
	local b = L.find(id)
	local R = if mode == "part" then L.run(b) else L.run(L.inRankOrder(b))
	local core = { schema = 1, name = b.name, type = "Sword", parts = b.parts }
	local M = Analyze.run(core)
	results[id] = { b = b, R = R, M = M, name = NAME[id] or b.name }
end

print("#### Physics")
for _, id in ipairs(ROWS) do
	local r = results[id]
	local p, e = r.M.physics, r.R.edge
	local kept = 0
	for _, k in ipairs(p.kept) do
		if k then
			kept += 1
		end
	end
	print(fmt("| %s | %d (%d) | %.4f | %.5f | %.3f | %.3f | %.3f | %.3f | %.2f |", r.name, #r.b.parts, kept, p.mass, p.volume,
		p.balance, p.reach, p.bladeLength, e.length, e.cutIndex))
end
for si, title in ipairs({ "#### Factors on work set All", "#### Factors on work set {Blade}" }) do
	print(title)
	for _, id in ipairs(ROWS) do
		local r = results[id]
		local s = r.R.steps[if si == 1 then 2 else 3]
		local cells = {}
		for _, f in ipairs(s.factors) do
			table.insert(cells, fmt("%s / %.3f", g4(f.raw), f.x))
		end
		print(fmt("| %s | %s |", r.name, table.concat(cells, " | ")))
	end
end
print("#### Steps")
for _, id in ipairs(ROWS) do
	local r = results[id]
	local cells, tiers = {}, {}
	for _, s in ipairs(r.R.steps) do
		local t = FULL[s.tier] or s.tier
		if s.tierRaw ~= s.tier then
			t = t .. " (" .. s.tierRaw .. ")"
		end
		table.insert(cells, fmt("%.4f / %.4f %s", s.g, s.d, t))
		table.insert(tiers, string.sub(s.tier, 1, 1))
	end
	print(fmt("| %s | %s | %s |", r.name, table.concat(cells, " | "), table.concat(tiers, "/")))
end
