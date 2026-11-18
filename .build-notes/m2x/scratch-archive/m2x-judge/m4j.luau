--!nocheck
-- M4 by the judge, on A's reading as recommended (canonical frames; and the baseline for comparison): every design read in
-- its own order and in 3 random orders (ids travel with the parts): kept row, cleaned list and every part's full shown area
-- bit for bit; then its mirror images (Blueprint/Mirror "X" and "Z"): each part's verdict against its own image's. A
-- verdict that differs is settled: a true twin (the part's image coincides with another part, so the coincident face's
-- owner swaps by rank) or an exact tie (the brute force's bracket J+/J− is wider than 1e-9 of the part), else a defect.
-- args: set [every] [model base|canon]
local process = require("@lune/process")
local fs = require("@lune/fs")
local L = require("./jlib")
local S = require("./jsets")
local T = require("./tangles")
local Mirror = require("./repo/src/shared/Blueprint/Mirror")
local Rng = require("./rng")
local fmt = string.format

local set = process.args[1] or "tangles7"
local every = tonumber(process.args[2] or "1") or 1
local modelName = process.args[3] or "canon"
local opts = if modelName == "canon" or modelName == "cons" then { canon = true } else nil
local readFn = if modelName == "cons" then L.readC else L.readA

local designs
if set == "fixtures" then
	designs = S.fixtures()
elseif set == "attacksA" then
	designs = S.attackCorpusA()
elseif set == "climbed" then
	designs = S.climbed()
elseif string.sub(set, 1, 7) == "tangles" then
	designs = T.corpus(tonumber(string.sub(set, 8)) or 7, 4000, 3, 14)
elseif string.sub(set, 1, 5) == "file:" then
	designs = S.json(string.sub(set, 6), "")
end

local rng = Rng.new(4242)

local function read(parts)
	local P = L.prep(parts)
	local flags = { L.flags(P) }
	local A = readFn(P, opts, flags)
	local byId = {}
	for i, p in ipairs(parts) do
		byId[p.id] = if A[i] then { shown = A[i].shown, kept = A[i].shown >= 0.02 * A[i].area, area = A[i].area } else { shown = false, kept = false }
	end
	-- the verdict exactly as Sampling.exposure decides it (copies, Dust, early stop): through A's Sampling with the same model
	return byId, P, flags
end

local st = { designs = 0, parts = 0, permRuns = 0, permBitDiff = 0, permKeptDiff = 0, mirrorRuns = 0, mirrorVerdictDiff = 0,
	twin = 0, tie = 0, defect = 0, defects = {} }

local function hasTwin(parts, i, plane)
	-- does part i's mirror image coincide (as a solid) with another part of the design?
	local img = Mirror.reflect(parts[i], plane)
	local Pi = L.Shapes.prepare(img, 1)
	for j, q in ipairs(parts) do
		if j ~= i and q.shape == parts[i].shape then
			local Pj = L.Shapes.prepare(q, 2)
			local d = math.abs(Pi.cx - Pj.cx) + math.abs(Pi.cy - Pj.cy) + math.abs(Pi.cz - Pj.cz)
			local s = math.abs(Pi.volume - Pj.volume)
			if d < 1e-6 and s < 1e-9 then return true end
		end
	end
	return false
end

local function tieWidth(parts, i)
	local P = L.prep(parts)
	local flags = { L.flags(P) }
	local rank, byRank, isCopy, dust, hider = table.unpack(flags)
	if not hider[i] then return 0 end
	local _, Jm = L.JBrute.readAll(P, flags, L.cands, nil, 1, nil) -- models only (limit 1 skips every union)
	local idx, higher = L.cands(P, i, rank, byRank, hider)
	local hm = {}
	for k, j in ipairs(idx) do hm[k] = Jm[j] end
	local w = 0
	for f = 1, #Jm[i].facets do
		local lo = L.JBrute.facetShown(Jm[i], f, hm, higher, nil, 1e-11)
		local hi = L.JBrute.facetShown(Jm[i], f, hm, higher, nil, -1e-11)
		w += hi - lo
	end
	return w / Jm[i].total
end

local t0 = os.clock()
for k, d in ipairs(designs) do
	if (k - 1) % every == 0 then
		st.designs += 1
		local parts = d.parts
		local base, P0 = read(parts)
		-- parts with an exact copy: which member survives is the index's call (slot and material tie), so they are compared
		-- as a class, i.e. left out here
		local copyClass = {}
		for i = 1, #P0 do
			for j = 1, #P0 do
				if i ~= j and L.Shapes.sameSolid(P0[i], P0[j]) then copyClass[parts[i].id] = true end
			end
		end
		for _, p in ipairs(parts) do st.parts += 1 end
		-- permutations
		for _ = 1, 3 do
			local order = {}
			for i = 1, #parts do order[i] = i end
			for i = #order, 2, -1 do
				local j = rng:NextInteger(1, i)
				order[i], order[j] = order[j], order[i]
			end
			local perm = {}
			for i, o in ipairs(order) do perm[i] = parts[o] end
			local r = read(perm)
			st.permRuns += 1
			local bit, kd = false, false
			for _, p in ipairs(parts) do
				if not copyClass[p.id] then
					local a, b = base[p.id], r[p.id]
					if a.shown ~= b.shown then bit = true end
					if a.kept ~= b.kept then kd = true end
				end
			end
			if bit then st.permBitDiff += 1 end
			if kd then st.permKeptDiff += 1 end
		end
		-- mirror images
		for _, plane in ipairs({ "X", "Z" }) do
			local img = {}
			for i, p in ipairs(parts) do img[i] = Mirror.reflect(p, plane) end
			local r = read(img)
			st.mirrorRuns += 1
			for i, p in ipairs(parts) do
				if not copyClass[p.id] and base[p.id].kept ~= r[p.id].kept then
					st.mirrorVerdictDiff += 1
					-- does i's rank against some other part flip between the design and its image? (the rank keys |cx| and cx
					-- under X, cz under Z: the coincident face's owner swaps by rule)
					local P1, P2 = L.prep(parts), L.prep(img)
					local r1, r2 = L.Sampling.ranked(P1), L.Sampling.ranked(P2)
					local flipped = false
					for j = 1, #parts do
						if j ~= i and (r1[i] < r1[j]) ~= (r2[i] < r2[j]) then flipped = true end
					end
					if hasTwin(parts, i, plane) then
						st.twin += 1
					elseif flipped then
						st.rankFlip = (st.rankFlip or 0) + 1
					else
						local w = math.max(tieWidth(parts, i), tieWidth(img, i))
						if w > 1e-9 then
							st.tie += 1
						else
							st.defect += 1
							table.insert(st.defects, fmt("%s part %d (%s) plane %s: %s %.9f / image %.9f", d.name, i, p.shape, plane,
								if base[p.id].kept then "kept" else "cleaned", base[p.id].shown / (base[p.id].area or 1),
								r[p.id].shown / (r[p.id].area or 1)))
						end
					end
				end
			end
		end
		if st.designs % 250 == 0 then
			print(fmt("  %d designs: perm runs %d (bits differ %d, kept differ %d), mirror runs %d (verdicts differ %d: twins %d, ties %d, defects %d), %.0f s",
				st.designs, st.permRuns, st.permBitDiff, st.permKeptDiff, st.mirrorRuns, st.mirrorVerdictDiff, st.twin, st.tie, st.defect, os.clock() - t0))
		end
	end
end
print(fmt("M4 %s every %d model %s: %d designs, %d parts; %d permuted runs: shown bits differ in %d, kept rows in %d; %d mirror images: verdicts differ on %d parts (true twins %d, rank order flipped %d, exact ties %d, unexplained %d); %.0f s",
	set, every, modelName, st.designs, st.parts, st.permRuns, st.permBitDiff, st.permKeptDiff, st.mirrorRuns, st.mirrorVerdictDiff,
	st.twin, st.rankFlip or 0, st.tie, st.defect, os.clock() - t0))
for _, s in ipairs(st.defects) do print("  " .. s) end
