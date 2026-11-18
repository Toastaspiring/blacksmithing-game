--!nocheck
-- P1 and the spun copies: new reading (full share), old verdict, new verdict, truth.
local L = require("./lib")
local H = require("./repo/tests/Physics/PhysicsHelpers")
local fmt = string.format

local function report(name, parts)
	local P = L.prep(parts)
	local share, kept, tests = L.newShares(P)
	local nv = L.newVerdict(parts)
	local ov = L.oldVerdict(parts)
	local tr = L.truth(P)
	print("== " .. name)
	for i = 1, #parts do
		local flag = ""
		if tr[i] and ((tr[i] >= 0.02) ~= nv[i]) then flag = " <- new disagrees with truth" end
		print(fmt("  %2d %-11s id %2d  new %9s %-7s old %-7s truth %9s tests %d%s", i, parts[i].shape, parts[i].id, L.pct(share[i]),
			if nv[i] then "kept" else "CLEANED", if ov[i] then "kept" else "CLEANED", L.pct(tr[i]), tests[i], flag))
		assert(nv[i] == kept[i], "lib's reading disagrees with Sampling.exposure")
	end
end

report("P1", H.p1().parts)

local cylinder = H.solid(1, "Cylinder", { 0, 2, 0 }, H.Z90, { 0.6, 0.24, 0.24 })
local spin = L.Quat.hemisphere(L.Quat.mul(H.Z90, H.axisAngle(1, 0, 0, 37)))
report("cylinder spun 37", { cylinder, H.solid(2, "Cylinder", { 0, 2, 0 }, spin, { 0.6, 0.24, 0.24 }) })
local ball = H.solid(1, "Ball", { 0, 2, 0 }, H.I, { 0.3, 0.3, 0.3 })
local turned = H.solid(2, "Ball", { 0, 2, 0 }, H.axisAngle(1, 2, 3, 77), { 0.3, 0.3, 0.3 })
report("ball turned 77", { ball, turned })

print("---- canonical model")
local canon = function(P) return L.Cover.model(P, { canon = true }) end
local fine = function(P) return L.Cover.model(P, { canon = true, sag = 0.002 }) end
for _, pair in ipairs({ { "cylinder spun 37", { cylinder, H.solid(2, "Cylinder", { 0, 2, 0 }, spin, { 0.6, 0.24, 0.24 }) } }, { "ball turned 77", { ball, turned } } }) do
	for _, v in ipairs({ { "canon", canon }, { "fine", fine } }) do
		local P = L.prep(pair[2])
		local share, kept, tests = L.newShares(P, v[2])
		print(pair[1], v[1], L.pct(share[1]), L.pct(share[2]), tests[1], tests[2])
	end
end
