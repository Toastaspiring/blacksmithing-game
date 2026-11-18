--!nocheck
-- Balls in cages of 6 walls and 12 edge blocks (V1's family; also turned about a random axis): the build's verdict against
-- the truth where the reading lies within 0.3–8 %: lune run b_cages -- <seed> <count>
local process = require("@lune/process")
local L = require("./lib")
local mk = require("./cagelib")
local TestRng = require("./repo/tests/lib/TestRng")
local fmt = string.format
local seed, count = tonumber(process.args[1]) or 1, tonumber(process.args[2]) or 300
local rng = TestRng.new(seed)
local Quat = L.Quat
local falseKept, falseClean, near, worstUnder, worstOver = 0, 0, 0, { 0 }, { 0 }
for t = 1, count do
	local r = rng:pick({ 0.05, 0.08, 0.1, 0.15, 0.2, 0.25 })
	local g = rng:range(-0.006, 0.02)
	local b = r * rng:range(0.1, 0.6)
	local parts = mk.cage(L, r, g, b, 0.02, 2 * r + 0.1, { 0, 2.5, 0 })
	if rng:float() < 0.5 then
		-- turn the cage (walls and edge blocks) about the Ball's centre
		local q = Quat.hemisphere(Quat.normalize({ rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1) }))
		for k = 2, #parts do
			local p = parts[k]
			local d = { p.pos[1], p.pos[2] - 2.5, p.pos[3] }
			local w = Quat.rotate(q, d)
			p.pos = { w[1], w[2] + 2.5, w[3] }
			local nr = Quat.hemisphere(Quat.normalize(Quat.mul(q, p.rot)))
			p.rot = { nr[1], nr[2], nr[3], nr[4] }
		end
	end
	L.renumber(parts)
	local P = L.prep(parts)
	local read = L.readOf(P, 1, L.models(P))
	if read > 0.003 and read < 0.08 then
		near += 1
		local _, _, hider = L.Oracle.flags(P)
		local truth = L.Oracle.share(P, 1, hider)
		if read >= 0.02 and truth < 0.02 then
			falseKept += 1
			print(string.format("FALSEKEPT reads %.4f%% truth %.4f%% r %.3f g %.5f b %.4f %s", 100 * read, 100 * truth, r, g, b, require("@lune/serde").encode("json", parts)))
			if read - truth > worstOver[1] then worstOver = { read - truth, r, g, b, read, truth } end
		elseif read < 0.02 and truth >= 0.02 then
			falseClean += 1
			print(string.format("FALSECLEAN reads %.4f%% truth %.4f%% r %.3f g %.5f b %.4f %s", 100 * read, 100 * truth, r, g, b, require("@lune/serde").encode("json", parts)))
			if truth - read > worstUnder[1] then worstUnder = { truth - read, r, g, b, read, truth } end
		end
	end
end
print(fmt("seed %d: %d cages, %d read 0.3–8 %%; false kept %d (worst: reads %.3f%%, truth %.3f%%, r %.2f g %.5f b %.4f); false cleaned %d (worst: reads %.3f%%, truth %.3f%%, r %.2f g %.5f b %.4f)",
	seed, count, near, falseKept, 100 * (worstOver[5] or 0), 100 * (worstOver[6] or 0), worstOver[2] or 0, worstOver[3] or 0, worstOver[4] or 0,
	falseClean, 100 * (worstUnder[5] or 0), 100 * (worstUnder[6] or 0), worstUnder[2] or 0, worstUnder[3] or 0, worstUnder[4] or 0))
