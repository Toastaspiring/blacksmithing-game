--!strict
-- S1 prototype (revision): why C3 renormalizes only above QUAT_NORM_TOL.
-- Takes editor-like unit quaternions (one q/|q| pass) and applies q/|q| again, N times in a row,
-- counting quaternions whose bits change (an always-renormalize rule would rewrite them on every save).
-- Run: lune run renorm_drift.luau
math.randomseed(20261031)
local function gauss(): number
	local u1 = math.max(math.random(), 1e-300)
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * math.random())
end
local function norm(q: { number }): { number }
	local s = math.sqrt(q[1] * q[1] + q[2] * q[2] + q[3] * q[3] + q[4] * q[4])
	return { q[1] / s, q[2] / s, q[3] / s, q[4] / s }
end
local function same(a: { number }, b: { number }): boolean
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end
local N, changedOnce, stillMovingAfter10, maxN2 = 200000, 0, 0, 0
for _ = 1, N do
	local q = norm({ gauss(), gauss(), gauss(), gauss() })
	local m = math.abs(q[1] * q[1] + q[2] * q[2] + q[3] * q[3] + q[4] * q[4] - 1)
	if m > maxN2 then
		maxN2 = m
	end
	local r = norm(q)
	if not same(q, r) then
		changedOnce += 1
	end
	local cur = r
	for _ = 2, 10 do
		cur = norm(cur)
	end
	if not same(norm(cur), cur) then
		stillMovingAfter10 += 1
	end
end
print(("unit quaternions: %d; second q/|q| changes bits in %d (%.1f%%); still changing after 10 passes: %d; max |n2-1| of inputs %.3g (threshold 1e-9)"):format(
	N, changedOnce, 100 * changedOnce / N, stillMovingAfter10, maxN2))
