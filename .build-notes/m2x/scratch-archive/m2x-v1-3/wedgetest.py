# wedgetest.py <tree>: add the Wedge-description case to tests/Physics/Verdict.spec.luau
import sys
p = sys.argv[1] + "/tests/Physics/Verdict.spec.luau"
s = open(p, encoding="utf-8", newline="").read()
anchor = "\t-- ── what the verdict reads, to the bit ─"
assert s.count(anchor) == 1
test = '''	-- A Wedge (sx, sy, sz) is the same solid as (sx, sz, sy) half turned about its local (0, 1, −1), to the bit of its vertices;
	-- Shapes' volume 4·hx·hy·hz rounds the two descriptions an ulp apart, so the rank takes hy and hz in order. F4's tip and
	-- C08's two tips, again in the Guard so described, are cleaned and the tips kept, every other measure bit-identical (with
	-- the volume as given, the copies kept the faces: F4's Sharpening 0.3420 Hard → 0.1814 Normal, C08's 0.2487 Hard → 0.0076).
	t.it("§4.4 a Wedge described the other way ties with itself: F4's and C08's tips again in the Guard are cleaned", function()
		local C08: any = nil
		for _, b in ipairs(Fixtures.calibration()) do
			if string.sub(b.name, 1, 3) == "C08" then
				C08 = b
			end
		end
		local Sq = 0.70710678118654757
		for _, case in ipairs({ { "F4", Blueprints.core("F4").parts, 5 }, { "C08", C08.parts, 5 }, { "C08", C08.parts, 6 } }) do
			local base: { any }, i: number = case[2], case[3]
			local tip = base[i]
			A.eq(tip.shape, "Wedge", case[1] .. ": its tip")
			local before = Sampling.exposure(H.prepared({ parts = base }))
			local parts = table.clone(base)
			local q = Quat.hemisphere(Quat.normalize(Quat.mul(tip.rot, { 0, Sq, -Sq, 0 })))
			table.insert(parts, H.part(#base + 1, "Guard", "Wedge", tip.material, table.clone(tip.pos), q, { tip.size[1], tip.size[3], tip.size[2] }))
			local list = H.prepared({ parts = parts })
			for k = 1, #list[i].wverts do
				A.near(list[#parts].wverts[k], list[i].wverts[k] , 1e-15, case[1] .. ": the same solid")
			end
			local after = Sampling.exposure(list)
			local what = case[1] .. " + its tip " .. i .. " described the other way in the Guard"
			A.truthy(after.kept[i], what .. ": the tip kept")
			A.falsy(after.kept[#parts], what .. ": the copy cleaned")
			H.sameKeptMeasure(after, before, #base)
		end
	end)

'''
s = s.replace(anchor, test + anchor)
if 'local Quat = require("../../src/shared/Blueprint/Quat")' not in s:
	a2 = 'local Sampling = require("../../src/shared/Physics/Sampling")\n'
	s = s.replace(a2, 'local Quat = require("../../src/shared/Blueprint/Quat")\n' + a2, 1)
open(p, "w", encoding="utf-8", newline="").write(s)
print("ok", p)
