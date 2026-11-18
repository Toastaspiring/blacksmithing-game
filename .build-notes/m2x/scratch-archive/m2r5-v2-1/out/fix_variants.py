# verifier: reading-rule fixes tried on the study's tree. usage: fix_variants.py <name> -- patches tree/src in place
import sys
S = 'tree/src/shared/Physics/Sampling.luau'
A = """		-- a strip narrower than the sub-grid's reach: through the centre, or along the rim
		if not hiddenNear then
			return w * VERDICT_STRIP_CENTRE
		end
		return if cornerShows then w * VERDICT_STRIP_RIM else 0
"""


def fine(N):
    return """		-- a strip narrower than the sub-grid's reach: through the centre, or along the rim
		if not hiddenNear then
			return w * VERDICT_STRIP_CENTRE
		end
		if cornerShows then
			return w * VERDICT_STRIP_RIM
		end
		-- hidden at all 21 points, by more than one part: a slit can pass between them
		local onFine, hiddenFine = 0, 0
		for i = 1, %d do
			local a = -1 + (2 * i - 1) / %d
			for j = 1, %d do
				local sx, sy, sz, mx, my, mz = patchPoint(p, S, k, a, -1 + (2 * j - 1) / %d)
				if not S.flat[k] or sd(p, sx, sy, sz) <= eps then
					onFine += 1
					if hiddenByNear(index, nn, sx, sy, sz, sx + delta * mx, sy + delta * my, sz + delta * mz) then
						hiddenFine += 1
					end
				end
			end
		end
		work(%d * nn)
		return if onFine > 0 then w * (onFine - hiddenFine) / onFine else 0
""" % (N, N, N, N, N * N)


def seam(K):
    return """		-- a strip narrower than the sub-grid's reach: through the centre, or along the rim
		if not hiddenNear then
			return w * VERDICT_STRIP_CENTRE
		end
		if cornerShows then
			return w * VERDICT_STRIP_RIM
		end
		-- hidden at all 21 points, by more than one part. A slit can pass between two sub-points hidden by different parts
		-- that neither hides both of: look along those segments
		local shownSeam = 0
		for c = 1, 16 do
			local qa = subHider[c]
			if qa then
				for side = 1, 2 do
					local d = if side == 1 then c + 1 else c + 4
					if (side == 1 and c %% 4 ~= 0) or (side == 2 and d <= 16) then
						local qb = subHider[d]
						if qb and qb ~= qa then
							local a1, b1 = SUB_GRID[(c - 1) // 4 + 1], SUB_GRID[(c - 1) %% 4 + 1]
							local a2, b2 = SUB_GRID[(d - 1) // 4 + 1], SUB_GRID[(d - 1) %% 4 + 1]
							local ux, uy, uz, um, un, uo = patchPoint(p, S, k, a1, b1)
							local vx, vy, vz, vm, vn, vo = patchPoint(p, S, k, a2, b2)
							if not hides(qa, index, vx, vy, vz, vx + delta * vm, vy + delta * vn, vz + delta * vo)
								and not hides(qb, index, ux, uy, uz, ux + delta * um, uy + delta * un, uz + delta * uo)
							then
								for t = 1, %d do
									local f = t / %d
									local sx, sy, sz, mx, my, mz = patchPoint(p, S, k, a1 + f * (a2 - a1), b1 + f * (b2 - b1))
									if (not S.flat[k] or sd(p, sx, sy, sz) <= eps)
										and not hiddenByNear(index, nn, sx, sy, sz, sx + delta * mx, sy + delta * my, sz + delta * mz)
									then
										shownSeam += 1
									end
								end
								work(%d * nn)
							end
						end
					end
				end
			end
		end
		return w * shownSeam / (16 * %d)
""" % (K, K + 1, K, K)


