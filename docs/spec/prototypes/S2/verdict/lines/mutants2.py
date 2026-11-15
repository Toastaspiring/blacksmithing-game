#!/usr/bin/env python
"""Mutants of the verdict's reading, the rank and what hangs on them: (old, new, why[, file]); old must occur exactly once. Runs the Physics suites on each, in copies of the repo.
args: out.jsonl workers [only indices, comma separated | -] [stages: physics,slow]"""
import os, sys, json, shutil, subprocess, threading, queue, time, re

S = "src/shared/Physics/Sampling.luau"
M_ = "src/shared/Physics/MassProps.luau"
SH = "src/shared/Physics/Shapes.luau"
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
REPO = r"C:\Users\louis\Documents\RANDOM\ROBLOX\Blacksmithing Game"
WORK = os.path.join(ROOT, "mutw")
LUNE = r"C:/Users/louis/.aftman/bin/lune.exe"

M = []
def m(old, new, why, f=S):
    M.append(dict(file=f, old=old, new=new, why=why))

# --- ranked
m("keys[p.index] = { -p.volume, p.cy,", "keys[p.index] = { p.volume, p.cy,", "the smaller first")
m("keys[p.index] = { -p.volume, p.cy,", "keys[p.index] = { 0, p.cy,", "no volume in the rank")
m("{ -p.volume, p.cy, abs(p.cx), p.cx,", "{ -p.volume, abs(p.cx), p.cx,", "no cy")
m("{ -p.volume, p.cy, abs(p.cx), p.cx,", "{ -p.volume, p.cy, p.cx,", "no |cx|")
m("abs(p.cx), p.cx, p.cz, p.hx,", "abs(p.cx), p.cz, p.hx,", "no cx: twins fall to the index")
m("abs(p.cx), p.cx, p.cz, p.hx,", "abs(p.cx), p.cx, p.hx,", "no cz")
m("p.cz, p.hx, p.hy, p.hz, p.ux,", "p.cz, p.ux,", "no half extents")
m("p.hz, p.ux, p.uy, p.uz, p.vx, p.vy, p.vz }", "p.hz }", "no turn")
m("""		if a.slot ~= b.slot then
			return a.slot < b.slot
		end
""", "", "no slot in the rank")
m("""			return a.slot < b.slot
""", """			return a.slot > b.slot
""", "the slot's name reversed")
m("""		if a.material ~= b.material then
			return a.material < b.material
		end
""", "", "no material in the rank")
m("""		return a.index < b.index
	end)
	local rank: { number } = table.create(N, 0)""", """		return a.index > b.index
	end)
	local rank: { number } = table.create(N, 0)""", "the higher index first among equals")
# --- copies
m("isCopy[byRank[r].index] = Shapes.sameSolid(byRank[r], byRank[r - 1])", "isCopy[byRank[r].index] = false", "no copies")
m("isCopy[byRank[r].index] = Shapes.sameSolid(byRank[r], byRank[r - 1])", "isCopy[byRank[r - 1].index] = Shapes.sameSolid(byRank[r], byRank[r - 1])", "the higher rank is the copy")
m("	for r = 2, N do\n		isCopy", "	for r = 3, N do\n		isCopy", "the second never a copy")
# --- rank in the hide tests
m("if d0 < -eps or (rank[q.index] < rank[pIndex] and d0 <= eps) then", "if d0 < -eps or (q.index < pIndex and d0 <= eps) then", "hides by index")
m("local hid = d0 < -eps or (rank[q.index] < rank[p.index] and d0 <= eps) or d1 <= eps", "local hid = d0 < -eps or (q.index < p.index and d0 <= eps) or d1 <= eps", "the measure by index")
m("local hid = d0 < -eps or (rank[q.index] < rank[index] and d0 <= eps) or d1 <= eps", "local hid = d0 < -eps or (q.index < index and d0 <= eps) or d1 <= eps", "the verdict's centre by index")
m("if rank[qi] < pRank then eps else -eps", "if qi < p.index then eps else -eps", "a line's surface by index")
m("if rank[qi] < pRank then eps else -eps", "eps", "a line's surface always grown")
m("if rank[qi] < pRank then eps else -eps", "-eps", "a line's surface always shrunk")
# --- the measure's order
m("""	for r = 1, N do
		local i = byRank[r].index
		if kept[i] then""", """	for r = 1, N do
		local i = r
		if kept[i] then""", "the measure in part order")
