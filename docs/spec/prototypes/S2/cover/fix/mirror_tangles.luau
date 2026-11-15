--!nocheck
-- V2's mirror probe: Cover.spec's tangles mirrored across X and Z; verdicts that differ among parts that are neither exact copies nor twins
local process = require("@lune/process")
local L = require("./lab")
local H, Cover, Shapes, Quat, Sampling = L.H, L.Cover, L.Shapes, L.Quat, L.Sampling
local NB = L.Brute
local first, count = tonumber(process.args[1]) or 1, tonumber(process.args[2]) or 100
local EXACT, TIE = 1e-9, 1e-11
local SHAPES = { "Block", "Block", "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" }
local OFFSETS = { 0, 0, 0, 1e-7, -1e-7, 2e-7, -2e-7, 1e-8, -1e-8, 1.5e-8, -1.5e-8, 3e-8, -3e-8, 1e-9, -1e-9, 1e-6, -1e-6, 1e-5, -1e-5,
	0.012, -0.012, 0.0119999, 0.0120001, 0.012 + 1e-7, 0.012 - 1e-7, 0.001, -0.001, 0.05 }
local R = 0.70710678118654757
local AXIS_ROTS = { { 0, 0, 0, 1 }, { 0, 0, R, R }, { 0, R, 0, R }, { R, 0, 0, R }, { 0, 0, 1, 0 }, { 0.5, 0.5, 0.5, 0.5 } }
local function sized(shape, s)
	if shape == "Ball" then local m = math.min(s[1], s[2], s[3]) return { m, m, m }
	elseif shape == "Cylinder" then local m = math.min(s[2], s[3]) return { s[1], m, m } end
	return s
end
local function tangle(rng)
	local parts = {}
	local function add(shape, pos, rot, size) table.insert(parts, H.solid(#parts + 1, shape, pos, rot, sized(shape, size))) end
	local function rsize() return { rng:range(0.02, 0.82), rng:range(0.02, 0.82), rng:range(0.02, 0.82) } end
	for k = 1, rng:int(3, 10) do
		local mode = rng:int(1, 10)
		local shape = rng:pick(SHAPES)
		if k == 1 or mode <= 3 then
			local rot = if rng:float() < 0.6 then rng:pick(AXIS_ROTS) else H.randomQuat(rng)
			add(shape, { rng:range(-0.3, 0.3), rng:range(-0.3, 0.3), rng:range(-0.3, 0.3) }, rot, rsize())
		elseif mode <= 7 then
			local host = rng:pick(parts)
			local axis = rng:int(1, 3)
			local side = if rng:float() < 0.5 then -1 else 1
			local size = sized(shape, rsize())
			local off = rng:pick(OFFSETS)
			local d = side * (host.size[axis] / 2 + size[axis] / 2 + off)
			if rng:float() < 0.25 then d = side * (host.size[axis] / 2 - size[axis] / 2 + off) end
			local l = { 0, 0, 0 }
			l[axis] = d
			for a = 1, 3 do
				if a ~= axis then
					l[a] = if rng:float() < 0.3 then (if rng:float() < 0.5 then -1 else 1) * (host.size[a] / 2 - size[a] / 2) + rng:pick(OFFSETS)
						else (rng:float() - 0.5) * host.size[a]
				end
			end
			local w = Quat.rotate(host.rot, l)
			add(shape, { host.pos[1] + w[1], host.pos[2] + w[2], host.pos[3] + w[3] }, table.clone(host.rot), size)
		elseif mode == 8 then
			local host = rng:pick(parts)
			local rot, pos = table.clone(host.rot), table.clone(host.pos)
			local r = rng:float()
			if r < 0.3 and (host.shape == "Cylinder" or host.shape == "Ball") then
				rot = Quat.hemisphere(Quat.normalize(Quat.mul(host.rot, H.axisAngle(1, 0, 0, rng:range(0, 90)))))
			elseif r < 0.6 then
				local a = rng:int(1, 3)
				pos[a] += rng:pick(OFFSETS)
			end
			table.insert(parts, H.solid(#parts + 1, host.shape, pos, rot, table.clone(host.size)))
		elseif mode == 9 then
			local host = rng:pick(parts)
			add("Block", { host.pos[1] + host.size[1] / 2, host.pos[2], host.pos[3] }, H.I, { 0.05, 0.05, 0.05 })
		else
			local host = rng:pick(parts)
			local axis = rng:int(1, 3)
			local size = { host.size[1] * rng:range(0.3, 1.3), host.size[2] * rng:range(0.3, 1.3), host.size[3] * rng:range(0.3, 1.3) }
			size[axis] = math.max(rng:pick({ 0.02, 0.013, 0.012, 0.011, 0.03 }), 0.02)
			local l = { 0, 0, 0 }
			l[axis] = host.size[axis] / 2 + size[axis] / 2 + rng:pick(OFFSETS)
			local w = Quat.rotate(host.rot, l)
			add("Block", { host.pos[1] + w[1], host.pos[2] + w[2], host.pos[3] + w[3] }, table.clone(host.rot), size)
		end
	end
	return parts
end
local differ, images, round, other = 0, 0, 0, 0
local examples = {}
for seed = first, first + count - 1 do
	local rng = L.TestRng.new(seed)
	local parts = tangle(rng)
	local P = L.prepared(parts)
	local ka = L.Sampling.exposure(P).kept
	for _, plane in ipairs({ "X", "Z" }) do
		local img = {}
		for i, p in ipairs(parts) do img[i] = L.Mirror.reflect(p, plane) end
		local Q = L.prepared(img)
		local kb = L.Sampling.exposure(Q).kept
		for i = 1, #parts do
			local skip = false
			for j = 1, #parts do
				if j ~= i and (L.Shapes.sameSolid(P[j], P[i]) or L.Shapes.sameSolid(Q[j], P[i])) then skip = true end
			end
			if not skip and P[i].volume >= L.Geo.MIN_PART_VOLUME then
				images += 1
				if ka[i] ~= kb[i] then
					differ += 1
					-- a round copy: another part of the same shape, centre and size, round
					local isRound = false
					for j = 1, #parts do
						if j ~= i and P[j].code == P[i].code and (P[i].code == L.Shapes.CYLINDER or P[i].code == L.Shapes.BALL)
							and P[j].cx == P[i].cx and P[j].cy == P[i].cy and P[j].cz == P[i].cz and P[j].hx == P[i].hx and P[j].r == P[i].r then
							isRound = true
						end
					end
					if isRound then round += 1 else other += 1; if #examples < 5 then table.insert(examples, string.format("seed %d part %d %s across %s", seed, i, P[i].shape, plane)) end end
				end
			end
		end
	end
end
print(string.format("tangles %d..%d: %d part images, %d verdicts differ: %d round copies, %d other", first, first + count - 1, images, differ, round, other))
for _, e in ipairs(examples) do print("  " .. e) end
