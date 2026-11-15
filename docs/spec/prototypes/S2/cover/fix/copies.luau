--!nocheck
local L = require("./lab")
local fmt = string.format
local function axisAngle(ax, ay, az, deg)
	local h = math.rad(deg) / 2
	local n = math.sqrt(ax * ax + ay * ay + az * az)
	return L.Quat.hemisphere(L.Quat.normalize({ ax / n * math.sin(h), ay / n * math.sin(h), az / n * math.sin(h), math.cos(h) }))
end
local function check(name, base, bi)
	local e0 = L.Sampling.exposure(L.prepared(base))
	local blade = base[bi]
	print(fmt("%s: blade part %d %s size %s, kept %s", name, bi, blade.shape, table.concat(blade.size, ","), tostring(e0.kept[bi])))
	local variants = {
		{ "an exact copy", blade.rot, blade.size, 0 },
		{ "turned 180 about Y", { 0, 1, 0, 0 }, blade.size, 0 },
		{ "turned 180 about X", { 1, 0, 0, 0 }, blade.size, 0 },
		{ "size permuted, 90 about Y", axisAngle(0, 1, 0, 90), { blade.size[3], blade.size[2], blade.size[1] }, 0 },
		{ "1e-12 lower", blade.rot, blade.size, -1e-12 },
		{ "5e-8 lower", blade.rot, blade.size, -5e-8 },
	}
	for _, v in ipairs(variants) do
		for _, slot in ipairs({ "Guard", "Pommel", "Grip" }) do
			local parts = {}
			for i, p in ipairs(base) do parts[i] = p end
			local n = #parts + 1
			table.insert(parts, { id = n, slot = slot, shape = blade.shape, material = blade.material, pos = { blade.pos[1], blade.pos[2] + v[4], blade.pos[3] }, rot = v[2], size = v[3] })
			local e = L.Sampling.exposure(L.prepared(parts))
			local same = true
			for i = 1, #base do
				if e.kept[i] ~= e0.kept[i] or e.exposedKept[i] ~= e0.exposedKept[i] then same = false end
				for j = 1, #base do
					if e.contact[i][j] ~= e0.contact[i][j] then same = false end
				end
			end
			print(fmt("  + its blade %-26s in the %-6s: blade %s, copy %s, the rest's measure %s", v[1], slot, e.kept[bi] and "kept" or "CLEANED", e.kept[n] and "KEPT" or "cleaned", same and "bit-identical" or "MOVED"))
		end
	end
end
local F3 = L.Blueprints.core("F3").parts
check("F3", F3, 6)
for _, b in ipairs(L.Fx.calibration()) do
	if string.sub(b.name, 1, 3) == "C08" then
		for i, p in ipairs(b.parts) do
			if p.slot == "Blade" then print(fmt("  C08 part %d %s %s size %s pos %s", i, p.slot, p.shape, table.concat(p.size, ","), table.concat(p.pos, ","))) end
		end
		for i, p in ipairs(b.parts) do
			if p.slot == "Blade" and p.shape == "Block" then check("C08", b.parts, i) break end
		end
	end
end
