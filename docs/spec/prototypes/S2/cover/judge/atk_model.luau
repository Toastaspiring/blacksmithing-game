--!nocheck
-- The model's own channel, measured on A's reading (baseline, canonical, fine) against the truth, in valid swords (C02):
--   ballInGrip   a Ball of radius R − g inside C02's Cylinder grip (radius R = 0.08): truly buried (0 %); the grip's model
--                is an inscribed 32-gon, so for g under its sagitta the ball's model pokes through and shows
--   rodInTube    a rod sealed in 16 flat walls (a tube) at gap g, turned 5.625° about its axis so no model lines up: the
--                truth hides it all when the walls' corners are within HIDE_OFFSET; the model's facets sit a sagitta deeper
--   T-PHY-09     a Cylinder spun 37° about its axis and a Ball turned 77°, exact geometric copies of the original
-- Each row: the part's share by the truth and by each reading, the verdicts, and |dD| (M3) of A's row against the truth's.
local process = require("@lune/process")
local fs = require("@lune/fs")
local L = require("./jlib")
local M3 = require("./m3j")
local Fx = require("./repo/docs/spec/prototypes/S2/v2/fixtures")
local fmt = string.format
local I = L.I
local Z90 = { 0, 0, 0.70710678118654757, 0.70710678118654757 }

local which = process.args[1] or "all"
local saved = {}

local function c02()
	local b = Fx.calibration()[2]
	local out = {}
	for i, p in ipairs(b.parts) do
		out[i] = { id = i, label = p.label, shape = p.shape, slot = p.slot, material = p.material, pos = { p.pos[1], p.pos[2], p.pos[3] },
			rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] }, size = { p.size[1], p.size[2], p.size[3] } }
	end
	return out
end

local function c01()
	return {
		{ id = 1, label = "Pommel", shape = "Block", slot = "Pommel", material = "Iron", pos = { 0, 0.35, 0 }, rot = I, size = { 0.3, 0.3, 0.3 } },
		{ id = 2, label = "Grip", shape = "Block", slot = "Grip", material = "Iron", pos = { 0, 1, 0 }, rot = I, size = { 0.2, 1, 0.2 } },
		{ id = 3, label = "Guard", shape = "Block", slot = "Guard", material = "Iron", pos = { 0, 1.6, 0 }, rot = I, size = { 1, 0.2, 0.3 } },
		{ id = 4, label = "Blade", shape = "Block", slot = "Blade", material = "Iron", pos = { 0, 2.9, 0 }, rot = I, size = { 0.25, 2.4, 0.1 } },
	}
end

local function report(name, parts, t)
	local ok, why = M3.valid(parts)
	local R = M3.rows(parts)
	local sh = R.shares[t]
	local function v(x) return if x then "K" else "c" end
	local line = fmt("%-44s valid %-5s truth %7.3f%% %s | base %7.3f%% %s | canon %7.3f%% %s | fine %7.3f%% %s | B %7.3f%% | today %s",
		name, tostring(ok), 100 * sh.truth, v(R.truth[t]), 100 * sh.A, v(R.A[t]), 100 * sh.Acanon, v(R.Acanon[t]), 100 * sh.Afine,
		v(R.Afine[t]), 100 * sh.B, v(R.today[t]))
	local extra = ""
	for _, key in ipairs({ "Acanon", "Afine" }) do
		if R[key][t] ~= R.truth[t] and ok then
			local dd, tier = M3.compare(parts, R[key], R.truth)
			if dd then extra ..= fmt("  %s |dD| %.4f%s", key, dd, if tier then " TIER" else "") end
		end
	end
	print(line .. extra)
	table.insert(saved, L.encodeDesign(name, parts))
end