m("return ranked[a.index] < ranked[b.index]", "return a.index < b.index", "ownership by index", M_)
# --- lineShown
m("if p.code ~= BLOCK then -- past the rim", "if false then -- past the rim", "no rim: a triangle's lines count past it")
m("if p.code ~= BLOCK then -- past the rim", "if true then -- past the rim", "a Block's lines clipped too (cost only)")
m("a0, a1 = max(t0, a0), min(t1, a1)", "a0, a1 = t0, t1", "the line's length not limited to the patch")
m("a0, a1 = max(t0, a0), min(t1, a1)", "a0, a1 = max(t0, a0), a1", "limited at one end only")
m("""			if a1 <= a0 then
				return 0, 0
			end""", "", "a line that misses the patch's part of the face still counts")
m("local hit, t0, t1 = Shapes.chord(p, lx, ly, lz, ux, uy, uz, eps)", "local hit, t0, t1 = Shapes.chord(p, lx, ly, lz, ux, uy, uz, 0)", "on p's face undilated")
m("if reachesProbe[qi] then", "if true then", "the probe's reach ignored (cost only)")
m("if reachesProbe[qi] then", "if false then", "no probe on the lines")
m("if reachesSurface[qi] and front < a1 then", "if front < a1 then", "the surface's reach ignored (cost only)")
m("if reachesSurface[qi] and front < a1 then", "if reachesSurface[qi] then", "no early stop before the surface (cost only)")
m("if reachesSurface[qi] and front < a1 then", "if false then", "no surface on the lines")
m("oz + frames[f + 12], vx, vy, vz, eps)", "oz + frames[f + 12], vx, vy, vz, 0)", "the probe's line undilated")
m("ox + frames[f + 10], oy + frames[f + 11], oz + frames[f + 12]", "ox, oy, oz", "the probe at the surface")
m("local ox = frames[f + 1] + off * frames[f + across + 1]", "local ox = frames[f + 1]", "a line not offset in x")
m("local oy = frames[f + 2] + off * frames[f + across + 2]", "local oy = frames[f + 2]", "a line not offset in y")
m("local oz = frames[f + 3] + off * frames[f + across + 3]", "local oz = frames[f + 3]", "a line not offset in z")
m("""				local hit, s0, s1 = chordLocal(q, ox + frames[f + 10], oy + frames[f + 11], oz + frames[f + 12], vx, vy, vz, eps)
				if hit and s1 > a0 and s0 < a1 then""", """				local hit, s0, s1 = chordLocal(q, ox + frames[f + 10], oy + frames[f + 11], oz + frames[f + 12], vx, vy, vz, eps)
				if hit then""", "a probe's span off the line's end kept")
m("""				local hit, s0, s1 = chordLocal(q, ox, oy, oz, vx, vy, vz, if rank[qi] < pRank then eps else -eps)
				if hit and s1 > a0 and s0 < a1 then""", """				local hit, s0, s1 = chordLocal(q, ox, oy, oz, vx, vy, vz, if rank[qi] < pRank then eps else -eps)
				if hit then""", "a surface span off the line's end kept")
m("""			if moved and m > 1 then
				near[m], near[1] = near[1], q
			end""", "", "no part moved up (cost only)")
m("""			if front >= a1 then
				work(2 * chords)
				return 0, a1 - a0
			end""", "", "no early end (cost only)")
