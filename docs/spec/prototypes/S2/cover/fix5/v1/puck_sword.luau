--!nocheck
-- V1 (m2x, round 5): rodrim.luau's hidden pucks in a sword. F5 with its guard a round disk (a Cylinder r R along Z, LEN
-- long, at the guard's place) and its blade GROW longer, plus N Blade pucks (Cylinders r ρ, 2·hx long) wholly inside the
-- disk, each tangent to its rim on the +x side at α* + j·11.25°, its cap rims' farthest points m under the disk's side:
-- every point of them inside the disk (the truth cleans them), none visible. The build's reading, and D on the build's
-- verdicts against the truth's row and against the design without them.
--   lune run puck_sword -- <rho> <hx> <m> <grow> <n> <alpha*> [R] [len]
local process = require("@lune/process")
local L = require("./lib")
local fmt = string.format
local rho, hx, m, GROW, N, A0 = tonumber(process.args[1]) or 0.1, tonumber(process.args[2]) or 0.05, tonumber(process.args[3]) or 1e-4,
	tonumber(process.args[4]) or 0.8, tonumber(process.args[5]) or 10, tonumber(process.args[6]) or 30
local R, LEN = tonumber(process.args[7]) or 0.8, tonumber(process.args[8]) or 0.5

local parts = L.repoFixture("F5")
local GC = { 0, 1.29, 0 }
parts[3] = L.part("Guard", "Cylinder", GC, L.Y90, { LEN, 2 * R, 2 * R })
parts[4].size[2] += GROW
parts[4].pos[2] += GROW / 2
parts[5].pos[2] += GROW
local base = L.copyParts(parts)
for j = 0, N - 1 do
	local a = math.rad(A0 + j * 11.25)
	local rx, ry = math.sin(a), math.cos(a)
	local y0 = math.sqrt((R - m) ^ 2 - hx * hx) - rho
	table.insert(parts, L.part("Blade", "Cylinder", { GC[1] + y0 * rx, GC[2] + y0 * ry, GC[3] },
		L.axisAngle(0, 0, 1, math.deg(math.atan2(-rx, ry))), { 2 * hx, 2 * rho, 2 * rho }))
end
L.renumber(parts)
local draft = L.Canonical.draft({ schema = 1, name = "pucks", type = "Sword", parts = L.copyParts(parts) })
parts = draft.value.parts
local Rr = L.run(L.copyParts(parts), { measureInvalid = false })
print("canonical", draft.ok, "valid:", Rr.validation.ok, L.codes(Rr))
local P = L.prep(parts)
local reads = L.readAll(P)
local truth = L.truthAll(P)
local kept = L.Sampling.exposure(P).kept
local nk = 0
for i = 1, #parts do
	if i <= 5 or i == 6 then
		print(fmt("%2d %-6s %-8s reads %8s (%s), truth %8s (%s)", i, parts[i].slot, parts[i].shape, L.pct(reads[i]),
			if kept[i] then "kept" else "cleaned", L.pct(truth[i]), if truth[i] and truth[i] >= 0.02 then "kept" else "cleaned"))
	end
	if i > 5 and kept[i] then
		nk += 1
	end
end
local worstTruth = 0
for i = 6, #parts do
	worstTruth = math.max(worstTruth, truth[i] or 0)
end
print(fmt("pucks: %d of %d kept by the build; the truth's largest share among them %.4f%%", nk, #parts - 5, 100 * worstTruth))
L.renumber(base)
print("D without the pucks:", L.dline(L.emu(base, nil)))
local Db, Dt = L.emu(L.copyParts(parts), nil), L.emu(L.copyParts(parts), L.truthRow(truth))
print("D build:            ", L.dline(Db))
print("D truth's row:      ", L.dline(Dt))
local w, tier, step = L.dDiff(Db, Dt)
print(fmt("|dD| %.4f on %s, tier flip %s", w, step, tostring(tier)))
print(require("@lune/serde").encode("json", parts))
