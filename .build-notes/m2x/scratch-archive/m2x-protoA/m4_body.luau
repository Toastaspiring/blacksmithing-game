local res = { designs = 0, orderRuns = 0, orderBad = 0, mirrorRuns = 0, mirrorBadVerdict = 0, mirrorTwinVerdict = 0, mirrorMaxDiff = 0, mirrorWorst = "",
	mirrorMaxDiffZ = 0, mirrorWorstZ = "", mirrorTwinMaxDiff = 0, copyRuns = 0, copyBad = 0, dustRuns = 0, dustBad = 0, bad = {} }
local rng = TestRng.new(12345 + shard)
local t0 = os.clock()
local Shapes = L.Shapes

-- classes of parts that only an index can tell apart: exact copies (Shapes.sameSolid) in the same slot and material
local function classesOf(P, parts)
	local cls = {}
	for i = 1, #P do
		cls[i] = parts[i].id
		for j = 1, i - 1 do
			if Shapes.sameSolid(P[i], P[j]) and parts[i].slot == parts[j].slot and parts[i].material == parts[j].material then
				cls[i] = cls[j]
				break
			end
		end
	end
	return cls
end
-- per class (keyed by the class id), the sorted list of "kept:shown" entries; nil shown (no reading) prints as -1
local function signature(parts, kept, shown, clsOfId)
	local by = {}
	for i, p in ipairs(parts) do
		local c = clsOfId[p.id] or p.id
		by[c] = by[c] or {}
		table.insert(by[c], tostring(kept[i]) .. ":" .. fmt("%.17g", shown[i] or -1))
	end
	local keys = {}
	for c, list in by do
		table.sort(list)
		table.insert(keys, c)
	end
	table.sort(keys)
	local out = {}
	for _, c in ipairs(keys) do table.insert(out, c .. "=" .. table.concat(by[c], ",")) end
	return table.concat(out, "|")
end

for k, d in ipairs(designs) do
	if (k - 1) % nshards == shard and #d.parts > 0 and #d.parts <= 24 then
		res.designs += 1
		local parts = d.parts
		for i, p in ipairs(parts) do p.id = i end
		local e0, shown0, share0, P0 = verdict(parts)
		local cls = classesOf(P0, parts)
		local clsOfId = {}
		for i, p in ipairs(parts) do clsOfId[p.id] = cls[i] end
		local sig0 = signature(parts, e0.kept, shown0, clsOfId)
		local r0 = L.Sampling.ranked(P0)
		-- orders: every part's verdict and shown area travel with its id (exact copies in one slot and material as a class)
		for o = 1, ORDERS do
			local perm = {}
			for i = 1, #parts do perm[i] = parts[i] end
			for i = #perm, 2, -1 do
				local j = rng:int(1, i)
				perm[i], perm[j] = perm[j], perm[i]
			end
			local e, shown = verdict(perm)
			res.orderRuns += 1
			if signature(perm, e.kept, shown, clsOfId) ~= sig0 then
				res.orderBad += 1
				table.insert(res.bad, "order: " .. d.name)
			end
		end
		-- mirror images: image part i against part i; a difference is a twin swap when the rank of i against some part flips
		for _, plane in ipairs({ "X", "Z" }) do
			local img = {}
			for i, p in ipairs(parts) do img[i] = Mirror.reflect(p, plane) end
			local ok, e, shown, share, Q = pcall(verdict, img)
			if ok then
				res.mirrorRuns += 1
				local r1 = L.Sampling.ranked(Q)
				local badV, twinV = false, false
				for i = 1, #parts do
					local flipped = false
					for j = 1, #parts do
						if j ~= i and (r0[i] < r0[j]) ~= (r1[i] < r1[j]) then
							flipped = true
							break
						end
					end
					if e.kept[i] ~= e0.kept[i] then
						if flipped then twinV = true else badV = true end
					end
					if share[i] and share0[i] then
						local dd = math.abs(share[i] - share0[i])
						if flipped then
							if dd > res.mirrorTwinMaxDiff then res.mirrorTwinMaxDiff = dd end
						elseif plane == "X" then
							if dd > res.mirrorMaxDiff then res.mirrorMaxDiff, res.mirrorWorst = dd, fmt("%s %s part %d (%s) %.12f vs %.12f", d.name, plane, i, parts[i].shape, share0[i], share[i]) end
						else
							if dd > res.mirrorMaxDiffZ then res.mirrorMaxDiffZ, res.mirrorWorstZ = dd, fmt("%s %s part %d (%s) %.12f vs %.12f", d.name, plane, i, parts[i].shape, share0[i], share[i]) end
						end
					end
				end
				if badV then
					res.mirrorBadVerdict += 1
					table.insert(res.bad, "mirror " .. plane .. ": " .. d.name)
				end
				if twinV then res.mirrorTwinVerdict += 1 end
			end
		end
		-- an exact copy of a random part first, then last: everything outside its class bit for bit, its class one cleaned
		-- entry more (a copy has no reading)
		local src = parts[rng:int(1, #parts)]
		for _, where in ipairs(if #parts < 24 then { "first", "last" } else {}) do
			local list = {}
			local copy = { id = #parts + 1, slot = src.slot, shape = src.shape, material = src.material, pos = { src.pos[1], src.pos[2], src.pos[3] }, rot = { src.rot[1], src.rot[2], src.rot[3], src.rot[4] }, size = { src.size[1], src.size[2], src.size[3] } }
			if where == "first" then table.insert(list, copy) end
			for _, p in ipairs(parts) do table.insert(list, p) end
			if where == "last" then table.insert(list, copy) end
			local e, shown = verdict(list)
			res.copyRuns += 1
			local c2 = {}
			for id, c in clsOfId do c2[id] = c end
			c2[copy.id] = clsOfId[src.id]
			local want, kept2, shown2 = {}, {}, {}
			for i, p in ipairs(parts) do
				want[i], kept2[i], shown2[i] = p, e0.kept[i], shown0[i]
			end
			table.insert(want, copy)
			kept2[#want] = false
			local sigW = signature(want, kept2, shown2, c2)
			if signature(list, e.kept, shown, c2) ~= sigW or #e.cleaned ~= #e0.cleaned + 1 then
				res.copyBad += 1
				table.insert(res.bad, "copy " .. where .. ": " .. d.name)
			end
		end
		-- Dust at a part's surface
		if #parts < 24 then
			local host = parts[rng:int(1, #parts)]
			local hp = L.prep({ host })[1]
			local speck = { id = #parts + 1, slot = host.slot, shape = "Block", material = "Iron", pos = { hp.maxx, (hp.miny + hp.maxy) / 2, hp.cz }, rot = { 0, 0, 0, 1 }, size = { 0.05, 0.05, 0.05 } }
			local list = {}
			for _, p in ipairs(parts) do table.insert(list, p) end
			table.insert(list, rng:int(1, #list + 1), speck)
			local e, shown = verdict(list)
			res.dustRuns += 1
			local foundDust = false
			for _, c in ipairs(e.cleaned) do
				if c.partId == speck.id and c.reason == "Dust" then foundDust = true end
			end
			local rest, restKept, restShown = {}, {}, {}
			for i, p in ipairs(list) do
				if p ~= speck then
					table.insert(rest, p)
					restKept[#rest], restShown[#rest] = e.kept[i], shown[i]
				end
			end
			if not foundDust or signature(rest, restKept, restShown, clsOfId) ~= sig0 then
				res.dustBad += 1
				table.insert(res.bad, "dust: " .. d.name)
			end
		end
	end
end