m("return 0, a1 - a0", "return 0, 0", "a covered line stands on nothing")
m("		work(2 * chords)\n		for i = 2, spans do", "		for i = 2, spans do", "no spend after a line that shows")
m("				work(2 * chords)\n				return 0, a1 - a0", "				return 0, a1 - a0", "no spend after a covered line")
m("while j >= 1 and spanLo[j] > lo do", "while false do", "the spans unsorted")
m("""			elseif spanHi[i] > hi then
				hi = spanHi[i]""", """			else
				hi = spanHi[i]""", "a span inside the run shortens it")
m("""				hidden += hi - lo
				lo, hi = spanLo[i], spanHi[i]""", """				lo, hi = spanLo[i], spanHi[i]""", "only the last run counted")
m("return (a1 - a0) - (hidden + hi - lo), a1 - a0", "return (a1 - a0) - hidden, a1 - a0", "the last run not counted")
m("return (a1 - a0) - (hidden + hi - lo), a1 - a0", "return (a1 - a0) - (hidden + hi - lo), 2 * half", "the whole line's length, on or off the face")
# --- flatShown: the one part
m("		for m = 1, nh do\n			local q = near[m]\n			local all = true", "		for m = 1, 0 do\n			local q = near[m]\n			local all = true", "no search (cost only, and a thin rim's reading)")
m("		for m = 1, nh do\n			local q = near[m]\n			local all = true", "		for m = 1, min(nh, 1) do\n			local q = near[m]\n			local all = true", "only the first hider asked (cost only?)")
m("		for m = 1, nh do\n			local q = near[m]\n			local all = true", "		for m = 1, nn do\n			local q = near[m]\n			local all = true", "every near part asked, centre hidden or not")
m("""			local all = true
			for c = 1, 4 do
				local a, b = CORNERS_A[c] * VERDICT_CORNER, CORNERS_B[c] * VERDICT_CORNER
				local sx, sy, sz = x + a * e1x""", """			local all = true
			for c = 1, 3 do
				local a, b = CORNERS_A[c] * VERDICT_CORNER, CORNERS_B[c] * VERDICT_CORNER
				local sx, sy, sz = x + a * e1x""", "3 corners")
m("""			work(4)
			if all then
				return 0
			end""", """			if all then
				return 0
			end""", "no spend for the search")