if which == "all" or which == "ballInGrip" then
	print("-- a Ball inside C02's grip (Cylinder radius 0.08), radius 0.08 − g")
	for _, g in ipairs({ 0.002, 0.001, 0.0006, 0.0004, 0.0003, 0.0002, 0.0001, 0.00003, 0.00001 }) do
		local parts = c02()
		local r = 0.08 - g
		table.insert(parts, { id = #parts + 1, label = "Core", shape = "Ball", slot = "Grip", material = "Iron", pos = { 0, 0.88, 0 },
			rot = I, size = { 2 * r, 2 * r, 2 * r } })
		report(fmt("ball in grip g %.5f", g), parts, #parts)
	end
end

if which == "all" or which == "rodInTube" then
	print("-- a rod (radius r) sealed in 16 flat walls at gap g from its surface, turned 5.625° about its axis, beside C02's blade")
	for _, r in ipairs({ 0.1, 0.2 }) do
		for _, gc in ipairs({ 0.0119, 0.0118, 0.0116, 0.0115, 0.0112, 0.0110, 0.0105, 0.0100 }) do
			-- gc: the gap at the walls' corners (what the truth's probes must cross); the wall gap at mid-face follows
			local parts = c01()
			local n = 16
			local rc = r + gc -- the corners' radius
			local rf = rc * 0.98078528040323043 -- the walls' mid-face radius, cos(π/16)
			local len = 1.6
			local th = 0.03
			local cx, cy = 0.125 + rc + th - 0.005, 2.3 -- rod axis along Y, the tube's wall on the blade's +X face
			local turn = 5.625
			table.insert(parts, { id = #parts + 1, label = "Rod", shape = "Cylinder", slot = "Blade", material = "Iron", pos = { cx, cy, 0 },
				rot = Z90, size = { len, 2 * r, 2 * r } })
			local side = 2 * rc * 0.19509032201612825 + 0.004 -- a wall's width: the chord between corners, a little over
			for k = 0, n - 1 do
				local a = math.rad(k * 360 / n + turn)
				local ux, uz = math.cos(a), math.sin(a)
				local d = rf + th / 2
				-- wall: local X across the tube (tangent), Y along the axis, Z through the wall (radial)
				local q = L.axisAngle(0, 1, 0, -(k * 360 / n + turn) + 90)
				table.insert(parts, { id = #parts + 1, label = "Wall", shape = "Block", slot = if k < 10 then "Blade" else "Guard",
					material = "Iron", pos = { cx + d * ux, cy, d * uz }, rot = q, size = { side, len + 0.06, th } })
			end
			-- end caps
			table.insert(parts, { id = #parts + 1, label = "CapTop", shape = "Block", slot = "Guard", material = "Iron",
				pos = { cx, cy + len / 2 + 0.015 + 0.004, 0 }, rot = I, size = { 2 * rc + 0.08, 0.03, 2 * rc + 0.08 } })
			table.insert(parts, { id = #parts + 1, label = "CapBottom", shape = "Block", slot = "Grip", material = "Iron",
				pos = { cx, cy - len / 2 - 0.015 - 0.004, 0 }, rot = I, size = { 2 * rc + 0.08, 0.03, 2 * rc + 0.08 } })
			report(fmt("rod r %.2f in 16 walls, corner gap %.4f", r, gc), parts, 5)
		end
	end
end

if which == "all" or which == "tphy09" then
	print("-- T-PHY-09: geometric copies turned about their own symmetry")
	local spin = L.Quat.hemisphere(L.Quat.mul(Z90, L.axisAngle(1, 0, 0, 37)))
	local p1 = {
		{ id = 1, shape = "Cylinder", slot = "Blade", material = "Iron", pos = { 0, 2, 0 }, rot = Z90, size = { 0.6, 0.24, 0.24 } },
		{ id = 2, shape = "Cylinder", slot = "Blade", material = "Iron", pos = { 0, 2, 0 }, rot = spin, size = { 0.6, 0.24, 0.24 } },
	}
	report("cylinder spun 37 deg (part 2)", p1, 2)
	report("cylinder spun 37 deg (part 1)", p1, 1)
	local p2 = {
		{ id = 1, shape = "Ball", slot = "Blade", material = "Iron", pos = { 0, 2, 0 }, rot = I, size = { 0.3, 0.3, 0.3 } },
		{ id = 2, shape = "Ball", slot = "Blade", material = "Iron", pos = { 0, 2, 0 }, rot = L.axisAngle(1, 2, 3, 77), size = { 0.3, 0.3, 0.3 } },
	}
	report("ball turned 77 deg (part 2)", p2, 2)
	report("ball turned 77 deg (part 1)", p2, 1)
end

fs.writeFile("out/atk_model_" .. which .. ".json", "[\n" .. table.concat(saved, ",\n") .. "\n]\n")
