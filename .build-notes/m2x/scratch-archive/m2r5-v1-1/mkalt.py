#!/usr/bin/env python
"""A variant of the build, with V1's tried fixes, as a whole folder: alt-<name>/tree, force, plain, proto and the harness. args: name [rank] [lines]"""
import os, shutil, sys
HERE = os.path.dirname(os.path.abspath(__file__))
name = sys.argv[1]
opts = set(sys.argv[2:])
ALT = os.path.join(HERE, "alt-" + name)
if os.path.isdir(ALT):
    shutil.rmtree(ALT)
os.makedirs(ALT)
shutil.copytree(os.path.join(HERE, "tree"), os.path.join(ALT, "tree"))
shutil.copytree(os.path.join(HERE, "proto"), os.path.join(ALT, "proto"))
for f in os.listdir(HERE):
    if f.endswith(".luau") or f == "aftman.toml":
        shutil.copy(os.path.join(HERE, f), os.path.join(ALT, f))
os.makedirs(os.path.join(ALT, "out"))

path = os.path.join(ALT, "tree/src/shared/Physics/Sampling.luau")
s = open(path, encoding="utf-8", newline="").read()
nl = "\r\n" if "\r\n" in s else "\n"

def rep(a, b, count=1):
    global s
    a = a.replace("\n", nl)
    b = b.replace("\n", nl)
    assert s.count(a) >= 1 and (count == 0 or s.count(a) == count), (a[:70], s.count(a))
    s = s.replace(a, b)

if "rank" in opts:
    # who keeps a coincident face, and the measure's order: by the parts' geometry, the largest first, never their ids
    rep("""	local subLeft = Geo.N_SUB_WORK
""", """	-- the rank of a part: the larger first, then by where it stands (a total order on the solids: ids play no part)
	local rank: { number } = table.create(N, 0)
	local byRank: { Prepared } = table.create(N)
	for i = 1, N do
		byRank[i] = parts[i]
	end
	table.sort(byRank, function(a: Prepared, b: Prepared): boolean
		if a.volume ~= b.volume then return a.volume > b.volume end
		if a.cy ~= b.cy then return a.cy < b.cy end
		if a.cx ~= b.cx then return a.cx < b.cx end
		if a.cz ~= b.cz then return a.cz < b.cz end
		if a.code ~= b.code then return a.code < b.code end
		if a.hx ~= b.hx then return a.hx < b.hx end
		if a.hy ~= b.hy then return a.hy < b.hy end
		if a.hz ~= b.hz then return a.hz < b.hz end
		if a.ux ~= b.ux then return a.ux < b.ux end
		if a.uy ~= b.uy then return a.uy < b.uy end
		if a.uz ~= b.uz then return a.uz < b.uz end
		if a.vx ~= b.vx then return a.vx < b.vx end
		if a.vy ~= b.vy then return a.vy < b.vy end
		if a.vz ~= b.vz then return a.vz < b.vz end
		return a.index < b.index
	end)
	for r = 1, N do
		rank[byRank[r].index] = r
	end

	local subLeft = Geo.N_SUB_WORK
""")
    rep("if d0 < -eps or (q.index < pIndex and d0 <= eps) then", "if d0 < -eps or (rank[q.index] < rank[pIndex] and d0 <= eps) then")
    rep("local hid = d0 < -eps or (q.index < p.index and d0 <= eps) or d1 <= eps", "local hid = d0 < -eps or (rank[q.index] < rank[p.index] and d0 <= eps) or d1 <= eps")
    rep("local hid = d0 < -eps or (q.index < index and d0 <= eps) or d1 <= eps", "local hid = d0 < -eps or (rank[q.index] < rank[index] and d0 <= eps) or d1 <= eps")
    # the measure's visits in rank order
    rep("""	local exposedKept: { number } = table.create(N, 0)
	for i = 1, N do
		if kept[i] then
			local p = parts[i]
			local S = Sampling.surfaceSamples(p, hSurf, work)""", """	local exposedKept: { number } = table.create(N, 0)
	for r = 1, N do
		local i = byRank[r].index
		if kept[i] then
			local p = parts[i]
			local S = Sampling.surfaceSamples(p, hSurf, work)""")

