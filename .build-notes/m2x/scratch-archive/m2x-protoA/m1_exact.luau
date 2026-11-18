--!nocheck
-- M1: Cover.shown against an independent computation on the same polyhedral model (Cover.model). Pieces: each facet clipped in 3D
-- by every hider's moved half-spaces (no box test, no shortcut, its own Sutherland-Hodgman), projected to the facet's plane;
-- union area by vertical slabs (every vertex x and every pairwise edge crossing is an event; between events the union's
-- cross-section is linear, so the midpoint rule is exact). Optional: a rank-1 lattice on each facet with the point test.
-- args: set [lattice points per facet, 0 = none] [max parts per design]
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local S = require("./sets")
local L = require("./lib")
local Geo = require("./repo/src/shared/Definitions/Balance").Geometry
local fmt = string.format
local EPS, DELTA = Geo.EPS_GEOM, Geo.HIDE_OFFSET

local which = process.args[1] or "fixtures"
local LAT = tonumber(process.args[2] or "0")
local modelName = process.args[3] or "base"
local MODELS = {
	base = function(P) return L.Cover.model(P) end,
	canon = function(P) return L.Cover.model(P, { canon = true }) end,
	fine = function(P) return L.Cover.model(P, { canon = true, sag = 0.002 }) end,
}
local mf = MODELS[modelName]

-- 3D clip of a flat polygon to n·x ≤ d
local function clip3(poly, nx, ny, nz, d)
	local out = {}
	local m = #poly / 3
	for i = 0, m - 1 do
		local j = (i + 1) % m
		local ax, ay, az = poly[3 * i + 1], poly[3 * i + 2], poly[3 * i + 3]
		local bx, by, bz = poly[3 * j + 1], poly[3 * j + 2], poly[3 * j + 3]
		local da = nx * ax + ny * ay + nz * az - d
		local db = nx * bx + ny * by + nz * bz - d
		if da <= 0 then
			table.insert(out, ax); table.insert(out, ay); table.insert(out, az)
		end
		if (da < 0 and db > 0) or (da > 0 and db < 0) then
			local t = da / (da - db)
			table.insert(out, ax + t * (bx - ax)); table.insert(out, ay + t * (by - ay)); table.insert(out, az + t * (bz - az))
		end
	end
	if #out < 9 then return nil end
	return out
end

-- union area of 2D convex polygons (flat u, v), by slabs in u
local function unionArea(polys)
	if #polys == 0 then return 0 end
	local xs = {}
	local edges = {}
	for _, p in ipairs(polys) do
		local n = #p / 2
		for i = 0, n - 1 do
			local j = (i + 1) % n
			local u0, v0, u1, v1 = p[2 * i + 1], p[2 * i + 2], p[2 * j + 1], p[2 * j + 2]
			table.insert(xs, u0)
			if u0 ~= u1 then table.insert(edges, { u0, v0, u1, v1 }) end
		end
	end
	-- pairwise crossings
	for a = 1, #edges do
		local e = edges[a]
		for b = a + 1, #edges do
			local g = edges[b]
			local x1, y1, x2, y2 = e[1], e[2], e[3], e[4]
			local x3, y3, x4, y4 = g[1], g[2], g[3], g[4]
			local den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
			if den ~= 0 then
				local t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den
				local s = ((x1 - x3) * (y1 - y2) - (y1 - y3) * (x1 - x2)) / den
				if t > 0 and t < 1 and s > 0 and s < 1 then
					table.insert(xs, x1 + t * (x2 - x1))
				end
			end
		end
	end
	table.sort(xs)
	local area = 0
	local spans = {}
	for k = 1, #xs - 1 do
		local a, b = xs[k], xs[k + 1]
		if b > a then
			local xm = (a + b) / 2
			-- cross-section of each convex polygon at u = xm
			local ns = 0
			for _, p in ipairs(polys) do
				local n = #p / 2
				local lo, hi = math.huge, -math.huge
				for i = 0, n - 1 do
					local j = (i + 1) % n
					local u0, v0, u1, v1 = p[2 * i + 1], p[2 * i + 2], p[2 * j + 1], p[2 * j + 2]
					if (u0 <= xm and u1 >= xm) or (u1 <= xm and u0 >= xm) then
						if u0 ~= u1 then
							local v = v0 + (xm - u0) / (u1 - u0) * (v1 - v0)
							if v < lo then lo = v end
							if v > hi then hi = v end
						end
					end
				end
				if hi > lo then
					ns += 1
					spans[ns] = { lo, hi }
				end
			end
			for i = ns + 1, #spans do spans[i] = nil end
			table.sort(spans, function(p, q) return p[1] < q[1] end)
			local len, clo, chi = 0, -math.huge, -math.huge
			for i = 1, ns do
				local s = spans[i]
				if s[1] > chi then
					if chi > clo then len += chi - clo end
					clo, chi = s[1], s[2]
				elseif s[2] > chi then
					chi = s[2]
				end
			end
			if chi > clo then len += chi - clo end
			area += len * (b - a)
		end
	end
	return area
