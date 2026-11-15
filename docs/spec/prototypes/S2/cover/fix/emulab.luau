--!nocheck
-- D through V1's M3 emulator (m2x-v1-1/emu/proto, analyze_build: the prototype's edge and factor formulas on the build's
-- kept, exposedKept, contact and ownership), on ./emu/repo, a copy of the repo's src
local Emu = require("./emu/proto/analyze_build")
local ESampling = require("./emu/repo/src/shared/Physics/Sampling")
local fmt = string.format
local E = {}
function E.run(parts, keptRow)
	local copy = {}
	for i, p in ipairs(parts) do
		copy[i] = { id = i, slot = p.slot or "Blade", shape = p.shape, material = p.material or "Iron", pos = { p.pos[1], p.pos[2], p.pos[3] },
			rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] }, size = { p.size[1], p.size[2], p.size[3] } }
	end
	ESampling.FORCE.kept = keptRow
	local ok, R = pcall(Emu.run, { name = "x", parts = copy }, { measureInvalid = true, build = true })
	ESampling.FORCE.kept = nil
	if not ok then error(R) end
	return R
end
function E.dline(R)
	local t = {}
	for _, s in ipairs(R.steps or {}) do
		table.insert(t, fmt("%s %.4f %s", string.sub(s.step, 1, 2), s.d, string.sub(s.tier, 1, 1)))
	end
	if #t == 0 then return "no steps (" .. tostring(R.valid) .. ")" end
	return table.concat(t, ", ")
end
function E.step(R, name)
	for _, s in ipairs(R.steps or {}) do
		if s.step == name then return s.d, s.tier end
	end
end
function E.diff(Ra, Rb)
	local worst, tier, step = 0, false, ""
	if not Ra.steps or not Rb.steps then return -1, false, "nosteps" end
	for i, s in ipairs(Ra.steps) do
		local o = Rb.steps[i]
		if math.abs(s.d - o.d) > worst then worst, step = math.abs(s.d - o.d), s.step end
		tier = tier or s.tier ~= o.tier
	end
	return worst, tier, step
end
return E
