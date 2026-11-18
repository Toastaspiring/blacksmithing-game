--!nocheck
-- the sealed rods of CoverAttacks, the whole design turned about the target's centre: the build's reading of the rod, against
-- the hide test with every part a hider (mybrute) — the box test's channel on Cylinders
local L = require("./lib")
local MB = require("./mybrute")
MB.init(L.Geo)
local Attacks = require("./repo/tests/Physics/CoverAttacks")
local Quat = L.Quat
local fmt = string.format
local worst = { 0 }
local flips = 0
for _, d in ipairs(Attacks) do
	if string.find(d.name, "rod") or string.find(d.name, "bar") then
		for _, ax in ipairs({ { 0, 0, 1 }, { 1, 0, 0 }, { 0, 1, 0 }, { 1, 1, 0 }, { 1, 2, 3 } }) do
			for _, ang in ipairs({ 3, 7, 13, 22.5, 31, 45, 60 }) do
				local q = L.axisAngle(ax[1], ax[2], ax[3], ang)
				local c = d.parts[d.target].pos
				local parts = {}
				for i, p in ipairs(d.parts) do
					local np = L.copyPart(p)
					local rel = { p.pos[1] - c[1], p.pos[2] - c[2], p.pos[3] - c[3] }
					local w = Quat.rotate(q, rel)
					np.pos = { c[1] + w[1], c[2] + w[2], c[3] + w[3] }
					np.rot = Quat.hemisphere(Quat.normalize(Quat.mul(q, p.rot)))
					parts[i] = np
				end
				L.renumber(parts)
				local P = L.prep(parts)
				local read = L.readOf(P, d.target)
				-- the hide test, every part a hider
				local models = {}
				for i = 1, #P do models[i] = L.Cover.model(P[i]) end
				local rk, ord = L.Sampling.ranked(P)
				local hm, higher = {}, {}
				for k = 1, #ord do
					local qq = ord[k]
					if qq.index ~= d.target then table.insert(hm, models[qq.index]); table.insert(higher, k < rk[d.target]) end
				end
				local m = models[d.target]
				local b = 0
				for f = 1, m.n do b += MB.facetShown(m, f, hm, higher) end
				b /= m.total
				if read - b > worst[1] then worst = { read - b, d.name, ax, ang, read, b } end
				if read >= 0.02 and b < 0.02 then flips += 1 end
			end
		end
	end
end
print(fmt("sealed rods and bars turned: the build reads above the hide test by up to %.4f (%s, axis (%g,%g,%g) %g°: reads %.3f%%, hide test %.3f%%); verdicts the box test flips: %d", worst[1], tostring(worst[2]), worst[3] and worst[3][1] or 0, worst[3] and worst[3][2] or 0, worst[3] and worst[3][3] or 0, worst[4] or 0, 100 * (worst[5] or 0), 100 * (worst[6] or 0), flips))