end

local GOLD = 0.6180339887498949

-- the independent reading of part i: full shown share on model i, and the lattice share (or false)
local function independent(P, models, i, rank, byRank, hider)
	local pm = models[i]
	local cand, higher = {}, {}
	for r = 1, #P do
		local q = byRank[r]
		local j = q.index
		if j ~= i and hider[j] then
			table.insert(cand, models[j])
			table.insert(higher, r < rank[i])
		end
	end
	local shown, latShown = 0, 0
	local maxPieces = 0
	for f = 1, pm.n do
		local poly = pm.poly[f]
		local nx, ny, nz = pm.nx[f], pm.ny[f], pm.nz[f]
		local nv = #poly / 3
		local cx, cy, cz = 0, 0, 0
		for k = 0, nv - 1 do cx += poly[3 * k + 1]; cy += poly[3 * k + 2]; cz += poly[3 * k + 3] end
		cx, cy, cz = cx / nv, cy / nv, cz / nv
		local ex, ey, ez = poly[4] - poly[1], poly[5] - poly[2], poly[6] - poly[3]
		local el = math.sqrt(ex * ex + ey * ey + ez * ez)
		ex, ey, ez = ex / el, ey / el, ez / el
		local gx, gy, gz = ny * ez - nz * ey, nz * ex - nx * ez, nx * ey - ny * ex
		local function to2(p3)
			local out = {}
			for k = 0, #p3 / 3 - 1 do
				local dx, dy, dz = p3[3 * k + 1] - cx, p3[3 * k + 2] - cy, p3[3 * k + 3] - cz
				out[2 * k + 1] = dx * ex + dy * ey + dz * ez
				out[2 * k + 2] = dx * gx + dy * gy + dz * gz
			end
			return out
		end
		local pieces = {}
		local planesets = {}
		for k, q in ipairs(cand) do
			local pl = q.planes
			local cA = if higher[k] then EPS else -EPS
			local A, B = poly, poly
			for m = 1, q.np do
				local px, py, pz, d = pl[4 * m - 3], pl[4 * m - 2], pl[4 * m - 1], pl[4 * m]
				if A then A = clip3(A, px, py, pz, d + cA) end
				if B then B = clip3(B, px, py, pz, d + EPS - DELTA * (px * nx + py * ny + pz * nz)) end
			end
			if A then table.insert(pieces, to2(A)) end
			if B then table.insert(pieces, to2(B)) end
			table.insert(planesets, { q = q, cA = cA })
		end
		if #pieces > maxPieces then maxPieces = #pieces end
		local f2 = to2(poly)
		local fa = 0
		for k = 0, nv - 1 do
			local j = (k + 1) % nv
			fa += f2[2 * k + 1] * f2[2 * j + 2] - f2[2 * j + 1] * f2[2 * k + 2]
		end
		fa = fa / 2
		local u = unionArea(pieces)
		shown += math.max(0, fa - u)
		if LAT > 0 then
			-- rank-1 lattice on the fan triangles, the point test with the half-spaces themselves
			local vis, tot = 0, 0
			for t = 1, nv - 2 do
				local ax, ay, az = poly[1], poly[2], poly[3]
				local bx, by, bz = poly[3 * t + 1], poly[3 * t + 2], poly[3 * t + 3]
				local qx, qy, qz = poly[3 * t + 4], poly[3 * t + 5], poly[3 * t + 6]
				local ux, uy, uz = bx - ax, by - ay, bz - az
				local wx, wy, wz = qx - ax, qy - ay, qz - az
				local cxx, cyy, czz = uy * wz - uz * wy, uz * wx - ux * wz, ux * wy - uy * wx
				local ta = math.sqrt(cxx * cxx + cyy * cyy + czz * czz) / 2
				local n = math.max(16, math.ceil(LAT * ta / pm.total))
				local shows = 0
				for s = 0, n - 1 do
					local a, b = (s + 0.5) / n, (s * GOLD + 0.5) % 1
					if a + b > 1 then a, b = 1 - a, 1 - b end
					local x, y, z = ax + a * ux + b * wx, ay + a * uy + b * wy, az + a * uz + b * wz
					local hidden = false
					for _, ps in ipairs(planesets) do
						local q = ps.q
						local pl = q.planes
						local inA, inB = true, true
						for m = 1, q.np do
							local px, py, pz, d = pl[4 * m - 3], pl[4 * m - 2], pl[4 * m - 1], pl[4 * m]
							local s0 = px * x + py * y + pz * z - d
							if s0 > ps.cA then inA = false end
							if s0 + DELTA * (px * nx + py * ny + pz * nz) > EPS then inB = false end
							if not inA and not inB then break end
						end
						if inA or inB then hidden = true break end
					end
					if not hidden then shows += 1 end
				end
				vis += ta * shows / n
			end
			latShown += vis
		end
	end
	return shown / pm.total, if LAT > 0 then latShown / pm.total else false, maxPieces