if "lines" in opts:
    lt = "rank[q.index] < rank[index]" if "rank" in opts else "q.index < index"
    fn = """	-- What shows of a line through a flat patch: its on-surface length, and the part of it no near part hides. A convex part cuts a line in one interval, on the surface
	-- (shrunk by eps; grown by eps where it keeps a coincident face) and on the probe's line (grown by eps): the same tests as hides, in closed form.
	local LO: { number } = {}
	local HI: { number } = {}
	local function lineShown(p: Prepared, nn: number, lx: number, ly: number, lz: number, ux: number, uy: number, uz: number, half: number, nx: number, ny: number,
		nz: number): (number, number)
		local hit, a0, a1 = Shapes.chord(p, lx, ly, lz, ux, uy, uz, eps)
		if not hit then
			return 0, 0
		end
		a0, a1 = max(a0, -half), min(a1, half)
		if a1 <= a0 then
			return 0, 0
		end
		local m = 0
		local index = p.index
		local px, py, pz = lx + delta * nx, ly + delta * ny, lz + delta * nz
		local front = a0 -- hidden from a0 up to here, as far as the parts asked so far show: the same union, found sooner
		for c = 1, nn do
			local q = near[c]
			local useful = false
			local h1, s0, s1 = Shapes.chord(q, px, py, pz, ux, uy, uz, eps)
			if h1 and s1 > a0 and s0 < a1 then
				m += 1
				LO[m], HI[m] = max(s0, a0), min(s1, a1)
				if s0 <= front and s1 > front then
					front = s1
					useful = true
				end
			end
			if front < a1 then
				local h2, s2, s3 = Shapes.chord(q, lx, ly, lz, ux, uy, uz, if LOWER then eps else -eps)
				if h2 and s3 > a0 and s2 < a1 then
					m += 1
					LO[m], HI[m] = max(s2, a0), min(s3, a1)
					if s2 <= front and s3 > front then
						front = s3
						useful = true
					end
				end
			end
			if useful and c > 1 then
				near[c], near[1] = near[1], q
			end
			if front >= a1 then
				return 0, a1 - a0
			end
		end
		-- the union of the intervals, an insertion sort
		for i = 2, m do
			local l, r = LO[i], HI[i]
			local j = i - 1
			while j >= 1 and LO[j] > l do
				LO[j + 1], HI[j + 1] = LO[j], HI[j]
				j -= 1
			end
			LO[j + 1], HI[j + 1] = l, r
		end
		local covered, reach = 0, a0
		for i = 1, m do
			local l, r = LO[i], HI[i]
			if r > reach then
				covered += r - max(l, reach)
				reach = r
			end
		end
		return (a1 - a0) - covered, a1 - a0
	end

	-- A flat patch. Its centre and corners hidden and the 2 lines through its centre covered: nothing long enough to matter shows. Otherwise it is measured on 4 lines each way:
	-- a boundary across a line is read exactly, so of the two ways the one whose lines agree crosses the pattern; if both agree, the way that reads a fraction does.
	local function measuredArea(p: Prepared, nn: number, x: number, y: number, z: number, ox: number, oy: number, oz: number, nx: number, ny: number, nz: number,
		e1x: number, e1y: number, e1z: number, e2x: number, e2y: number, e2z: number, w: number, hiddenNear: boolean): number
		local index = p.index
		local l1, l2 = sqrt(e1x * e1x + e1y * e1y + e1z * e1z), sqrt(e2x * e2x + e2y * e2y + e2z * e2z)
		local u1x, u1y, u1z = e1x / l1, e1y / l1, e1z / l1
		local u2x, u2y, u2z = e2x / l2, e2y / l2, e2z / l2
		if hiddenNear then
			local all = true
			for c = 1, 4 do
				local a, b = CORNERS_A[c] * VERDICT_CORNER, CORNERS_B[c] * VERDICT_CORNER
				local sx, sy, sz = x + a * e1x + b * e2x, y + a * e1y + b * e2y, z + a * e1z + b * e2z
				if not hiddenByNear(index, nn, sx, sy, sz, sx + delta * nx, sy + delta * ny, sz + delta * nz) then
					all = false
					break
				end
			end
			work(4 * nn)
			if all then
				local s1, on1 = lineShown(p, nn, x, y, z, u1x, u1y, u1z, l1, nx, ny, nz)
				if s1 <= 0 then
					local s2, on2 = lineShown(p, nn, x, y, z, u2x, u2y, u2z, l2, nx, ny, nz)
					work(4 * nn)
					if s2 <= 0 then
						return 0
					end
				end
			end
		end
		local shownA, onA, loA, hiA = 0, 0, math.huge, -math.huge
		local shownB, onB, loB, hiB = 0, 0, math.huge, -math.huge
		for i = 1, 4 do
			local c = SUB_GRID[i]
			local s, on = lineShown(p, nn, x + c * e2x, y + c * e2y, z + c * e2z, u1x, u1y, u1z, l1, nx, ny, nz)
			if on > 0 then
				shownA += s
				onA += on
				loA, hiA = min(loA, s / on), max(hiA, s / on)
			end
			s, on = lineShown(p, nn, x + c * e1x, y + c * e1y, z + c * e1z, u2x, u2y, u2z, l2, nx, ny, nz)
			if on > 0 then
				shownB += s
				onB += on
				loB, hiB = min(loB, s / on), max(hiB, s / on)
			end
		end
		work(16 * nn)
		if onA <= 0 and onB <= 0 then
			return if hiddenNear then 0 else w
		end
		local useA
		if onB <= 0 then
			useA = true
		elseif onA <= 0 then
			useA = false
		elseif abs((hiA - loA) - (hiB - loB)) > 1e-6 then
			useA = hiA - loA < hiB - loB
		else
			useA = shownA > 1e-9 * onA and shownA < (1 - 1e-9) * onA
		end
		if useA then
			return w * shownA / onA
		end
		return w * shownB / onB
	end

""".replace("if LOWER then", "if " + lt + " then")
    rep("	-- What the verdict reads at sample k: the area of its patch that shows (§4.4).\n", fn + "	-- What the verdict reads at sample k: the area of its patch that shows (§4.4).\n")
    rep("""		-- the 4 corners against the centre
""", """		if S.flat[k] then
			return measuredArea(p, nn, x, y, z, ox, oy, oz, nx, ny, nz, e1x, e1y, e1z, e2x, e2y, e2z, w, hiddenNear)
		end

		-- the 4 corners against the centre
""")

