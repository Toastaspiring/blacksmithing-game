--!nocheck
-- (a) Does a hidden part move what the verdict reads on a part it does not cover? K against K + fill, every part's full reading, to the bit; where a reading moves, does the truth move by as much?
-- Fill: wholly inside a host, not touching its surface (so it covers nothing), in numbers up to 24, many near one patch; Dust anywhere; copies. args: seed count
local process = require("@lune/process")
local L = require("./lib")
local T = L.T
local fmt = string.format
local Force, Shapes = L.Force, L.Shapes
local seed, count = tonumber(process.args[1]) or 1, tonumber(process.args[2]) or 200
math.randomseed(seed)
local rnd = math.random
local function range(a, b) return a + (b - a) * rnd() end
T.SPACING, T.MAX_LINES = 0.001, 3000
local NAMES = { "F1", "F2", "F3", "F4", "F5", "C01", "C02 Arming (Iron)", "C04", "C05", "C06", "C07", "C08", "C09", "C10", "C11", "C12", "C13", "C14", "C15", "P1", "P2", "P3", "P4", "P5" }
local function fullRead(parts)
	L.renumber(parts)
	local P = L.prep(parts)
	Force.FORCE.read, Force.FORCE.fullRead = {}, true
	local ex = Force.exposure(P)
	local read = Force.FORCE.read
	Force.FORCE.read, Force.FORCE.fullRead = nil, nil
	return read, ex
end
local designs, moved, unexplained, fillKept = 0, 0, 0, 0
local MAX = { Blade = 12, Guard = 8, Grip = 6, Pommel = 4 }
for d = 1, count do
	local K = L.renumber(L.copyParts((L.fixture(NAMES[math.random(1, #NAMES)]))))
	local readK = fullRead(L.copyParts(K))
	local parts = L.copyParts(K)
	-- fill: inside a Block host, its surface at least 0.03 from the host's: covers nothing; as many as the slots take
	local c = { Blade = 0, Guard = 0, Grip = 0, Pommel = 0 }
	for _, p in ipairs(parts) do c[p.slot] += 1 end
	local hosts = {}
	for _, p in ipairs(K) do
		if p.shape == "Block" and math.min(p.size[1], p.size[2], p.size[3]) >= 0.1 then table.insert(hosts, p) end
	end
	local nf = 0
	if #hosts > 0 then
		local host = hosts[math.random(1, #hosts)]
		local PP = Shapes.prepare(host, 1)
		local target = math.random(1, 24 - math.min(#parts, 23))
		for k = 1, target do
			if #parts >= 24 then break end
			local slot
			for _, s in ipairs({ "Pommel", "Grip", "Guard", "Blade" }) do
				if c[s] < MAX[s] then slot = s break end
			end
			if not slot then break end
			c[slot] += 1
			local hx, hy, hz = host.size[1] / 2 - 0.03, host.size[2] / 2 - 0.03, host.size[3] / 2 - 0.03
			if hx > 0.012 and hy > 0.012 and hz > 0.012 then
				local a, b, e = range(0.024, 2 * hx), range(0.024, 2 * hy), range(0.024, 2 * hz)
				local lx, ly, lz = range(-hx + a / 2, hx - a / 2), range(-hy + b / 2, hy - b / 2), range(-hz + e / 2, hz - e / 2)
				local x, y, z = Shapes.toWorld(PP, lx, ly, lz)
				table.insert(parts, L.part("F", "Block", slot, { x, y, z }, host.rot, { a, b, e }))
				nf += 1
			end
		end
	end
	if nf > 0 then
		designs += 1
		local readF = fullRead(parts)
		local any = false
		for i = 1, #K do
			if readK[i] ~= readF[i] then
				any = true
				moved += 1
				print(fmt("reading moved: %s part %d: %.17g -> %.17g", K[i].label or "?", i, readK[i] or -1, readF[i] or -1))
			end
		end
	end
end
print(fmt("seed %d: %d designs with fill that covers nothing: %d parts' readings moved", seed, designs, moved))