m("local a, b = CORNERS_A[c] * VERDICT_CORNER, CORNERS_B[c] * VERDICT_CORNER", "local a, b = CORNERS_A[c] * 0.75, CORNERS_B[c] * 0.75", "corners at the sub-grid's reach")
m("local a, b = CORNERS_A[c] * VERDICT_CORNER, CORNERS_B[c] * VERDICT_CORNER", "local a, b = CORNERS_A[c], CORNERS_B[c]", "corners on the rim (a rim under 2 % is read)")
m("if not hides(q, p.index, sx, sy, sz, sx + delta * nx, sy + delta * ny, sz + delta * nz) then", "if not hides(q, p.index, sx, sy, sz, sx, sy, sz) then", "the corners' probes at the surface")
# --- flatShown: reach
m("local hx = l1 * abs(px) + l2 * abs(rx) + q.hx + 2 * eps", "local hx = l2 * abs(rx) + q.hx + 2 * eps", "reach: e1 forgotten on x")
m("local hx = l1 * abs(px) + l2 * abs(rx) + q.hx + 2 * eps", "local hx = l1 * abs(px) + q.hx + 2 * eps", "reach: e2 forgotten on x")
m("local hy = l1 * abs(py) + l2 * abs(ry) + q.hy + 2 * eps", "local hy = l2 * abs(ry) + q.hy + 2 * eps", "reach: e1 forgotten on y")
m("local hy = l1 * abs(py) + l2 * abs(ry) + q.hy + 2 * eps", "local hy = l1 * abs(py) + q.hy + 2 * eps", "reach: e2 forgotten on y")
m("local hz = l1 * abs(pz) + l2 * abs(rz) + q.hz + 2 * eps", "local hz = l2 * abs(rz) + q.hz + 2 * eps", "reach: e1 forgotten on z")
m("local hz = l1 * abs(pz) + l2 * abs(rz) + q.hz + 2 * eps", "local hz = l1 * abs(pz) + q.hz + 2 * eps", "reach: e2 forgotten on z")
m("local hx = l1 * abs(px) + l2 * abs(rx) + q.hx + 2 * eps", "local hx = l1 * abs(px) + l2 * abs(rx) + q.hx", "reach: no eps on x")
m("local hy = l1 * abs(py) + l2 * abs(ry) + q.hy + 2 * eps", "local hy = l1 * abs(py) + l2 * abs(ry) + q.hy", "reach: no eps on y")
m("local hz = l1 * abs(pz) + l2 * abs(rz) + q.hz + 2 * eps", "local hz = l1 * abs(pz) + l2 * abs(rz) + q.hz", "reach: no eps on z")
m("local atSurface = abs(ox) <= hx and abs(oy) <= hy and abs(oz) <= hz", "local atSurface = true", "reach at the surface always (cost only)")
m("local atProbe = abs(ox + sx) <= hx and abs(oy + sy) <= hy and abs(oz + sz) <= hz", "local atProbe = true", "reach at the probe always (cost only)")
m("local atSurface = abs(ox) <= hx and abs(oy) <= hy and abs(oz) <= hz", "local atSurface = false", "never at the surface")
m("local atProbe = abs(ox + sx) <= hx and abs(oy + sy) <= hy and abs(oz + sz) <= hz", "local atProbe = false", "never at the probe")
m("local atProbe = abs(ox + sx) <= hx and abs(oy + sy) <= hy and abs(oz + sz) <= hz", "local atProbe = abs(ox) <= hx and abs(oy) <= hy and abs(oz) <= hz", "the probe's reach at the surface")
m("sx, sy, sz = delta * sx, delta * sy, delta * sz", "sx, sy, sz = 0, 0, 0", "a frame's probe at the surface")
m("near[reaching] = q", "near[m] = q", "a part that reaches stays where it was")
m("		work(nn)\n		if reaching == 0 then", "		if reaching == 0 then", "no spend for the reach")
m("""		if reaching == 0 then
			return w
		end""", """		if reaching == 0 then
			return 0
		end""", "nothing reaches: reads nothing")
# --- flatShown: families
m("lineShown(p, reaching, 3, 6, c * l2, l1, x + c * e2x, y + c * e2y, z + c * e2z, u1x, u1y, u1z)", "lineShown(p, reaching, 3, 6, c * l1, l1, x + c * e2x, y + c * e2y, z + c * e2z, u1x, u1y, u1z)", "family A offset by the wrong half-vector")
m("lineShown(p, reaching, 6, 3, c * l1, l2, x + c * e1x, y + c * e1y, z + c * e1z, u2x, u2y, u2z)", "lineShown(p, reaching, 6, 3, c * l2, l2, x + c * e1x, y + c * e1y, z + c * e1z, u2x, u2y, u2z)", "family B offset by the wrong half-vector")
m("lineShown(p, reaching, 3, 6, c * l2, l1, x + c * e2x, y + c * e2y, z + c * e2z, u1x, u1y, u1z)", "lineShown(p, reaching, 3, 6, c * l2, l2, x + c * e2x, y + c * e2y, z + c * e2z, u1x, u1y, u1z)", "family A's half length wrong")
m("lineShown(p, reaching, 6, 3, c * l1, l2, x + c * e1x, y + c * e1y, z + c * e1z, u2x, u2y, u2z)", "lineShown(p, reaching, 6, 3, c * l1, l1, x + c * e1x, y + c * e1y, z + c * e1z, u2x, u2y, u2z)", "family B's half length wrong")
m("lineShown(p, reaching, 3, 6, c * l2, l1, x + c * e2x, y + c * e2y, z + c * e2z, u1x, u1y, u1z)", "lineShown(p, reaching, 3, 6, c * l2, l1, x, y, z, u1x, u1y, u1z)", "family A's world line through the centre")
m("lineShown(p, reaching, 6, 3, c * l1, l2, x + c * e1x, y + c * e1y, z + c * e1z, u2x, u2y, u2z)", "lineShown(p, reaching, 6, 3, c * l1, l2, x, y, z, u2x, u2y, u2z)", "family B's world line through the centre")
m("if hiA - loA <= LINES_AGREE and shownA > LINE_NOTHING * onA and shownA < (1 - LINE_NOTHING) * onA then", "if false then", "family B always read (cost only)")
m("if hiA - loA <= LINES_AGREE and shownA > LINE_NOTHING * onA and shownA < (1 - LINE_NOTHING) * onA then", "if hiA - loA <= LINES_AGREE then", "A agrees on nothing or all: no B")
m("if hiA - loA <= LINES_AGREE and shownA > LINE_NOTHING * onA and shownA < (1 - LINE_NOTHING) * onA then", "if shownA > LINE_NOTHING * onA and shownA < (1 - LINE_NOTHING) * onA then", "A reads a fraction: no B, agree or not")
m("""		if readA <= LINE_NOTHING then
			return w * readB
		elseif""", """		if false then
			return w * readB
		elseif""", "A's nothing does not lose")
