--!nocheck
-- M3, the model's own channel: a rod (true Cylinder) in a closed tube of N flat walls whose inner faces stand g from the true rod,
-- and a ball in a closed box of 6 walls standing g from the true ball. Near g = HIDE_OFFSET the truth hides the filler while the
-- inscribed polygon model reads part of it as showing (its surface lies up to the sagitta deeper). Through the M3 emulator
-- (analyze_build): K (the walls, a hilt) against K + F, and the reading's verdict against the truth's, on each model.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local L = require("./lib")
local fmt = string.format
local Quat = L.Quat

local MODELS = { base = { "./v/force_base/Sampling", "./proto_base/analyze_build" }, canon = { "./v/force_canon/Sampling", "./proto_canon/analyze_build" }, fine = { "./v/force_fine/Sampling", "./proto_fine/analyze_build" } }
local Z90 = { 0, 0, 0.70710678118654757, 0.70710678118654757 }

local function hilt(gw, gz)
	return {
		L.part(1, "Ball", "Pommel", { 0, 0.30, 0 }, L.I, { 0.30, 0.30, 0.30 }),
		L.part(2, "Cylinder", "Grip", { 0, 0.88, 0 }, Z90, { 0.90, 0.16, 0.16 }),
		L.part(3, "Block", "Guard", { 0, 1.40, 0 }, L.I, { gw, 0.16, gz }),
	}
end

-- a closed tube of n walls round the Y axis, inner faces at distance a, thickness t, from y0 to y1; slots Blade then Guard
local function tube(parts, n, a, t, y0, y1)
	local w = 2 * a * math.tan(math.pi / n) + 2 * t * math.tan(math.pi / n) + 0.002 -- adjacent walls overlap at the corners
	local slots = { "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Blade", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard", "Guard" }
	for k = 0, n - 1 do
		local ang = 2 * math.pi * k / n
		local cx, cz = (a + t / 2) * math.sin(ang), (a + t / 2) * math.cos(ang)
		local q = L.axisAngle(0, 1, 0, math.deg(ang))
		table.insert(parts, L.part(#parts + 1, "Block", slots[k + 1], { cx, (y0 + y1) / 2, cz }, q, { w, y1 - y0, t }))
	end
end

local function emu(Emu, Force, parts, row)
	Force.FORCE.kept = row
	local ok, R = pcall(Emu.run, { name = "x", parts = parts }, { measureInvalid = true, build = true })
	Force.FORCE.kept = nil
	return if ok then R else nil
end
local function dline(R)
	if not R or not R.steps then return "-" end
	local t = {}
	for _, s in ipairs(R.steps) do table.insert(t, fmt("%s %.4f %s", string.sub(s.step, 1, 2), s.d, string.sub(s.tier, 1, 1))) end
	return table.concat(t, ", ")
end
local function dDiff(a, b)
	if not a or not b or not a.steps or not b.steps then return -1, false end
	local w, tier = 0, false
	for i, s in ipairs(a.steps) do
		w = math.max(w, math.abs(s.d - b.steps[i].d))
		tier = tier or s.tier ~= b.steps[i].tier
	end
	return w, tier
end

local rows = {}
local function case(name, K, F)
	local KF = {}
	for _, p in ipairs(K) do table.insert(KF, p) end
	F.id = #KF + 1
	table.insert(KF, F)
	local P = L.prep(KF)
	local f = #KF
	local tr = L.truth(P)
	local okV = L.Sampling.exposure(P) and true
	local core = { schema = 1, name = "x", type = "Sword", parts = KF }
	local valid = L.Sampling and require("./repo/src/shared/Physics/Analyze").run(core, { measureInvalid = true }).validation.ok
	local truthRow = {}
	for i = 1, #KF do truthRow[i] = tr[i] ~= false and tr[i] >= 0.02 end
	local line = fmt("%s [%d parts, %s]: filler true %.3f %%", name, #KF, if valid then "valid" else "INVALID", (tr[f] or 0) * 100)
	for _, m in ipairs({ "base", "canon", "fine" }) do
		local Force, Emu = require(MODELS[m][1]), require(MODELS[m][2])
		local share = L.newShares(P, function(Pp) return L.Cover.model(Pp, ({ base = nil, canon = { canon = true }, fine = { canon = true, sag = 0.002 } })[m]) end)
		local RK = emu(Emu, Force, K, nil)
		local RKF = emu(Emu, Force, KF, nil)
		local RT = emu(Emu, Force, KF, truthRow)
		local w1, t1 = dDiff(RK, RKF)
		local w2, t2 = dDiff(RKF, RT)
		line ..= fmt("\n   %-5s read %.3f %% %s | K vs K+F |dD| %.4f%s | reading vs truth |dD| %.4f%s", m, share[f] * 100, if share[f] >= 0.02 then "kept" else "CLEANED", w1, if t1 then " TIER" else "", w2, if t2 then " TIER" else "")
		table.insert(rows, { name = name, model = m, truth = tr[f], read = share[f], dKF = w1, tierKF = t1, dVT = w2, tierVT = t2, valid = valid, parts = KF })
	end
	print(line)
end

for _, def in ipairs({ { 0.2, 16, { 0.0068, 0.0070, 0.0072, 0.0074, 0.0076, 0.0078, 0.0079 } }, { 0.1, 16, { 0.0092, 0.0094, 0.0096, 0.0098 } }, { 0.2, 12, { 0.0032, 0.0034, 0.0036, 0.0038, 0.0040 } } }) do
	local r, n = def[1], def[2]
	for _, g in ipairs(def[3]) do
		local K = hilt(2 * (r + g + 0.03) + 0.1, math.min(0.58, 2 * (r + g + 0.03) + 0.05))
		tube(K, n, r + g, 0.03, 1.48, 4.2)
		table.insert(K, L.part(#K + 1, "Block", "Pommel", { 0, 4.215, 0 }, L.I, { 2 * (r + g + 0.04), 0.03, math.min(0.58, 2 * (r + g + 0.04)) }))
		for _, spin in ipairs({ 0, 5.625 }) do
			local q = Quat.hemisphere(Quat.normalize(Quat.mul(L.axisAngle(0, 1, 0, spin), Z90)))
			local rod = L.part(0, "Cylinder", "Grip", { 0, 2.84, 0 }, q, { 2.7, 2 * r, 2 * r })
			case(fmt("rod r %.2f in %d walls, gap %.4f, spun %.3f", r, n, g, spin), K, rod)
		end
	end
end
fs.writeFile("out/m3_tube_fine.json", serde.encode("json", rows))
