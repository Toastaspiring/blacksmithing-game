--!nocheck
-- m2r5: every prototype fixture under a variant against the prototype: the cleaned list and D per step, through the emulator. And the regression table's bounds
-- (X01..X07 against their reference designs). args: variant
local process = require("@lune/process")
local Sampling = require("./tree/src/shared/Physics/Sampling")
local Emu = require("./proto/analyze_build")
local Proto = require("./proto/analyze")
local Fx = require("./proto/fixtures")
local V = require("./variants")
local fmt = string.format

local variant = process.args[1] or "P"
V.apply(Sampling, variant)

local function cleanedOf(R)
	local t = {}
	for _, c in ipairs(R.cleaned or {}) do
		table.insert(t, c.reason .. "#" .. c.partId)
	end
	return table.concat(t, ",")
end

local rows, total, diff = {}, 0, 0
local function compare(group, b)
	if not b or not b.parts then return end
	local ok1, Rp = pcall(Proto.run, b, { measureInvalid = true })
	local ok2, Re = pcall(Emu.run, b, { measureInvalid = true, build = true })
	if not ok1 or not ok2 then
		print("ERROR", b.name, ok1, ok2, if ok2 then "" else Re)
		return
	end
	total += 1
	local cp, ce = cleanedOf(Rp), cleanedOf(Re)
	local changed = cp ~= ce
	local line = {}
	local dMax = 0
	local tier = false
	for i, s in ipairs(Rp.steps or {}) do
		local o = Re.steps and Re.steps[i]
		if o then
			table.insert(line, fmt("%s %.4f/%.4f", string.sub(s.step, 1, 2), s.d, o.d))
			dMax = math.max(dMax, math.abs(s.d - o.d))
			if s.d ~= o.d then changed = true end
			if s.tier ~= o.tier then tier = true end
		end
	end
	if changed then
		diff += 1
		print(fmt("%-11s %-52s cleaned %s -> %s | proto/build %s | max dD %.4f%s", group, string.sub(b.name, 1, 52), if cp == "" then "none" else cp, if ce == "" then "none" else ce, table.concat(line, " "), dMax, if tier then " TIER" else ""))
	end
end

local seen = {}
local function once(group, b)
	if b and not seen[b.name] then
		seen[b.name] = true
		compare(group, b)
	end
end
for _, b in ipairs(Fx.calibration()) do once("calibration", b) end
for _, b in ipairs(Fx.golden()) do once("golden", b) end
for _, r in ipairs(Fx.adversarial()) do
	once("adversarial", r.fixture)
	once("adversarial", r.base)
end
for _, r in ipairs(Fx.regression()) do
	once("regression", r.fixture)
	once("regression", r.base)
end
for _, b in ipairs(Fx.validation()) do once("validation", b) end
for _, b in ipairs(Fx.perf()) do once("perf", b) end
print(fmt("%s: %d fixtures, %d differ from the prototype", variant, total, diff))

-- the regression table: |D - D_ref| per fixture with kind D, against its reference, prototype and variant
print("X01/X02 against their union-equivalent blades:")
for _, r in ipairs(Fx.regression()) do
	if string.sub(r.id, 1, 3) == "X01" or string.sub(r.id, 1, 3) == "X02" then
		local P1, P0 = Proto.run(r.fixture, { measureInvalid = true }), Proto.run(r.base, { measureInvalid = true })
		local E1, E0 = Emu.run(r.fixture, { measureInvalid = true, build = true }), Emu.run(r.base, { measureInvalid = true, build = true })
		local a, b = {}, {}
		for i, s in ipairs(P1.steps) do
			table.insert(a, fmt("%.4f", math.abs(s.d - P0.steps[i].d)))
			table.insert(b, fmt("%.4f", math.abs(E1.steps[i].d - E0.steps[i].d)))
		end
		print(fmt("  %-7s proto |dD| %s; %s %s; cleaned proto %s / %s", r.id, table.concat(a, " "), variant, table.concat(b, " "), cleanedOf(P1), cleanedOf(E1)))
	end
end