m("""		elseif readB <= LINE_NOTHING then
			return w * readA
		end""", """		end""", "B's nothing does not lose")
m("return w * (if spreadA < spreadB then readA else readB)", "return w * (if spreadA > spreadB then readA else readB)", "the family that disagrees wins")
m("if abs(spreadA - spreadB) > LINES_AGREE then", "if false then", "no spread compared")
m("return w * min(readA, readB)", "return w * readA", "a tie: A")
m("return w * min(readA, readB)", "return w * readB", "a tie: B")
m("return w * min(readA, readB)", "return w * max(readA, readB)", "a tie: the larger")
# --- shownArea
m("""				if hid then
					nh += 1
					near[nn], near[nh] = near[nh], q
				end""", "", "no part counted as hiding the centre")
m("""					near[nn], near[nh] = near[nh], q
""", "", "the centre's hiders not first")
m("if S.flat[k] then\n			return flatShown", "if p.code == BLOCK then\n			return flatShown", "only Blocks read by lines")
m("""			if hid and c > 1 then
				cand[c], cand[1] = cand[1], q -- it likely hides the next sample too
			end""", "", "no hider-first (cost only)")
m("return surfaceEstimate(p, h) <= Geo.VERDICT_SAMPLES", "return surfaceEstimate(p, h) < Geo.VERDICT_SAMPLES", "exactly VERDICT_SAMPLES does not fit")
m("return est <= Geo.N_SURF_WORK", "return est < Geo.N_SURF_WORK", "exactly N_SURF_WORK does not fit")
m("hider[i] = not isCopy[i] and parts[i].volume >= Geo.MIN_PART_VOLUME", "hider[i] = not isCopy[i] and parts[i].volume > Geo.MIN_PART_VOLUME", "the Dust floor hides nothing")
m("""			if abs(d0) <= lim or abs(d1) <= lim then
				nn += 1
				near[nn] = q
				if hid then""", """			if abs(d0) <= lim then
				nn += 1
				near[nn] = q
				if hid then""", "near by the sample alone")
m("""			if abs(d0) <= lim or abs(d1) <= lim then
				nn += 1
				near[nn] = q
				if hid then""", """			if abs(d1) <= lim then
				nn += 1
				near[nn] = q
				if hid then""", "near by the probe alone")
m("""			elseif hid then
				return 0 -- a part too far""", """			elseif false then
				return 0 -- a part too far""", "a far part hides nothing")
