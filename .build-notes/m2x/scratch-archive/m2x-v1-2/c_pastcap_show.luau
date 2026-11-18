--!nocheck
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local L = require("./lib")
local fmt = string.format
for _, f in ipairs({ "out/honest_32.log", "out/honest_33.log", "out/honest_34.log" }) do
	local txt = fs.readFile(f)
	local line = string.match(txt, "PASTCAP (%b[])")
	if line then
		local parts = serde.decode("json", line)
		L.renumber(parts)
		local P = L.prep(parts)
		local u = L.units(P)
		local r = L.run(L.copyParts(parts), { measureInvalid = false })
		local models = L.models(P)
		local lowest = 1
		for i = 1, #P do lowest = math.min(lowest, L.readOf(P, i, models)) end
		local desc = {}
		local tilted = 0
		for i, p in ipairs(parts) do
			local rot = p.rot
			local base = if p.slot == "Guard" then { 0, 0, 0, 1 } else L.Z90
			local dot = math.abs(rot[1] * base[1] + rot[2] * base[2] + rot[3] * base[3] + rot[4] * base[4])
			local ang = 2 * math.deg(math.acos(math.min(1, dot)))
			if ang > 0.01 then tilted += 1 end
			table.insert(desc, fmt("%s %.1f°", string.sub(p.slot, 1, 2), ang))
		end
		print(fmt("%s: %d parts, %.1f units, %s %s, lowest reading %.1f%%, %d parts turned off their rows' axis", f, #parts, u, r.validation.ok and "valid" or "invalid", L.codes(r), 100 * lowest, tilted))
		print("   " .. table.concat(desc, ", "))
		fs.writeFile("out/pastcap_" .. string.match(f, "honest_(%d+)") .. ".json", line)
	end
end
