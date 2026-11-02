--!strict
-- T-UTIL-01 Util/Quantize (SPEC §9.5, §16.17, §14.5): q(x, SCALAR_SCALE) = math.round(x · 1e4) / 1e4 puts derived
-- scalars on the 1e-4 grid; it errors on non-finite input, folds −0 into 0 and is idempotent bit for bit. Property
-- cases come from Prop (Tol.PROP_BASE_SEED, Tol.PROP_N).

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Prop = require("../lib/Prop")
local Tol = require("../lib/Tol")
local TestRng = require("../lib/TestRng")
local Quantize = require("../../src/shared/Util/Quantize")

type TestRng = TestRng.TestRng

local S = Quantize.SCALAR_SCALE
local LIMIT = 2251799813685248 -- 2^51: a grid index |round(x · scale)| from here on is refused

local function q(x: number): number
	return Quantize.q(x, S)
end

-- bit for bit, −0 distinguished from +0
local function same(a: number, b: number): boolean
	return a == b and (a ~= 0 or 1 / a == 1 / b)
end

-- A value of random sign and magnitude 1e-7 … 1e10 (log-uniform by decades), sometimes on or next to a grid half.
local function value(rng: TestRng): number
	local mode = rng:int(1, 4)
	if mode == 1 then
		return (rng:int(-2000000, 2000000) + 0.5) / S -- an exact-looking half between two grid points
	elseif mode == 2 then
		return rng:int(-2000000, 2000000) / S -- on the grid
	end
	local decade = rng:int(-7, 10)
	local m = 1 + 9 * rng:float()
	local x = m
	if decade >= 0 then
		for _ = 1, decade do
			x *= 10
		end
	else
		for _ = 1, -decade do
			x /= 10
		end
	end
	return if rng:float() < 0.5 then -x else x
end

return Test.suite("Util/Quantize", function(t)
	t.it("T-UTIL-01 SCALAR_SCALE is the 1e-4 grid (§16.17)", function()
		A.eq(Quantize.SCALAR_SCALE, 10000)
		A.truthy(table.isfrozen(Quantize), "module table frozen")
	end)

	t.it("T-UTIL-01 rounds to the nearest grid point, halves away from zero", function()
		local cases: { { number } } = {
			{ 0, 0 },
			{ 1, 1 },
			{ -1, -1 },
			{ 0.12345, 1235 / 10000 }, -- 0.12345 · 1e4 = 1234.5 in doubles: away from zero
			{ -0.12345, -1235 / 10000 },
			{ 0.00005, 1 / 10000 },
			{ -0.00005, -1 / 10000 },
			{ 0.00004999, 0 },
			{ 0.1999999999, 2000 / 10000 },
			{ 0.19995, 2000 / 10000 }, -- 1999.5 in doubles: away from zero
			{ 2.00005, 20001 / 10000 },
			{ 1 / 3, 3333 / 10000 },
			{ 123.456789, 1234568 / 10000 },
		}
		for _, c in cases do
			local got = q(c[1])
			A.truthy(same(got, c[2]), string.format("q(%.17g) = %.17g, expected %.17g", c[1], got, c[2]))
		end
	end)

	t.it("T-UTIL-01 folds −0 into +0", function()
		for _, x in { -0.0, -0.00004, -0.00000001, -1e-300 } do
			local got = q(x)
			A.eq(got, 0)
			A.eq(1 / got, math.huge, string.format("q(%.17g) is +0", x))
		end
	end)

	t.it("T-UTIL-01 errors on non-finite input, |round(x · scale)| ≥ 2^51 and bad scales", function()
		A.throws(function()
			q(0 / 0)
		end, "non-finite")
		A.throws(function()
			q(math.huge)
		end, "non-finite")
		A.throws(function()
			q(-math.huge)
		end, "non-finite")
		A.throws(function()
			q(LIMIT / S)
		end, "2^51")
		A.throws(function()
			q(-LIMIT / S)
		end, "2^51")
		A.throws(function()
			q(1e305) -- the product overflows
		end, "2^51")
		for _, scale in { 0, -1, 0 / 0, math.huge } do
			A.throws(function()
				Quantize.q(1, scale)
			end, "scale")
		end
		A.throws(function()
			(Quantize.q :: any)("1", S)
		end, "non-finite")
		-- just below the limit is accepted and still idempotent
		local x = (LIMIT - 1) / S
		local y = q(x)
		A.truthy(same(q(y), y), "idempotent just below 2^51")
	end)

	t.it("T-UTIL-01 at the top of the range every x is refused or has q(q(x)) == q(x)", function()
		-- refused, or accepted with an idempotent result: never accepted with a result that q itself refuses
		local function refusedOrIdempotent(x: number)
			local ok, y = pcall(q, x)
			if not ok then
				return
			end
			local ok2, z = pcall(q, y)
			A.truthy(ok2 and same(z, y), string.format("q(%.17g) = %.17g is accepted but q of it is not the same", x, y))
		end
		-- x · 1e4 = 2^51 − 0.25 rounds to the grid index 2^51 (measured: 225179981368.52478 · 1e4 =
		-- 2251799813685247.8), so q refuses it rather than return a value that it would then refuse
		for _, x in { (LIMIT - 0.25) / S, 225179981368.52478 } do
			refusedOrIdempotent(x)
			refusedOrIdempotent(-x)
			A.throws(function()
				q(x)
			end, "2^51")
		end
		-- a sweep across the edge, both signs, in steps of 1/16 of a grid index
		for i = 0, 4096 do
			refusedOrIdempotent((LIMIT - i / 16) / S)
			refusedOrIdempotent(-(LIMIT - i / 16) / S)
		end
	end)

	t.it("T-UTIL-01 idempotent bit for bit, on the grid, within half a step (PROP_N values)", function()
		Prop.check(Tol.PROP_N, value, function(x: number)
			local y = q(x)
			A.finite(y)
			A.truthy(same(q(y), y), string.format("q(q(x)) == q(x) for x = %.17g", x))
			A.eq(math.round(y * S), math.round(x * S), "q(x) · 1e4 recovers the grid index")
			A.truthy(math.abs(y - x) <= 0.5 / S + math.abs(x) * 4e-16, string.format("|q(x) − x| ≤ 5e-5 for x = %.17g", x))
			A.truthy(same(q(x), y), "P-DET: same input, same bits")
		end)
	end)

	t.it("T-UTIL-01 monotone: x ≤ x' ⇒ q(x) ≤ q(x') (PROP_N sorted lists)", function()
		Prop.check(Tol.PROP_N, function(rng: TestRng): { number }
			local xs: { number } = {}
			for i = 1, 20 do
				xs[i] = value(rng)
			end
			table.sort(xs)
			return xs
		end, function(xs: { number })
			for i = 2, #xs do
				A.truthy(q(xs[i - 1]) <= q(xs[i]), string.format("q(%.17g) ≤ q(%.17g)", xs[i - 1], xs[i]))
			end
		end)
	end)

	t.slow("T-UTIL-01 idempotent on 10^6 values up to 2^51 / scale", function()
		local rng = TestRng.new(Tol.PROP_BASE_SEED)
		for _ = 1, 1000000 do
			local x = (rng:float() * 2 - 1) * (LIMIT - 1) / S * rng:float()
			local y = q(x)
			if not same(q(y), y) then
				A.fail(string.format("q not idempotent at x = %.17g", x))
			end
		end
	end)
end)