m("if aabbContains(q, x, y, z, m0) then\n				d0 = sd(q, x, y, z)\n			end\n			if aabbContains(q, ox, oy, oz, 2 * lim) then\n				d1 = sd(q, ox, oy, oz)\n			end\n			local hid = d0 < -eps or (rank[q.index] < rank[index]", "if aabbContains(q, x, y, z, 2 * eps) then\n				d0 = sd(q, x, y, z)\n			end\n			if aabbContains(q, ox, oy, oz, 2 * lim) then\n				d1 = sd(q, ox, oy, oz)\n			end\n			local hid = d0 < -eps or (rank[q.index] < rank[index]", "the sample's AABB tight")
m("local hid = d0 < -eps or (rank[q.index] < rank[index] and d0 <= eps) or d1 <= eps", "local hid = (rank[q.index] < rank[index] and d0 <= eps) or d1 <= eps", "no burial at the centre")
m("local hid = d0 < -eps or (rank[q.index] < rank[index] and d0 <= eps) or d1 <= eps", "local hid = d0 < -eps or d1 <= eps", "no coincidence at the centre")
m("local hid = d0 < -eps or (rank[q.index] < rank[index] and d0 <= eps) or d1 <= eps", "local hid = d0 < -eps or (rank[q.index] < rank[index] and d0 <= eps)", "no probe at the centre")
m("hOwn = PI * p.r / 2 / (Geo.VERDICT_BALL_NF - 0.5)", "hOwn = PI * p.r / 2 / Geo.VERDICT_BALL_NF", "a Ball of nf exactly")
m("if p.code == BALL then\n			return if hiddenNear then 0 else w", "if false then\n			return if hiddenNear then 0 else w", "a Ball read as a side")
# --- a Cylinder's side
m("local mx, my, mz = vx / l, vy / l, vz / l\n		return p.cx + along * p.ux + p.r * mx, p.cy + along * p.uy + p.r * my, p.cz + along * p.uz + p.r * mz, mx, my, mz", "local mx, my, mz = vx / l, vy / l, vz / l\n		return p.cx + along * p.ux + p.r * mx, p.cy + along * p.uy + p.r * my, p.cz + along * p.uz + p.r * mz, S.nx[k], S.ny[k], S.nz[k]", "a sub-point's probe on the centre's normal")
m("local vx, vy, vz = dx - along * p.ux, dy - along * p.uy, dz - along * p.uz", "local vx, vy, vz = dx, dy, dz", "radial not radial")
m("""			if hidden ~= hiddenNear then
				uniform = false
			end""", """			if false then
				uniform = false
			end""", "a side patch always uniform")

m("local cornerShows = not uniform", "local cornerShows = false", "no corner ever shows")
m("if uniform and hiddenNear and nn > 1 then", "if false then", "a side: no search")
m("for m = 1, nn do\n				local q = near[m]\n				if hides(q, index, x, y, z, ox, oy, oz) then", "for m = 1, nn do\n				local q = near[m]\n				if true then", "a side's search skips the centre")
m("""					for c = 1, 4 do
						local sx, sy, sz, mx, my, mz = sidePoint(""", """					for c = 1, 3 do
						local sx, sy, sz, mx, my, mz = sidePoint(""", "a side's search on 3 corners")
m("		work(16 * nn)\n		if hiddenPoints < 16 then", "		if hiddenPoints < 16 then", "no spend for a side's sub-grid")
m("return w * VERDICT_STRIP_CENTRE", "return 0", "no centre credit")
m("return if cornerShows then w * VERDICT_STRIP_RIM else 0", "return 0", "no rim credit")
# --- CornerWedge
m("if cells > 1 then -- the slope y/hy", "if false then -- the slope y/hy", "the verdict's slope not mirrored")
m("if cells > 1 then -- the slope y/hy", "if true then -- the slope y/hy", "the measure's slope mirrored too")
# --- Shapes
m("ok, t0, t1 = clipSlab(t0, t1, lox, lux, hx + d)", "ok, t0, t1 = clipSlab(t0, t1, lox, lux, hx)", "chord: no dilation on x", SH)
m("ok, t0, t1 = clipSlab(t0, t1, loy, luy, hy + d)", "ok, t0, t1 = clipSlab(t0, t1, loy, luy, hy)", "chord: no dilation on y", SH)
m("ok, t0, t1 = clipSlab(t0, t1, loz, luz, hz + d)", "ok, t0, t1 = clipSlab(t0, t1, loz, luz, hz)", "chord: no dilation on z", SH)