end

local designs = {}
local function add(list) for _, d in ipairs(list) do table.insert(designs, d) end end
if which == "fixtures" then add(S.repoF()); add(S.protoFixtures())
elseif which == "worst" then add(S.worstP()); add(S.attacksJson())
elseif string.sub(which, 1, 6) == "jsonl:" then add(S.jsonl(string.sub(which, 7)))
end
local stride = tonumber(process.args[4] or "1")
local maxParts = tonumber(process.args[5] or "24")

local worst, worstLat, nParts, nDesigns = 0, 0, 0, 0
local worstName, worstLatName = "", ""
local t0 = os.clock()
for di, d in ipairs(designs) do
	if (di - 1) % stride == 0 and #d.parts <= maxParts then
		local P = L.prep(d.parts)
		local rank, byRank, isCopy, dust, hider = L.flags(P)
		local models = {}
		for i = 1, #P do if hider[i] then models[i] = mf(P[i]) end end
		local share = L.newShares(P, mf)
		nDesigns += 1
		for i = 1, #P do
			if hider[i] then
				local s, lat, mp = independent(P, models, i, rank, byRank, hider)
				local diff = math.abs(s - share[i])
				nParts += 1
				if diff > worst then worst, worstName = diff, fmt("%s part %d (%s): cover %.12f slabs %.12f", d.name, i, d.parts[i].shape, share[i], s) end
				if lat then
					local dl = math.abs(lat - share[i])
					if dl > worstLat then worstLat, worstLatName = dl, fmt("%s part %d (%s): cover %.6f lattice %.6f", d.name, i, d.parts[i].shape, share[i], lat) end
				end
			end
		end
	end
end
print(fmt("M1 %s model %s: %d designs, %d parts, %.1f s", which, modelName, nDesigns, nParts, os.clock() - t0))
print(fmt("  largest |cover - slabs| share: %.3e   %s", worst, worstName))
if LAT > 0 then print(fmt("  largest |cover - lattice| share: %.3e   %s", worstLat, worstLatName)) end
