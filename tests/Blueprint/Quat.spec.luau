--!strict
-- T-BP-12 Blueprint/Quat (SPEC §3.4, §3.11, E-S8.5): R(q) orthonormal to 1e-12 (s = 2/‖q‖², any non-zero q), q ≡ −q
-- bit for bit, fromMatrix round trip (Shepperd, every branch), plus the contracts of normalize, hemisphere, mul and
-- rotate. Random quaternions come from Prop (Tol.PROP_BASE_SEED, Tol.PROP_N).

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Prop = require("../lib/Prop")
local Tol = require("../lib/Tol")
local TestRng = require("../lib/TestRng")
local Drafts = require("./Drafts")
local Quat = require("../../src/shared/Blueprint/Quat")

type TestRng = TestRng.TestRng
type Q = { number }

local R = Drafts.R

local function n2(q: Q): number
	return q[1] * q[1] + q[2] * q[2] + q[3] * q[3] + q[4] * q[4]
end

local function neg(q: Q): Q
	return { -q[1], -q[2], -q[3], -q[4] }
end

local function matrix(q: Q): { number }
	return { Quat.toMatrix(q) }
end

local function maxDiff(a: { number }, b: { number }): number
	local m = 0
	for k = 1, #a do
		m = math.max(m, math.abs(a[k] - b[k]))
	end
	return m
end

local function same(a: { number }, b: { number }, what: string)
	local diff = Drafts.bitDiff(a, b)
	A.truthy(diff == nil, what .. ": " .. tostring(diff) .. " (" .. Dump.short(a) .. " vs " .. Dump.short(b) .. ")")
end

-- |R·Rᵀ − I| and |det R − 1|
local function orthoError(m: { number }): number
	local e = 0
	for a = 0, 2 do
		for b = 0, 2 do
			local dot = m[a * 3 + 1] * m[b * 3 + 1] + m[a * 3 + 2] * m[b * 3 + 2] + m[a * 3 + 3] * m[b * 3 + 3]
			e = math.max(e, math.abs(dot - (if a == b then 1 else 0)))
		end
	end
	local det = m[1] * (m[5] * m[9] - m[6] * m[8]) - m[2] * (m[4] * m[9] - m[6] * m[7]) + m[3] * (m[4] * m[8] - m[5] * m[7])
	return math.max(e, math.abs(det - 1))
end

local function inHemisphere(q: Q): boolean
	if q[4] ~= 0 then
		return q[4] > 0
	end
	for k = 1, 3 do
		if q[k] ~= 0 then
			return q[k] > 0
		end
	end
	return false
end

local function noNegativeZero(q: Q): boolean
	for k = 1, 4 do
		if q[k] == 0 and 1 / q[k] < 0 then
			return false
		end
	end
	return true
end

-- A random rotation, unit (editor-like) or scaled by 0.5…2 (toMatrix must not care).
local function anyQuat(rng: TestRng): Q
	local q = Drafts.unitQuat(rng)
	if rng:float() < 0.4 then
		local f = rng:range(0.5, 2)
		q = { q[1] * f, q[2] * f, q[3] * f, q[4] * f }
	end
	return q
end

-- Rotations whose largest component is w, x, y or z, so fromMatrix takes each of its four branches.
local function dominated(rng: TestRng, axis: number): Q
	local q = { rng:range(-0.4, 0.4), rng:range(-0.4, 0.4), rng:range(-0.4, 0.4), rng:range(-0.4, 0.4) }
	q[axis] = (if rng:float() < 0.5 then -1 else 1) * rng:range(0.8, 1)
	local s = math.sqrt(n2(q))
	return { q[1] / s, q[2] / s, q[3] / s, q[4] / s }
end

