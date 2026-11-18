--!nocheck
-- A real sword's blade, and inside it, wholly inside it, a skin of 6 plates flush with its faces, with lower ids. Nothing shows that did not show before.
local V = require("./v1")
local fmt = string.format
local I = V.I
local function skin(h, t)
	local sx, sy, sz = h.size[1], h.size[2], h.size[3]
	local cx, cy, cz = h.pos[1], h.pos[2], h.pos[3]
	return {
		V.part("Skin", "Block", "Guard", { cx, cy, cz + sz / 2 - t / 2 }, I, { sx, sy, t }),
		V.part("Skin", "Block", "Guard", { cx, cy, cz - sz / 2 + t / 2 }, I, { sx, sy, t }),
		V.part("Skin", "Block", "Guard", { cx + sx / 2 - t / 2, cy, cz }, I, { t, sy, sz }),
		V.part("Skin", "Block", "Guard", { cx - sx / 2 + t / 2, cy, cz }, I, { t, sy, sz }),
		V.part("Skin", "Block", "Pommel", { cx, cy + sy / 2 - t / 2, cz }, I, { sx, t, sz }),
		V.part("Skin", "Block", "Pommel", { cx, cy - sy / 2 + t / 2, cz }, I, { sx, t, sz }),
	}
end
for _, def in ipairs({ { "C05", 4 }, { "C02 Arming (Iron)", 4 }, { "C08", 4 }, { "F5", 4 }, { "F4", 4 }, { "C09", 12 } }) do
	local base = V.fixture(def[1])
	local Ra = V.emu(V.copyParts(base))
	local h = base[def[2]]
	h.label = "Blade"
	local KF = {}
	for _, s in ipairs(skin(h, 0.02)) do table.insert(KF, s) end
	for _, p in ipairs(base) do table.insert(KF, V.copyPart(p)) end
	-- the slots must still fit
	local c = { Blade = 0, Guard = 0, Pommel = 0, Grip = 0 }
	local MAXES = { Blade = 12, Guard = 8, Pommel = 4, Grip = 6 }
	for _, p in ipairs(KF) do c[p.slot] += 1 end
	for _, p in ipairs(KF) do
		if p.label == "Skin" and c[p.slot] > MAXES[p.slot] then
			c[p.slot] -= 1
			for _, sl in ipairs({ "Grip", "Blade", "Guard", "Pommel" }) do
				if c[sl] < MAXES[sl] then
					p.slot = sl
					c[sl] += 1
					break
				end
			end
		end
	end
	local ok = V.valid(KF)
	local text = V.show(KF, { "Blade", "Skin" }, 0.0005)
	local Rb = V.emu(KF)
	local w, tier, step = V.dDiff(Ra, Rb)
	print(fmt("%s, valid %s: %s\n   K: %s | K + skin: %s | |dD| %.4f %s%s", def[1], tostring(ok), string.sub(text, 1, 200), V.dline(Ra), V.dline(Rb), w, step, if tier then " TIER" else ""))
end
