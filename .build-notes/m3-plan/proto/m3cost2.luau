--!nocheck
-- B05 with the void test per candidate (as first written) against VOID_LATE (once per exposed sample): cost and the
-- §17.2 sandwich, so the cheaper form is known to give the same answer there.
local Analyze = require("./analyze")
local Fx = require("./fixtures")
local CFG = Analyze.CFG
local fmt = string.format
local function set(r, tm, vg, late)
	CFG.RECOMPUTE, CFG.THIN_MERGE, CFG.VOID_GAP, CFG.VOID_LATE = r, tm, vg, late
end
local function best(b)
	local t = math.huge
	local R
	for _ = 1, 5 do
		local X = Analyze.run(b)
		if X.T.total < t then
			t, R = X.T.total, X
		end
	end
	return t * 1000, R
end
local function dl(R)
	local t = {}
	for _, s in ipairs(R.steps) do
		table.insert(t, fmt("%.4f", s.d))
	end
	return table.concat(t, "/")
end
local list = {}
for _, b in ipairs(Fx.calibration()) do
	local id = string.match(b.name, "^(C%d+)")
	if id == "C05" or id == "C09" or id == "C04" or id == "C06" or id == "C08" then
		table.insert(list, b)
	end
end
table.insert(list, Fx.golden()[3])
for _, b in ipairs(Fx.perf()) do
	table.insert(list, b)
end
for _, b in ipairs(list) do
	set(true, 0.01, 0, false)
	local a, Ra = best(b)
	set(true, 0.05, 0.05, false)
	local c, Rc = best(b)
	set(true, 0.05, 0.05, true)
	local d, Rd = best(b)
	set(false, 0.01, 0, false)
	print(fmt("%-36s R0r %.1f ms %s | B05 %.1f (%+.0f %%) %s | B05late %.1f (%+.0f %%) %s", string.sub(b.name, 1, 36), a, dl(Ra), c, (c / a - 1) * 100, dl(Rc), d, (d / a - 1) * 100, dl(Rd)))
end
