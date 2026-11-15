--!nocheck
-- Hidden parts that cover nothing: K + F against K, every verdict and the measure, to the bit. args: mode(fill|copies) shard nshards count
local process = require("@lune/process")
local V = require("./v1")
local H = require("./tree/tests/Physics/PhysicsHelpers")
local TestRng = require("./tree/tests/lib/TestRng")
local Drafts = require("./tree/tests/Blueprint/Drafts")
local Sampling = V.Sampling
local fmt = string.format
local mode, shard, nshards, count = process.args[1], tonumber(process.args[2]), tonumber(process.args[3]), tonumber(process.args[4])

local function shrunk(host, f, id, slot)
	local P = H.prepare(host)
	return H.part(id, slot, host.shape, "Iron", { P.gx + f * (host.pos[1] - P.gx), P.gy + f * (host.pos[2] - P.gy), P.gz + f * (host.pos[3] - P.gz) }, host.rot, { host.size[1] * f, host.size[2] * f, host.size[3] * f })
end
local function slotFor(parts)
	local MAX = { Blade = 12, Guard = 8, Grip = 6, Pommel = 4 }
	local c = { Blade = 0, Guard = 0, Grip = 0, Pommel = 0 }
	for _, p in ipairs(parts) do c[p.slot] += 1 end
	for _, slot in ipairs({ "Blade", "Guard", "Grip", "Pommel" }) do
		if c[slot] < MAX[slot] then return slot end
	end
	error("no slot")
end
local function filler(rng, K, id, slot)
	local host = rng:pick(K)
	local kind = rng:int(1, 5)
	if kind == 5 then
		local d = rng:range(0.02, 0.0575)
		return H.part(id, slot, rng:pick({ "Block", "Ball", "Wedge", "Cylinder" }), "Iron", { rng:range(-0.7, 0.7), rng:range(0.1, 4.9), rng:range(-0.25, 0.25) }, H.randomQuat(rng), { d, d, d })
	elseif kind == 4 and slot >= host.slot then
		local copy = Drafts.deepCopy(host)
		copy.id, copy.slot = id, slot
		return copy
	elseif kind == 3 and host.shape == "Block" then
		local P = H.prepare(host)
		local d = math.min(host.size[1], host.size[2], host.size[3]) * rng:range(0.15, 0.4)
		return H.part(id, slot, rng:pick({ "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }), "Iron", { P.gx, P.gy, P.gz }, H.randomQuat(rng), { d, d, d })
	end
	return shrunk(host, if rng:float() < 0.5 then rng:range(0.1, 0.6) else rng:range(0.6, 0.97), id, slot)
end
local function large(rng)
	local u = rng:float()
	if u < 0.4 then return H.ornate() end
	if u < 0.7 then
		local base = H.p1()
		for _ = 1, rng:int(8, 12) do table.remove(base.parts, rng:int(1, #base.parts)) end
		for i, p in ipairs(base.parts) do p.id = i end
		return base
	end
	local name = rng:pick({ "F1", "F3", "F4", "F5" })
	return H.f(name)
end
local function same(after, before, n)
	if after.hSurf ~= before.hSurf then return false, "hSurf" end
	for i = 1, n do
		if after.kept[i] ~= before.kept[i] then return false, "kept " .. i end
		if after.exposedKept[i] ~= before.exposedKept[i] then return false, "area " .. i end
	end
	return true
end
local n, moved, cleanedF = 0, 0, 0
for k = 1, count do
	if (k - 1) % nshards == shard then
		local rng = TestRng.new(90000 + k)
		n += 1
		if mode == "fill" then
			local base = large(rng)
			local filled = Drafts.deepCopy(base)
			local c = rng:int(1, 24 - #base.parts)
			if c >= 1 then
				for j = 1, c do
					table.insert(filled.parts, filler(rng, base.parts, 100 + j, slotFor(filled.parts)))
				end
				local ok, why = same(Sampling.exposure(H.prepared(filled)), Sampling.exposure(H.prepared(base)), #base.parts)
				if not ok then
					moved += 1
					print("MOVED", k, why)
				end
			end
		else
			-- a part poking out of F4's or F1's blade, on either side of 2 %, hidden copies inside it
			local F = H.f(rng:pick({ "F4", "F1", "F3" }))
			local hi = 4
			local host = F.parts[hi]
			local size = { host.size[1] * rng:range(0.7, 0.98), host.size[2] * rng:range(0.7, 0.98), host.size[3] * rng:range(0.3, 0.7) }
			local poke = rng:range(0, 0.1)
			local X = H.part(50, "Blade", "Block", "Iron", { host.pos[1], host.pos[2] - (host.size[2] / 2 - size[2] / 2 + poke), host.pos[3] }, host.rot, size)
			local base = Drafts.deepCopy(F)
			table.insert(base.parts, X)
			local filled = Drafts.deepCopy(base)
			local m = rng:int(1, math.min(18, 24 - #base.parts))
			for j = 1, m do
				table.insert(filled.parts, shrunk(X, 0.985 - 0.012 * j, 100 + j, slotFor(filled.parts)))
			end
			local ok, why = same(Sampling.exposure(H.prepared(filled)), Sampling.exposure(H.prepared(base)), #base.parts)
			if not ok then
				moved += 1
				print("MOVED", k, why)
			end
		end
	end
end
print(fmt("SUMMARY %s %d: %d designs, %d moved", mode, shard, n, moved))
