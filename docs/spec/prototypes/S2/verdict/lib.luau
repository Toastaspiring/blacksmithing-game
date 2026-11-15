--!nocheck
-- V-A: what the probes share.
local Sampling = require("./tree/src/shared/Physics/Sampling")
local Shapes = require("./tree/src/shared/Physics/Shapes")
local MassProps = require("./tree/src/shared/Physics/MassProps")
local Quat = require("./tree/src/shared/Blueprint/Quat")
local Fx = require("./proto/fixtures")

local L = {}
L.RANK = { Blade = 1, Guard = 2, Grip = 3, Pommel = 4 }
L.MAXES = { Blade = 12, Guard = 8, Grip = 6, Pommel = 4 }
L.I = { 0, 0, 0, 1 }
L.HIT_MIN = { -0.8, 0, -0.3 }
L.HIT_MAX = { 0.8, 5, 0.3 }

function L.rng(seed)
	local s = bit32.band(seed * 2654435761 + 12345, 0xFFFFFFFF)
	if s == 0 then s = 88172645 end
	local R = {}
	function R.u32()
		s = bit32.bxor(s, bit32.lshift(s, 13))
		s = bit32.bxor(s, bit32.rshift(s, 17))
		s = bit32.bxor(s, bit32.lshift(s, 5))
		return s
	end
	function R.float()
		return R.u32() / 4294967296
	end
	function R.range(a, b)
		return a + (b - a) * R.float()
	end
	function R.int(a, b)
		return a + math.floor(R.float() * (b - a + 1))
	end
	function R.pick(list)
		return list[R.int(1, #list)]
	end
	function R.quat()
		while true do
			local a, b = R.range(-1, 1), R.range(-1, 1)
			local c, d = R.range(-1, 1), R.range(-1, 1)
			local s1, s2 = a * a + b * b, c * c + d * d
			if s1 < 1 and s1 > 1e-4 and s2 < 1 and s2 > 1e-4 then
				local k = math.sqrt((1 - s1) / s2)
				return Quat.hemisphere(Quat.normalize({ a, b, c * k, d * k }))
			end
		end
	end
	function R.smallTilt(deg)
		local ax, ay, az = R.range(-1, 1), R.range(-1, 1), R.range(-1, 1)
		local n = math.sqrt(ax * ax + ay * ay + az * az) + 1e-9
		local half = math.rad(R.range(-deg, deg)) / 2
		local sn = math.sin(half)
		return Quat.hemisphere(Quat.normalize({ ax / n * sn, ay / n * sn, az / n * sn, math.cos(half) }))
	end
	return R
end

function L.prep(parts)
	local P = table.create(#parts)
	for i, p in ipairs(parts) do
		P[i] = Shapes.prepare(p, i)
	end
	return P
end

function L.copyPart(p)
	return { id = p.id, label = p.label, slot = p.slot, shape = p.shape, material = p.material, pos = { p.pos[1], p.pos[2], p.pos[3] },
		rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] }, size = { p.size[1], p.size[2], p.size[3] } }
end

function L.copyParts(parts)
	local out = table.create(#parts)
	for i, p in ipairs(parts) do
		out[i] = L.copyPart(p)
	end
	return out
end

function L.renumber(parts)
	for i, p in ipairs(parts) do
		p.id = i
	end
	return parts
end

function L.inHitbox(p)
	local P = Shapes.prepare(p, 1)
	local e = 1e-4
	return P.minx >= L.HIT_MIN[1] - e and P.miny >= L.HIT_MIN[2] - e and P.minz >= L.HIT_MIN[3] - e and P.maxx <= L.HIT_MAX[1] + e
		and P.maxy <= L.HIT_MAX[2] + e and P.maxz <= L.HIT_MAX[3] + e
end

function L.slotCounts(parts)
	local c = { Blade = 0, Guard = 0, Grip = 0, Pommel = 0 }
	for _, p in ipairs(parts) do
		c[p.slot] += 1
	end
	return c
end

function L.quickValid(parts)
	if #parts > 24 then return false end
	local c = L.slotCounts(parts)
	if c.Blade < 1 or c.Grip < 1 then return false end
	for s, m in pairs(L.MAXES) do
		if c[s] > m then return false end
	end
	for _, p in ipairs(parts) do
		if not L.inHitbox(p) then return false end
	end
	return true
end

-- a free slot (nil when there is none), preferring `want`
function L.freeSlot(counts, want, rng)
	if want and counts[want] < L.MAXES[want] then
		return want
	end
	local order = { "Blade", "Guard", "Grip", "Pommel" }
	local start = if rng then rng.int(1, 4) else 1
	for k = 0, 3 do
		local s = order[(start + k - 1) % 4 + 1]
		if counts[s] < L.MAXES[s] then
			return s
		end
	end
	return nil
end

-- every calibration, golden and cost fixture
function L.fixtures()
	local out = {}
	for _, list in ipairs({ Fx.calibration(), Fx.golden(), Fx.perf() }) do
		for _, b in ipairs(list) do
			table.insert(out, b)
		end
	end
	return out
end

function L.byPrefix(prefix)
	for _, b in ipairs(L.fixtures()) do
		if string.sub(b.name, 1, #prefix) == prefix then
			return b
		end
	end
	error("no fixture " .. prefix)
end

function L.median(list)
	local t = table.clone(list)
	table.sort(t)
	return t[(#t + 1) // 2]
end

function L.stepsOf(R)
	local out = {}
	for _, s in ipairs(R.steps or {}) do
		out[s.step] = s
	end
	return out
end

function L.factor(step, name)
	for _, f in ipairs(step.factors) do
		if f.factor == name then
			return f
		end
	end
end

-- Homothety of a part about its centroid: stays inside any convex host that holds the part itself.
function L.shrunk(host, f, id, slot)
	local P = Shapes.prepare(host, 1)
	local q = L.copyPart(host)
	q.id, q.slot = id or host.id, slot or host.slot
	q.pos = { P.gx + f * (host.pos[1] - P.gx), P.gy + f * (host.pos[2] - P.gy), P.gz + f * (host.pos[3] - P.gz) }
	q.size = { host.size[1] * f, host.size[2] * f, host.size[3] * f }
	return q
end

return L
