--!nocheck
-- the caged Ball the model over-reads (truly under 2 %, read over 2 %, kept) in a sword whose blade thickness and width
-- vary: D under the build's verdict and under the truth's, looking for a tier flip
local L = require("./lib")
local mk = require("./cagelib")
local fmt = string.format
local function sword(r, g, b, th, w)
	local c = { 0, 2.4, 0 }
	local cage = mk.cage(L, r, g, b, 0.02, 2 * r + 0.1, c)
	local parts = {}
	table.insert(parts, L.part("Grip", "Block", { 0, 0.75, 0 }, L.I, { 0.16, 0.9, 0.16 }))
	table.insert(parts, L.part("Guard", "Block", { 0, 1.29, 0 }, L.I, { 1.0, 0.18, 0.24 }))
	local wallBottom = c[2] - (r + g + 0.02)
	local wallTop = c[2] + (r + g + 0.02)
	table.insert(parts, L.part("Blade", "Block", { 0, (1.38 + wallBottom) / 2, 0 }, L.I, { w, wallBottom - 1.38, th }))
	table.insert(parts, L.part("Blade", "Block", { 0, (wallTop + 4.0) / 2, 0 }, L.I, { w, 4.0 - wallTop, th }))
	local ball = cage[1]
	ball.slot = "Blade"
	local slots = { "Blade", "Blade", "Blade", "Blade", "Blade", "Pommel" }
	for k = 2, 7 do cage[k].slot = slots[k - 1] end
	local eslots = { "Blade", "Blade", "Blade", "Blade", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Grip" }
	for k = 8, 19 do cage[k].slot = eslots[k - 7] end
	for k = 1, #cage do table.insert(parts, cage[k]) end
	return L.renumber(parts), 5
end
local found = 0
for _, def in ipairs({ { 0.08, 0.00537, 0.0302 }, { 0.10, 0.00665, 0.0314 } }) do
	for _, th in ipairs({ 0.06, 0.05, 0.045, 0.04, 0.035, 0.03, 0.025 }) do
		for _, w in ipairs({ 0.16, 0.12, 0.1 }) do
			local parts, bi = sword(def[1], def[2], def[3], th, w)
			local run = L.run(L.copyParts(parts), { measureInvalid = false })
			if run.validation.ok then
				local P = L.prep(parts)
				local e = L.Sampling.exposure(P)
				if e.kept[bi] then
					local _, _, hider = L.Oracle.flags(P)
					local truth = L.Oracle.share(P, bi, hider)
					if truth < 0.02 then
						local Rb = L.emu(L.copyParts(parts))
						local row = table.clone(e.kept)
						row[bi] = false
						local Rt = L.emu(L.copyParts(parts), row)
						local d, t, s = L.dDiff(Rb, Rt)
						print(fmt("r %.2f blade %.3f × %.2f: Ball reads ≥ 2 %%, truth %.3f%%; build %s | truth %s | |dD| %.4f %s%s", def[1], th, w, 100 * truth, L.dline(Rb), L.dline(Rt), d, s, t and " TIER FLIP" or ""))
						if t then found += 1 end
					end
				end
			end
		end
	end
end
print("tier flips", found)
