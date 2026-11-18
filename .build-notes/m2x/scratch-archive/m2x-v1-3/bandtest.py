# bandtest.py <tree>: add the sag-band case to tests/Physics/Verdict.spec.luau
import sys
p = sys.argv[1] + "/tests/Physics/Verdict.spec.luau"
s = open(p, encoding="utf-8", newline="").read()
anchor = "\t-- ── what the verdict reads, to the bit ─"
assert s.count(anchor) == 1
test = '''	-- A part wholly inside a round one is buried whatever the round part's model: F5 with its pommel a Ball 0.6 across and 4
	-- Blade Blocks inside it along (1, ±1, ±1)/√3, their outer faces 0.011 inside the sphere (between it and the inscribed
	-- model's facets, 0.0172 deep there), and 4 Blade Balls r 0.1 inside it, 0.002 from the sphere: every vertex buried, so
	-- the truth reads 0 and the hidden metal is cleaned, F5's measure bit-identical. Read on the inscribed half-spaces, the
	-- Blocks showed 10 % and the Balls 3.3 %, kept: Sharpening 0.0989 Normal → 0.2169 / 0.2958 Hard through the emulator.
	t.it("§4.4 a part wholly inside a Ball, against its true surface, is cleaned: no filler in the sag band", function()
		local S3 = 1 / math.sqrt(3)
		local R = 0.3
		local base = table.clone(Blueprints.core("F5").parts)
		base[1] = H.part(1, "Pommel", "Ball", "Iron", { 0, R, 0 }, H.I, { 2 * R, 2 * R, 2 * R })
		local before = Sampling.exposure(H.prepared({ parts = base }))
		for _, kind in ipairs({ "Block", "Ball" }) do
			local parts = table.clone(base)
			for _, d in ipairs({ { S3, S3, S3 }, { S3, -S3, S3 }, { S3, S3, -S3 }, { S3, -S3, -S3 } }) do
				if kind == "Block" then
					local k = R - 0.011 - 0.1
					table.insert(parts, H.part(#parts + 1, "Blade", "Block", "Iron", { k * d[1], R + k * d[2], k * d[3] },
						H.axisAngle(d[3], 0, -d[1], math.deg(math.acos(d[2]))), { 0.1, 0.2, 0.1 }))
				else
					local k = R - 0.002 - 0.1
					table.insert(parts, H.part(#parts + 1, "Blade", "Ball", "Iron", { k * d[1], R + k * d[2], k * d[3] }, H.I, { 0.2, 0.2, 0.2 }))
				end
			end
			local list = H.prepared({ parts = parts })
			for i = #base + 1, #parts do
				local P = list[i]
				local corners: { number } = if P.poly then P.wverts else { P.cx + P.r * S3, P.cy + P.r * S3, P.cz + P.r * S3 }
				for j = 1, #corners, 3 do
					A.truthy(Shapes.sd(list[1], corners[j], corners[j + 1], corners[j + 2]) < -5e-4, kind .. " " .. i .. ": wholly inside the Ball")
				end
			end
			local after = Sampling.exposure(list)
			for i = #base + 1, #parts do
				A.falsy(after.kept[i], kind .. " " .. i .. " inside F5's pommel: cleaned")
			end
			H.sameKeptMeasure(after, before, #base)
		end
	end)

'''
s = s.replace(anchor, test + anchor)
open(p, "w", encoding="utf-8", newline="").write(s)
print("ok", p)