def read(path):
    return open(path, encoding="utf-8", newline="").read()


def run(cwd, args, timeout):
    t0 = time.time()
    try:
        p = subprocess.run([LUNE, "run", "tests/run", "--"] + args, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        return p.returncode, p.stdout.decode("utf-8", "replace"), time.time() - t0
    except subprocess.TimeoutExpired as e:
        return 124, (e.stdout or b"").decode("utf-8", "replace"), time.time() - t0


def fails(out):
    return [l.strip()[:150] for l in out.splitlines() if re.match(r"^\s*(FAIL|ERROR)", l)]


def worker(k, q, results, lock, stages):
    root = os.path.join(WORK, str(k))
    if os.path.isdir(root):
        shutil.rmtree(root)
    shutil.copytree(REPO, root, ignore=shutil.ignore_patterns(".git", "tools", "review", "*.rbxlx"))
    tol = os.path.join(root, "tests/lib/Tol.luau")
    t = read(tol)
    assert "CASE_BUDGET_MS = 2000," in t
    open(tol, "w", encoding="utf-8", newline="").write(t.replace("CASE_BUDGET_MS = 2000,", "CASE_BUDGET_MS = 300000,"))
    while True:
        try:
            idx = q.get_nowait()
        except queue.Empty:
            return
        mu = M[idx]
        path = os.path.join(root, mu["file"])
        original = read(os.path.join(REPO, mu["file"]))
        n = original.count(mu["old"])
        if n != 1:
            with lock:
                results.write(json.dumps(dict(idx=idx, why=mu["why"], state="BADPATCH", n=n, old=mu["old"][:80])) + "\n")
                results.flush()
            print(idx, "BADPATCH", n, mu["why"], flush=True)
            continue
        open(path, "w", encoding="utf-8", newline="").write(original.replace(mu["old"], mu["new"]))
        state, stage, fail = "SURVIVED", "", []
        for st in stages:
            args = ["--quick", "--filter", "Physics/"] if st == "physics" else ["--filter", "Physics/"]
            code, out, secs = run(root, args, 900)
            if code != 0:
                state, stage, fail = "KILLED", st, fails(out)
                if code == 124:
                    fail = ["TIMEOUT"] + fail
                if code == 2:
                    fail = ["HARNESS"] + out.splitlines()[-3:]
                break
        open(path, "w", encoding="utf-8", newline="").write(original)
        with lock:
            results.write(json.dumps(dict(idx=idx, why=mu["why"], state=state, stage=stage, fail=fail[:4])) + "\n")
            results.flush()
        print(idx, state, stage, mu["why"], flush=True)


def main():
    out = sys.argv[1]
    n = int(sys.argv[2])
    only = None if len(sys.argv) <= 3 or sys.argv[3] == "-" else set(int(x) for x in sys.argv[3].split(","))
    stages = sys.argv[4].split(",") if len(sys.argv) > 4 else ["physics", "slow"]
    q = queue.Queue()
    for i in range(len(M)):
        if only is None or i in only:
            q.put(i)
    lock = threading.Lock()
    with open(out, "a", encoding="utf-8") as results:
        ts = [threading.Thread(target=worker, args=(k, q, results, lock, stages)) for k in range(n)]
        for t in ts:
            t.start()
        for t in ts:
            t.join()


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--check":
        original = {}
        bad = 0
        for i, mu in enumerate(M):
            f = mu["file"]
            original.setdefault(f, read(os.path.join(REPO, f)))
            c = original[f].count(mu["old"])
            if c != 1:
                print(i, c, mu["why"], repr(mu["old"][:70]))
                bad += 1
        print(len(M), "mutants,", bad, "bad")
    else:
        main()