def apply(name):
    s = open(S, encoding='utf-8', newline='').read()
    crlf = '\r\n' in s
    def nl(t):
        return t.replace('\n', '\r\n') if crlf else t
    a = nl(A)
    assert a in s
    if name.startswith('fine'):
        s = s.replace(a, nl(fine(int(name[4:]))))
    elif name.startswith('seam'):
        s = s.replace(a, nl(seam(int(name[4:]))))
        x1 = nl("\t\tlocal onSurface, hiddenOnSurface = 0, 0\n")
        y1 = x1 + nl("\t\tfor c = 1, 16 do\n\t\t\tsubHider[c] = false\n\t\tend\n")
        assert x1 in s
        s = s.replace(x1, y1)
        x2 = nl("\t\t\t\t\tif hiddenByNear(index, nn, sx, sy, sz, sx + delta * mx, sy + delta * my, sz + delta * mz) then\n\t\t\t\t\t\thiddenOnSurface += 1\n")
        y2 = x2 + nl("\t\t\t\t\t\tsubHider[(i - 1) * 4 + j] = near[1]\n")
        assert x2 in s
        s = s.replace(x2, y2)
        x3 = nl("\tlocal near: { Prepared } = {}\n")
        y3 = x3 + nl("\tlocal subHider: { any } = table.create(16, false)\n")
        assert x3 in s
        s = s.replace(x3, y3)
    else:
        raise SystemExit('no variant ' + name)
    open(S, 'w', encoding='utf-8', newline='').write(s)


if __name__ == '__main__':
    apply(sys.argv[1])


def look(K):
    return """		-- a strip narrower than the sub-grid's reach: through the centre, or along the rim
		if not hiddenNear then
			return w * VERDICT_STRIP_CENTRE
		end
		if cornerShows then
			return w * VERDICT_STRIP_RIM
		end
		-- hidden at all 21 points, by more than one part. A slit can pass between two points hidden by different parts that neither
		-- hides both of: along each row and column of the sub-grid, out to the corners' reach, look between those points
		local shownLook = 0
		for pass = 1, 2 do
			for r = 1, 4 do
				local fixed = SUB_GRID[r]
				local qPrev: any, vPrev: any = nil, nil
				local px, py, pz, pm, pn, po = 0, 0, 0, 0, 0, 0
				for i = 1, 6 do
					local v = LOOK[i]
					local a, b = if pass == 1 then v else fixed, if pass == 1 then fixed else v
					local sx, sy, sz, mx, my, mz = patchPoint(p, S, k, a, b)
					local q: any = nil
					if not S.flat[k] or sd(p, sx, sy, sz) <= eps then
						if hiddenByNear(index, nn, sx, sy, sz, sx + delta * mx, sy + delta * my, sz + delta * mz) then
							q = near[1]
						elseif vPrev then
							shownLook += 0.25 * abs(v - vPrev) / 2
						end
					end
					if q and qPrev and q ~= qPrev
						and not hides(q, index, px, py, pz, px + delta * pm, py + delta * pn, pz + delta * po)
						and not hides(qPrev, index, sx, sy, sz, sx + delta * mx, sy + delta * my, sz + delta * mz)
					then
						local seen = 0
						for t = 1, %d do
							local f = t / %d
							local c = vPrev + f * (v - vPrev)
							local tx, ty, tz, gx, gy, gz = patchPoint(p, S, k, if pass == 1 then c else fixed, if pass == 1 then fixed else c)
							if (not S.flat[k] or sd(p, tx, ty, tz) <= eps)
								and not hiddenByNear(index, nn, tx, ty, tz, tx + delta * gx, ty + delta * gy, tz + delta * gz)
							then
								seen += 1
							end
						end
						work(%d * nn)
						shownLook += 0.25 * abs(v - vPrev) / 2 * seen / %d
					end
					qPrev, vPrev = q, v
					px, py, pz, pm, pn, po = sx, sy, sz, mx, my, mz
				end
				work(6 * nn)
			end
		end
		return w * shownLook
""" % (K, K + 1, K, K)


_apply0 = apply


def apply(name):
    if name.startswith('look'):
        s = open(S, encoding='utf-8', newline='').read()
        crlf = '\r\n' in s
        def nl(t):
            return t.replace('\n', '\r\n') if crlf else t
        a = nl(A)
        assert a in s
        s = s.replace(a, nl(look(int(name[4:]))))
        x3 = nl("\tlocal near: { Prepared } = {}\n")
        y3 = x3 + nl("\tlocal LOOK: { number } = { -VERDICT_CORNER, -0.75, -0.25, 0.25, 0.75, VERDICT_CORNER }\n")
        assert x3 in s
        s = s.replace(x3, y3)
        open(S, 'w', encoding='utf-8', newline='').write(s)
    else:
        _apply0(name)
