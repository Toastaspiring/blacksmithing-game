--!strict
-- S8 study: exact (analytic) reference values for the golden fixtures, plus pairwise
-- overlap volumes estimated by fine sampling, so expected ranges cover both
-- "sum of parts" and "union" mass conventions. Run from proto/S8:
--   lune run studies/fixture_reference
local P = require("../repo/src/shared/Physics/ProtoShapes")
local F = require("../repo/tests/fixtures/Blueprints")

local function aabb(part: P.Part): ({ number }, { number })
	local m = P.matrix(part.rot)
	local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
		local c = P.rotate(m, { sx * part.size[1] / 2, sy * part.size[2] / 2, sz * part.size[3] / 2 })
		for a = 1, 3 do
			lo[a] = math.min(lo[a], part.pos[a] + c[a]); hi[a] = math.max(hi[a], part.pos[a] + c[a])
		end
	end end end
	return lo, hi
end

-- Volume and centroid of A ∩ B by centre sampling at spacing h inside the AABB overlap.
local function overlap(a: P.Part, b: P.Part, h: number): (number, { number })
	local alo, ahi = aabb(a)
	local blo, bhi = aabb(b)
	local lo, hi = {}, {}
	for i = 1, 3 do
		lo[i] = math.max(alo[i], blo[i]); hi[i] = math.min(ahi[i], bhi[i])
		if lo[i] >= hi[i] then return 0, { 0, 0, 0 } end
	end
	local n, sx, sy, sz = 0, 0, 0, 0
	local x = lo[1] + h / 2
	while x < hi[1] do
		local y = lo[2] + h / 2
		while y < hi[2] do
			local z = lo[3] + h / 2
			while z < hi[3] do
				if P.insideDesign({ a }, x, y, z) and P.insideDesign({ b }, x, y, z) then
					n += 1; sx += x; sy += y; sz += z
				end
				z += h
			end
			y += h
		end
		x += h
	end
	if n == 0 then return 0, { 0, 0, 0 } end
	return n * h * h * h, { sx / n, sy / n, sz / n }
end

for _, name in F.order do
	local parts = (F :: any)[name] :: { P.Part }
	local slots: { [string]: number } = {}
	local vIron, vSteel = 0, 0
	local gripLo, gripHi = math.huge, -math.huge
	local bladeTop = -math.huge
	local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	for _, part in parts do
		slots[part.slot] = (slots[part.slot] or 0) + 1
		local v = P.analyticVolume(part)
		if part.material == "Iron" then vIron += v else vSteel += v end
		local plo, phi = aabb(part)
		for a = 1, 3 do lo[a] = math.min(lo[a], plo[a]); hi[a] = math.max(hi[a], phi[a]) end
		if part.slot == "Grip" then gripLo = math.min(gripLo, plo[2]); gripHi = math.max(gripHi, phi[2]) end
		if part.slot == "Blade" then bladeTop = math.max(bladeTop, P.supportY(part)) end
	end
	-- pairwise overlaps
	local ovTotal, ovList = 0, {}
	local ovMassY = { [0.9] = 0, [1.0] = 0, [1.1] = 0 }
	for i = 1, #parts do
		for j = i + 1, #parts do
			local v, c = overlap(parts[i], parts[j], 0.002)
			if v > 0 then
				ovTotal += v
				table.insert(ovList, string.format("%s#%d∩%s#%d=%.6f", parts[i].slot, i, parts[j].slot, j, v))
				for r in ovMassY do
					local rho = if parts[i].material == "Steel" then r else 1 -- overlap material = first part's (blueprint order)
					ovMassY[r] += rho * v * c[2]
				end
			end
		end
	end
	local rows = {}
	for _, r in { 0.9, 1.0, 1.1 } do
		local mp = P.analyticMassProps(parts, { Iron = 1, Steel = r })
		-- union correction: remove the double-counted overlap (assumes overlaps are pairwise only)
		local rhoOv = if vSteel > 0 and vIron == 0 then r else 1
		local unionMass = mp.mass - rhoOv * ovTotal
		local unionComY = (mp.com[2] * mp.mass - ovMassY[r]) / unionMass
		table.insert(rows, string.format("r=%.1f: m_sum=%.5f COMy_sum=%+.4f | m_union=%.5f COMy_union=%+.4f", r, mp.mass, mp.com[2], unionMass, unionComY))
	end
	local mp1 = P.analyticMassProps(parts, { Iron = 1, Steel = 1 })
	local slotText = {}
	for _, s in { "Blade", "Guard", "Grip", "Pommel" } do table.insert(slotText, s .. "=" .. tostring(slots[s] or 0)) end
	print(string.format("%s  parts=%d (%s)", name, #parts, table.concat(slotText, " ")))
	print(string.format("  V_sum=%.5f  V_iron=%.5f  V_steel=%.5f  overlap=%.6f -> V_union=%.5f   %s", vIron + vSteel, vIron, vSteel, ovTotal, vIron + vSteel - ovTotal, table.concat(ovList, " ")))
	print(string.format("  AABB x[%.3f, %.3f] y[%.3f, %.3f] z[%.3f, %.3f]  size %.3f x %.3f x %.3f", lo[1], hi[1], lo[2], hi[2], lo[3], hi[3], hi[1] - lo[1], hi[2] - lo[2], hi[3] - lo[3]))
	print(string.format("  grip y[%.3f, %.3f] centre %.3f   blade top %.4f   reach from O %.4f, from grip centre %.4f   COMx=%+.4f", gripLo, gripHi, (gripLo + gripHi) / 2, bladeTop, bladeTop, bladeTop - (gripLo + gripHi) / 2, mp1.com[1]))
	for _, row in rows do print("  " .. row) end
end