return Test.suite("Blueprint/Quat", function(t)
	t.it("T-BP-12 IDENTITY is {0, 0, 0, 1}, frozen; the module is frozen", function()
		same(Quat.IDENTITY, { 0, 0, 0, 1 }, "IDENTITY")
		A.truthy(table.isfrozen(Quat.IDENTITY), "IDENTITY frozen")
		A.truthy(table.isfrozen(Quat), "module frozen")
		same(matrix(Quat.IDENTITY), { 1, 0, 0, 0, 1, 0, 0, 0, 1 }, "R(IDENTITY) = I")
	end)

	t.it("T-BP-12 R(q) is orthonormal to 1e-12 with det +1, for unit and non-unit q (PROP_N)", function()
		Prop.check(Tol.PROP_N, anyQuat, function(q: Q)
			local e = orthoError(matrix(q))
			A.truthy(e <= 1e-12, string.format("orthonormality error %.3g", e))
		end)
	end)

	t.it("T-BP-12 matches §3.4 on exact rotations; columns are the local axes", function()
		-- 90° about Z: local X → +Y, local Y → −X
		local m = matrix({ 0, 0, R, R })
		A.truthy(maxDiff(m, { 0, -1, 0, 1, 0, 0, 0, 0, 1 }) <= 1e-15, "Z90 " .. Dump.short(m))
		m = matrix({ 0, R, 0, R }) -- 90° about Y: local X → −Z
		A.truthy(maxDiff(m, { 0, 0, 1, 0, 1, 0, -1, 0, 0 }) <= 1e-15, "Y90 " .. Dump.short(m))
		m = matrix({ 1, 0, 0, 0 }) -- 180° about X
		same(m, { 1, 0, 0, 0, -1, 0, 0, 0, -1 }, "X180")
		m = matrix({ 0, 0, 0, 2 }) -- non-unit identity: s = 2/‖q‖² makes it exact
		same(m, { 1, 0, 0, 0, 1, 0, 0, 0, 1 }, "{0, 0, 0, 2}")
	end)

	t.it("T-BP-12 q ≡ −q: the same matrix, rotation and hemisphere bit for bit (PROP_N)", function()
		Prop.check(Tol.PROP_N, anyQuat, function(q: Q)
			same(matrix(neg(q)), matrix(q), "R(−q) = R(q)")
			local v = { 0.3, -1.7, 2.25 }
			same(Quat.rotate(neg(q), v), Quat.rotate(q, v), "rotate(−q) = rotate(q)")
			same(Quat.hemisphere(neg(q)), Quat.hemisphere(q), "hemisphere(−q) = hemisphere(q)")
		end)
	end)

	t.it("T-BP-12 fromMatrix round trip in every Shepperd branch; the result is canonical (PROP_N)", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): Q
			return dominated(rng, rng:int(1, 4))
		end, function(q: Q)
			local back = Quat.fromMatrix(Quat.toMatrix(q))
			local want = Quat.hemisphere(q)
			local e = maxDiff(back, want)
			A.truthy(e <= 2e-15, string.format("fromMatrix(toMatrix(q)) off by %.3g", e))
			A.truthy(math.abs(n2(back) - 1) <= 1e-15, "unit")
			A.truthy(inHemisphere(back) and noNegativeZero(back), "C4–C5 applied")
			A.truthy(maxDiff(matrix(back), matrix(q)) <= 1e-14, "toMatrix(fromMatrix(R)) = R")
		end)
	end)

	t.it("T-BP-12 fromMatrix on exact rotations gives the canonical quaternion", function()
		same(Quat.fromMatrix(1, 0, 0, 0, 1, 0, 0, 0, 1), { 0, 0, 0, 1 }, "identity")
		same(Quat.fromMatrix(1, 0, 0, 0, -1, 0, 0, 0, -1), { 1, 0, 0, 0 }, "X180 (qw = 0, x > 0)")
		same(Quat.fromMatrix(-1, 0, 0, 0, 1, 0, 0, 0, -1), { 0, 1, 0, 0 }, "Y180")
		same(Quat.fromMatrix(-1, 0, 0, 0, -1, 0, 0, 0, 1), { 0, 0, 1, 0 }, "Z180")
		local z90 = Quat.fromMatrix(0, -1, 0, 1, 0, 0, 0, 0, 1)
		A.truthy(maxDiff(z90, { 0, 0, R, R }) <= 3e-16, "Z90 " .. Dump.short(z90))
		local zm90 = Quat.fromMatrix(0, 1, 0, -1, 0, 0, 0, 0, 1)
		A.truthy(maxDiff(zm90, { 0, 0, -R, R }) <= 3e-16, "Z−90 " .. Dump.short(zm90))
		same(Quat.fromMatrix(0, 0, 0, 0, 0, 0, 0, 0, 0), { 0, 0, 0, 1 }, "a degenerate matrix still yields a unit q")
	end)

	t.it("T-BP-12 normalize: unit, same direction, new table; errors without a direction", function()
		Prop.check(Tol.PROP_N, anyQuat, function(q: Q)
			local u = Quat.normalize(q)
			A.truthy(math.abs(n2(u) - 1) <= 1e-15, "unit")
			A.truthy(u[1] * q[1] + u[2] * q[2] + u[3] * q[3] + u[4] * q[4] > 0, "same direction")
			A.falsy(u == q, "a new table")
		end)
		for _, bad in { { 0, 0, 0, 0 }, { 0, 0, 0 / 0, 1 }, { math.huge, 0, 0, 0 } } do
			A.throws(function()
				Quat.normalize(bad)
			end, "no direction")
		end
	end)

	t.it("T-BP-12 hemisphere: C4 sign rule and C5 −0 → +0, a new table", function()
		local cases: { { Q } } = {
			{ { 0, 0, 0, -1 }, { 0, 0, 0, 1 } },
			{ { -0.0, 0, -0.0, 1 }, { 0, 0, 0, 1 } },
			{ { 0.5, -0.5, 0.5, -0.5 }, { -0.5, 0.5, -0.5, 0.5 } },
			{ { -1, 0, 0, 0 }, { 1, 0, 0, 0 } },
			{ { -1, -0.0, -0.0, -0.0 }, { 1, 0, 0, 0 } },
			{ { 0, -1, 0, 0 }, { 0, 1, 0, 0 } },
			{ { -0.0, -0.0, -1, 0 }, { 0, 0, 1, 0 } },
			{ { 0, R, -R, 0 }, { 0, R, -R, 0 } },
			{ { 0, -R, R, 0 }, { 0, R, -R, 0 } },
			{ { -R, 0, 0, R }, { -R, 0, 0, R } },
		}
		for _, c in cases do
			local got = Quat.hemisphere(c[1])
			same(got, c[2], "hemisphere " .. Dump.short(c[1]))
			A.falsy(got == c[1], "a new table")
			same(Quat.hemisphere(got), got, "idempotent")
		end
	end)

	t.it("T-BP-12 mul: a ⊗ b rotates by b, then by a; identity and inverse; inputs untouched (PROP_N)", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): { Q }
			return { Drafts.unitQuat(rng), Drafts.unitQuat(rng), Drafts.unitQuat(rng) }
		end, function(qs: { Q })
			local a, b, c = qs[1], qs[2], qs[3]
			local a0, b0 = table.clone(a), table.clone(b)
			local v = { 1.25, -0.5, 3 }
			local composed = Quat.rotate(Quat.mul(a, b), v)
			local stepwise = Quat.rotate(a, Quat.rotate(b, v))
			A.truthy(maxDiff(composed, stepwise) <= 1e-12, "rotate(a ⊗ b) = rotate(a) ∘ rotate(b)")
			A.truthy(maxDiff(Quat.mul(Quat.mul(a, b), c), Quat.mul(a, Quat.mul(b, c))) <= 1e-15, "associative")
			A.truthy(maxDiff(Quat.mul(Quat.IDENTITY, a), a) == 0 and maxDiff(Quat.mul(a, Quat.IDENTITY), a) == 0,
				"identity")
			local inverse = Quat.mul(a, { -a[1], -a[2], -a[3], a[4] })
			A.truthy(maxDiff(inverse, { 0, 0, 0, 1 }) <= 1e-15, "a ⊗ conj(a) = identity")
			same(a, a0, "a untouched")
			same(b, b0, "b untouched")
		end)
		-- Hamilton's rules: i·j = k, j·k = i, k·i = j
		same(Quat.mul({ 1, 0, 0, 0 }, { 0, 1, 0, 0 }), { 0, 0, 1, 0 }, "i ⊗ j = k")
		same(Quat.mul({ 0, 1, 0, 0 }, { 0, 0, 1, 0 }), { 1, 0, 0, 0 }, "j ⊗ k = i")
		same(Quat.mul({ 0, 0, 1, 0 }, { 1, 0, 0, 0 }), { 0, 1, 0, 0 }, "k ⊗ i = j")
	end)

	t.it("T-BP-12 rotate: R(q)·v, length kept for unit q, a new table (PROP_N)", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): { any }
			return { Drafts.unitQuat(rng), { rng:range(-5, 5), rng:range(-5, 5), rng:range(-5, 5) } }
		end, function(input: { any })
			local q, v = input[1] :: Q, input[2] :: { number }
			local w = Quat.rotate(q, v)
			local m = matrix(q)
			local want = { m[1] * v[1] + m[2] * v[2] + m[3] * v[3], m[4] * v[1] + m[5] * v[2] + m[6] * v[3],
				m[7] * v[1] + m[8] * v[2] + m[9] * v[3] }
			same(w, want, "rotate = toMatrix · v")
			local lv = math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
			local lw = math.sqrt(w[1] * w[1] + w[2] * w[2] + w[3] * w[3])
			A.truthy(math.abs(lw - lv) <= 1e-12 * math.max(1, lv), "length kept")
			A.falsy(w == v, "a new table")
		end)
		local w = Quat.rotate({ 0, 0, R, R }, { 1, 0, 0 })
		A.truthy(maxDiff(w, { 0, 1, 0 }) <= 1e-15, "Z90 takes +X to +Y")
	end)
end)
