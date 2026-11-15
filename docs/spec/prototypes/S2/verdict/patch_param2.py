#!/usr/bin/env python
"""Second round of study knobs in tree/'s parametric Sampling: precision rules for the verdict only (never the measure).
   rimCredit  a flat patch with a visible corner on the part's surface, whose sub-points all read hidden, shows a strip narrower than the sub-grid: credit it
   single     a patch counts as uniformly hidden only if one part hides its centre and its 4 corners (a slit between two parts is not uniform)
   curved     a Cylinder's side gets the corner test and the sub-grid, sub-points projected onto the surface, normals radial"""
path = 'tree/src/shared/Physics/Sampling.luau'
s = open(path, encoding='utf-8', newline='').read()
crlf = '\r\n' in s
if crlf:
    s = s.replace('\r\n', '\n')


def sub(old, new, count=1):
    global s
    assert old in s, old
    s = s.replace(old, new, count)


sub('''	earlyOut = false, -- verdict: a sample hidden by a part that is not near stops the candidate loop (the same bits, less time)
''', '''	earlyOut = false, -- verdict: a sample hidden by a part that is not near stops the candidate loop (the same bits, less time)
	rimCredit = 0, -- verdict: the share of a flat patch credited when a corner shows but no sub-point does (0: none)
	rimCredit1 = 0, -- the same when only one corner shows (0: rimCredit)
	single = false, -- verdict: a patch is uniformly hidden only if one part hides its centre and its 4 corners
	curved = false, -- verdict: a Cylinder's side gets the corner test and the sub-grid
	ballTest = false, -- verdict: reserved
''')

# the near loop and pre-test
old = s[s.index('''		if hiddenFar then
			return 0, 0
		end
		if nn == 0 then
			return w, w
		end
		local centre = if hiddenNear then 0 else w
'''):s.index('''	-- the verdict: each part on a grid of its own''')]

new = '''		if hiddenFar then
			return 0, 0
		end
		if nn == 0 then
			return w, w
		end
		local centre = if hiddenNear then 0 else w
		local curvedPatch = inVerdict and CFG.curved and p.code == CYLINDER and not S.flat[k]
		if (not S.flat[k] and not curvedPatch) or subLeft < 20 * nn then
			return centre, centre
		end
		-- corner pre-test: the hiding regions are convex, so a patch whose 4 corners agree with its centre is uniform
		subLeft -= 4 * nn
		subTests += 4 * nn
		local uniform = true
		local cornersSeen = 0
		local wantAll = inVerdict and (CFG.rimCredit > 0)
		for c = 1, 4 do
			local a, b = CORNERS_A[c], CORNERS_B[c]
			local sx, sy, sz = x + a * e1x + b * e2x, y + a * e1y + b * e2y, z + a * e1z + b * e2z
			local mx, my, mz = nx, ny, nz
			if curvedPatch then
				sx, sy, sz, mx, my, mz = ontoCylinder(p, sx, sy, sz)
			end
			local tx, ty, tz = sx + delta * mx, sy + delta * my, sz + delta * mz
			local hidden = false
			for m = 1, nn do
				if hides(near[m], p.index, sx, sy, sz, tx, ty, tz) then
					hidden = true
					break
				end
			end
			if hidden ~= hiddenNear then
				uniform = false
				if not wantAll then
					break
				end
				if not hidden and (curvedPatch or sd(p, sx, sy, sz) <= eps) then
					cornersSeen += 1
				end
			end
		end
		work(4 * nn)
		if uniform and hiddenNear and inVerdict and CFG.single and nn > 1 then
			-- a slit between two hiders has hidden corners and a hidden centre: only one part hiding all five is uniform
			local one = false
			for m = 1, nn do
				local q = near[m]
				if hides(q, p.index, x, y, z, ox, oy, oz) then
					one = true
					for c = 1, 4 do
						local a, b = CORNERS_A[c], CORNERS_B[c]
						local sx, sy, sz = x + a * e1x + b * e2x, y + a * e1y + b * e2y, z + a * e1z + b * e2z
						local mx, my, mz = nx, ny, nz
						if curvedPatch then
							sx, sy, sz, mx, my, mz = ontoCylinder(p, sx, sy, sz)
						end
						if not hides(q, p.index, sx, sy, sz, sx + delta * mx, sy + delta * my, sz + delta * mz) then
							one = false
							break
						end
					end
					if one then
						break
					end
				end
			end
			uniform = one
		end
		if uniform then
			return centre, centre
		end
		subLeft -= 16 * nn
		subTests += 16 * nn
		subSampled += 1
		local hiddenCount, onSurface, hiddenOnSurface = 0, 0, 0
		for i = 1, 4 do
			local a = SUB_GRID[i]
			for j = 1, 4 do
				local b = SUB_GRID[j]
				local sx, sy, sz = x + a * e1x + b * e2x, y + a * e1y + b * e2y, z + a * e1z + b * e2z
				local mx, my, mz = nx, ny, nz
				local here
				if curvedPatch then
					sx, sy, sz, mx, my, mz = ontoCylinder(p, sx, sy, sz)
					here = true
				else
					here = sd(p, sx, sy, sz) <= eps
				end
				local tx, ty, tz = sx + delta * mx, sy + delta * my, sz + delta * mz
				if here then
					onSurface += 1
				end
				for m = 1, nn do
					if hides(near[m], p.index, sx, sy, sz, tx, ty, tz) then
						hiddenCount += 1
						if here then
							hiddenOnSurface += 1
						end
						break
					end
				end
			end
		end
		work(16 * nn)
		local visible = if onSurface > 0 then w * (onSurface - hiddenOnSurface) / onSurface else centre
		if visible == 0 and cornersSeen > 0 then
			-- a strip along the rim, narrower than the sub-grid can see
			local credit = CFG.rimCredit
			if cornersSeen == 1 and CFG.rimCredit1 > 0 then
				credit = CFG.rimCredit1
			end
			visible = w * credit
		end
		return w * (16 - hiddenCount) / 16, visible
	end

'''
s = s.replace(old, new, 1)

