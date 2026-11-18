--!nocheck
local S = require("./sets")
local L = require("./lib")
local Mirror = require("./repo/src/shared/Blueprint/Mirror")
local Plausible = require("./repo/tests/Physics/PlausibleDesigns")
local fmt = string.format
local want = { ["wedgeInGuard|C05|Wedge 0.12 0.12 0.16 spin0 height0.075"] = true, ["plateEdge|C09|blade w0.8 k0.8 l1.0 poke0.0500"] = true }
for _, d in ipairs(Plausible.all()) do
	if want[d.name] then
		local parts = S.clean(d.parts)
		local img = {}
		for i, p in ipairs(parts) do img[i] = Mirror.reflect(p, "X") end
		local P, Q = L.prep(parts), L.prep(img)
		local s0, k0 = L.newShares(P)
		local s1, k1 = L.newShares(Q)
		local r0, r1 = L.Sampling.ranked(P), L.Sampling.ranked(Q)
		print("== " .. d.name)
		for i, p in ipairs(parts) do
			print(fmt("  %2d %-11s %-7s pos %8.4f %7.4f %7.4f size %.4f %.4f %.4f | share %.9f %s | image %.9f %s | rank %d/%d", i, p.shape, p.slot, p.pos[1], p.pos[2], p.pos[3], p.size[1], p.size[2], p.size[3],
				s0[i] or -1, tostring(k0[i]), s1[i] or -1, tostring(k1[i]), r0[i], r1[i]))
		end
	end
end