if "nosearch" in opts:
    # no search for the one part that hides all five: the sub-grid reads the same on a flat patch, hider first
    i0 = s.index("		if uniform and hiddenNear and nn > 1 then")
    i1 = s.index("		if uniform then" + nl + "			return if hiddenNear then 0 else w")
    s = s[:i0] + "		if uniform and hiddenNear and nn > 1 then" + nl + "			uniform = false" + nl + "		end" + nl + s[i1:]

open(path, "w", encoding="utf-8", newline="").write(s)

# force and plain, from the fixed source
f = s
f = f.replace('require("../Definitions/Balance")', 'require("../tree/src/shared/Definitions/Balance")')
f = f.replace('require("../Definitions/Limits")', 'require("../tree/src/shared/Definitions/Limits")')
f = f.replace('require("./Shapes")', 'require("../tree/src/shared/Physics/Shapes")')
marker = "\t-- the measure: the kept parts, against kept parts only"
assert marker in f
patch = nl.join(["\tif Sampling.FORCE.kept then", "\t\tcleaned = {}", "\t\tfor i = 1, N do", "\t\t\tkept[i] = Sampling.FORCE.kept[i]", "\t\t\tif not kept[i] then",
                 "\t\t\t\ttable.insert(cleaned, { partId = parts[i].id, reason = \"Enclosed\" :: CleanReason })", "\t\t\tend", "\t\tend", "\tend", "", ""])
f = f.replace(marker, patch + marker)
f = f.replace("local Sampling = {}" + nl, "local Sampling = {}" + nl + "Sampling.FORCE = {} :: any" + nl, 1)
a = "\t\t\t\tif visible >= need then" + nl + "\t\t\t\t\tbreak" + nl + "\t\t\t\tend"
assert a in f
f = f.replace(a, "\t\t\t\tif visible >= need and not Sampling.FORCE.fullRead then" + nl + "\t\t\t\t\tbreak" + nl + "\t\t\t\tend")
a = "\t\t\tif visible >= need then" + nl + "\t\t\t\tkept[i] = true"
assert a in f
f = f.replace(a, "\t\t\tif Sampling.FORCE.read then Sampling.FORCE.read[i] = visible / p.area end" + nl + a)
os.makedirs(os.path.join(ALT, "force"))
open(os.path.join(ALT, "force/Sampling.luau"), "w", encoding="utf-8", newline="").write(f)
g = f.replace(marker, "\tif Sampling.FORCE.verdictOnly then" + nl + "\t\treturn { kept = kept, cleaned = cleaned }" + nl + "\tend" + nl + marker)
os.makedirs(os.path.join(ALT, "plain"))
open(os.path.join(ALT, "plain/Sampling.luau"), "w", encoding="utf-8", newline="").write(g)
c = g
a = "local sd, sdLocal, toWorld, aabbContains, aabbOverlap =" + nl + "\tShapes.sd, Shapes.sdLocal, Shapes.toWorld, Shapes.aabbContains, Shapes.aabbOverlap"
assert a in c
c = c.replace(a, nl.join(["local COUNT = { sd = 0, aabb = 0 }", "local sdRaw, aabbRaw = Shapes.sd, Shapes.aabbContains", "local function sd(q, x, y, z) COUNT.sd += 1 return sdRaw(q, x, y, z) end",
                          "local function aabbContains(q, x, y, z, m) COUNT.aabb += 1 return aabbRaw(q, x, y, z, m) end", "local sdLocal, toWorld, aabbOverlap = Shapes.sdLocal, Shapes.toWorld, Shapes.aabbOverlap"]))
c = c.replace("Sampling.FORCE = {} :: any" + nl, "Sampling.FORCE = {} :: any" + nl + "Sampling.COUNT = COUNT" + nl)
os.makedirs(os.path.join(ALT, "count"))
open(os.path.join(ALT, "count/Sampling.luau"), "w", encoding="utf-8", newline="").write(c)
print("built", ALT, sorted(opts))