sub('''	local verdictEarly = false
	local stats = CFG.stats
''', '''	local verdictEarly = false
	local inVerdict = false
	local stats = CFG.stats
''')
sub('''	-- The whole verdict at a sub-point: only the near parts can change over the patch (sd is 1-Lipschitz).
''', '''	-- a point near a Cylinder's side, onto its surface, with the radial normal there
	local function ontoCylinder(p: Prepared, sx: number, sy: number, sz: number): (number, number, number, number, number, number)
		local dx, dy, dz = sx - p.cx, sy - p.cy, sz - p.cz
		local t = dx * p.ux + dy * p.uy + dz * p.uz
		local vx, vy, vz = dx - t * p.ux, dy - t * p.uy, dz - t * p.uz
		local l = sqrt(vx * vx + vy * vy + vz * vz)
		local mx, my, mz = vx / l, vy / l, vz / l
		return p.cx + t * p.ux + p.r * mx, p.cy + t * p.uy + p.r * my, p.cz + t * p.uz + p.r * mz, mx, my, mz
	end

	-- The whole verdict at a sub-point: only the near parts can change over the patch (sd is 1-Lipschitz).
''')
sub('''			subLeft = CFG.subWork
			verdictEarly = CFG.earlyOut
''', '''			subLeft = CFG.subWork
			verdictEarly = CFG.earlyOut
			inVerdict = true
''')
sub('''			verdictEarly = false
			if stats then
''', '''			verdictEarly = false
			inVerdict = false
			if stats then
				stats.subTests = (stats.subTests or 0) + subTests
				subTests = 0
''')

if crlf:
    s = s.replace('\n', '\r\n')
open(path, 'w', encoding='utf-8', newline='').write(s)

path = 'variants.luau'
s = open(path, encoding='utf-8', newline='').read()
sub('''			elseif key == "nf" then
				def.ballRule, def.ballNf = "nf", tonumber(value)
''', '''			elseif key == "nf" then
				def.ballRule, def.ballNf = "nf", tonumber(value)
			elseif key == "rc" then
				def.rimCredit = if value == "" then 1 / 16 else 1 / tonumber(value)
			elseif key == "rcone" then
				def.rimCredit1 = 1 / tonumber(value)
			elseif key == "sh" then
				def.single = true
			elseif key == "cs" then
				def.curved = true
''')
sub('''	cfg.earlyOut = def.earlyOut or false
''', '''	cfg.earlyOut = def.earlyOut or false
	cfg.rimCredit = def.rimCredit or 0
	cfg.rimCredit1 = def.rimCredit1 or 0
	cfg.single = def.single or false
	cfg.curved = def.curved or false
''')
open(path, 'w', encoding='utf-8', newline='').write(s)
print('ok')
