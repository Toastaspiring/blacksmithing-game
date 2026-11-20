--!strict
-- Minigames/Rng (SPEC §6.3, §16.19; T-RNG-01…06, E-S3.1, E-S8.5). T-RNG-01's vectors are E-S3.1's, cross-checked bit
-- for bit against the independent Python reference (docs/spec/prototypes/S3/rng_ref.py), plus the tagged streams'
-- states and floats, seeds 0 and 2^32 − 1, mul32 and hashU32 cases, the four game tags and the helper vectors of one
-- HoldZone stream, re-derived from big integers for M4's plan (.build-notes/m4-plan/measure/, critic-b/). E-S8.5's
-- "vectors from kat/" names S8's xorshift32 stand-in, superseded by S3's xoshiro128** (the plan's I1).
-- The χ² cases are fixed streams, so each is pass or fail per code version (§14.8); for an exact port every outcome is
-- known (critic B's rng_check: T-RNG-04's largest χ² 30.87, int(1, 16) 22.50, the fast cases 16.37; T-RNG-06's 28.20),
-- so a failure is a stream or `int` bug, never a re-seed.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Tol = require("../lib/Tol")
local Rng = require("../../src/shared/Minigames/Rng")

type Rng = Rng.Rng

local M32 = 4294967296
local GAME_TAGS = { "HoldZone.Target", "TimingStrike.Tempo", "TimingStrike.Offsets", "PrecisionTrace.Perturb" }
local TAGS = { "", "HoldZone.Target", "TimingStrike.Tempo", "TimingStrike.Offsets", "PrecisionTrace.Perturb" }
local N = 160000 -- draws per χ² stream (T-RNG-04, 06)
local N_FAST = 16000

local function state(r: Rng): { number }
	return { r.s0, r.s1, r.s2, r.s3 }
end

local function u32s(r: Rng, n: number): { number }
	local out: { number } = {}
	for i = 1, n do
		out[i] = r:nextU32()
	end
	return out
end

-- Pearson's χ² of counts against a uniform expectation over #counts cells
local function chi2(counts: { number }, n: number): number
	local e = n / #counts
	local s = 0
	for _, c in ipairs(counts) do
		s += (c - e) * (c - e) / e
	end
	return s
end

-- T-RNG-04: the top 4 bits of n draws into 16 buckets
local function topBits(seed: number, tag: string, n: number): number
	local r = Rng.new(seed, tag)
	local counts = table.create(16, 0)
	for _ = 1, n do
		local b = bit32.rshift(r:nextU32(), 28) + 1
		counts[b] += 1
	end
	return chi2(counts, n)
end

-- T-RNG-06: 4 × 4 cells from the top 2 bits of paired draws
local function pairs2d(xs: { number }, ys: { number }): number
	local counts = table.create(16, 0)
	for i = 1, #xs do
		local c = bit32.rshift(xs[i], 30) * 4 + bit32.rshift(ys[i], 30) + 1
		counts[c] += 1
	end
	return chi2(counts, #xs)
end

return Test.suite("Minigames/Rng", function(t)
	-- ── T-RNG-01 vectors ─────────────────────────────────────────────────────────────────────────────────────

	t.it("T-RNG-01 FNV-1a 32: published vectors and the four game tags; §16.19's constants", function()
		A.eq(Rng.fnv1a32(""), 0x811C9DC5)
		A.eq(Rng.fnv1a32("a"), 0xE40C292C)
		A.eq(Rng.fnv1a32("foobar"), 0xBF9CF968)
		A.eq(Rng.fnv1a32("TimingStrike.Offsets"), 0xBDE3CD3F)
		A.eq(Rng.fnv1a32("HoldZone.Target"), 0x364C5DC9)
		A.eq(Rng.fnv1a32("TimingStrike.Tempo"), 0x6AE6E414)
		A.eq(Rng.fnv1a32("PrecisionTrace.Perturb"), 0xCE7A16CE)
		A.eq(Rng.FNV_BASIS, 0x811C9DC5)
		A.eq(Rng.FNV_PRIME, 0x01000193)
		A.eq(Rng.RNG_SPLITMIX_GAMMA, 0x9E3779B9)
		A.eq(Rng.RNG_FMIX_C1, 0x85EBCA6B)
		A.eq(Rng.RNG_FMIX_C2, 0xC2B2AE35)
		A.deepEq(Rng.TAGS, {
			HoldZoneTarget = "HoldZone.Target",
			TimingStrikeTempo = "TimingStrike.Tempo",
			TimingStrikeOffsets = "TimingStrike.Offsets",
			PrecisionTracePerturb = "PrecisionTrace.Perturb",
		}, "§6.3's tags")
	end)

	t.it("T-RNG-01 mul32 and hashU32", function()
		A.eq(Rng.mul32(0xFFFFFFFF, 0xFFFFFFFF), 1, "the largest product (2^64 − 2^33 + 1)")
		A.eq(Rng.mul32(0x80000000, 2), 0)
		A.eq(Rng.mul32(0x01000193, 0x811C9DC5), 84696351)
		A.eq(Rng.mul32(123456789, 987654321), 4227814277)
		A.eq(Rng.mul32(0, 0xFFFFFFFF), 0)
		A.eq(Rng.hashU32(Rng.FNV_BASIS, 0), 0x4B95F515)
		A.eq(Rng.hashU32(Rng.FNV_BASIS, 0xDEADBEEF), 0x90879FCB)
		-- hashU32 is FNV-1a over the word's bytes, low byte first
		A.eq(Rng.hashU32(Rng.FNV_BASIS, 0x64636261), Rng.fnv1a32("abcd"), "little-endian bytes")
	end)

	t.it("T-RNG-01 raw xoshiro128** 1.1 from state (1, 2, 3, 4)", function()
		A.deepEq(u32s(Rng.fromState(1, 2, 3, 4), 10), {
			11520, 0, 5927040, 70819200, 2031721883, 1637235492, 1287239034, 3734860849, 3729100597, 4258142804,
		})
	end)

	t.it("T-RNG-01 seeded streams: states, u32s and floats (E-S3.1)", function()
		local cases: { { any } } = {
			{ 1, "", { 0x283F5546, 0xD3E69993, 0xE0DFBA52, 0xF9D93A6F },
				{ 3296685081, 292216795, 3203276040, 3343330025, 3022133357, 443753119 },
				{ 0.7009810614399612, 0.34134213626384735 } },
			{ 3735928559, "", { 0x8D72B72A, 0x53A3D0FD, 0xD068308F, 0x22AE1FC7 },
				{ 3856547673, 1244478788, 63559405, 3329023417, 1418849053, 466841299 },
				{ 0.8987551447935402, 0.7545752725563943 } },
			{ 1, "TimingStrike.Offsets", { 0xC4A92F6A, 0xFC1C82C9, 0x630FE6FF, 0xA1A56D9E },
				{ 2172563110, 3751778701, 3705501078, 924797711, 2910597952, 64598121 },
				{ 0.44087175047025084, 0.931851631263271 } },
			{ 3735928559, "TimingStrike.Offsets", { 0x20BDFADC, 0x84BE86B5, 0x7D60DDAC, 0x97CC1BD1 },
				{ 3201755939, 1102565783, 4063799498, 528979833, 2160534696, 2194535758 },
				{ 0.6990435346961021, 0.9730237319599837 } },
		}
		for _, c in cases do
			local what = string.format("Rng.new(%d, %q)", c[1], c[2])
			local r = Rng.new(c[1], c[2])
			A.deepEq(state(r), c[3], what .. " state")
			A.deepEq(u32s(r, 6), c[4], what .. " u32 × 6")
			-- floats compared as numbers: the literals are the shortest round-trip forms of the doubles
			A.eq(r:nextFloat(), c[5][1], what .. " float 1")
			A.eq(r:nextFloat(), c[5][2], what .. " float 2")
		end
		local r0 = Rng.new(0, "")
		A.deepEq(state(r0), { 0x09CEF78C, 0x79661DE2, 0xEA0EB7EE, 0xE8B2C241 }, "seed 0 state")
		A.deepEq(u32s(r0, 4), { 2040553127, 2671230994, 3535833209, 446703493 }, "seed 0")
		local rMax = Rng.new(4294967295, "")
		A.deepEq(state(rMax), { 0xE7469B4A, 0x67ECDB64, 0x47A974D7, 0xAAEBFA63 }, "seed 2^32 − 1 state")
		A.deepEq(u32s(rMax, 4), { 1363692059, 3358058105, 1851661954, 1516388948 }, "seed 2^32 − 1")
	end)

	t.it("T-RNG-01 helpers on one HoldZone stream: range, int, chance, sign (E-S3.7's first keys follow)", function()
		-- drawn in this order, as HoldZone.generate draws (c0, then a segment: length, hold?, magnitude, sign)
		local r = Rng.new(1, "HoldZone.Target")
		local c = r:range(0.3, 0.7)
		A.eq(c, 0.5807066061533988, "range(0.3, 0.7)")
		A.eq(r:int(900, 2200), 2060, "int(900, 2200)")
		A.eq(r:chance(0.25), false, "chance(0.25)")
		A.eq(r:range(0.5, 1.0), 0.8602050932822749, "range(0.5, 1.0)")
		A.eq(r:sign(), 1, "sign()")
		A.eq(r:int(1, 16), 16, "int(1, 16)")
		-- E-S3.7 (Iron/Normal, x = 0): the first centre 0.40 + 0.40·c = 0.6323 to 4 decimals, the first key at 3000 +
		-- 2060 = 5060 ms
		A.near(0.40 + (0.80 - 0.40) * c, 0.6323, 0.00005, "E-S3.7's first centre")
	end)

	-- ── T-RNG-02 determinism ──────────────────────────────────────────────────────────────────────────────────

	t.it("T-RNG-02 one (seed, tag) gives one stream for every method; nil ≡ \"\"; instances share no state", function()
		local draws: { [string]: (Rng) -> any } = {
			nextU32 = function(r: Rng): any return r:nextU32() end,
			nextFloat = function(r: Rng): any return r:nextFloat() end,
			range = function(r: Rng): any return r:range(-2.5, 7.25) end,
			int = function(r: Rng): any return r:int(-3, 1000) end,
			chance = function(r: Rng): any return r:chance(0.3) end,
			sign = function(r: Rng): any return r:sign() end,
		}
		for _, name in { "nextU32", "nextFloat", "range", "int", "chance", "sign" } do
			local draw = draws[name]
			local a, b = Rng.new(0xC0FFEE, "TimingStrike.Tempo"), Rng.new(0xC0FFEE, "TimingStrike.Tempo")
			for i = 1, 10000 do
				local x, y = draw(a), draw(b)
				if x ~= y then
					A.fail(string.format("%s: draw %d differs: %s ~= %s", name, i, tostring(x), tostring(y)))
				end
			end
		end
		A.deepEq(u32s(Rng.new(77, nil), 1000), u32s(Rng.new(77, ""), 1000), "a nil tag is the empty tag")
		A.deepEq(u32s(Rng.new(77), 1000), u32s(Rng.new(77, ""), 1000), "an omitted tag is the empty tag")
		-- drawing from one instance leaves another's next value unchanged
		local first = Rng.new(5, "HoldZone.Target"):nextU32()
		local r1, r2 = Rng.new(5, "HoldZone.Target"), Rng.new(5, "HoldZone.Target")
		u32s(r1, 100)
		A.eq(r2:nextU32(), first, "r2 untouched by r1's draws")
		-- the tag selects the stream
		A.truthy(Rng.new(5, "HoldZone.Target"):nextU32() ~= Rng.new(5, "TimingStrike.Tempo"):nextU32(), "tags differ")
	end)

	-- ── T-RNG-03 seed validation ──────────────────────────────────────────────────────────────────────────────

	t.it("T-RNG-03 Rng.new refuses every seed that is not a u32 integer; hashU32 and fromState likewise", function()
		local bad: { any } = { 0 / 0, math.huge, -math.huge, -1, -0.5, 1.5, M32, M32 + 1, 2 ^ 53, "1", true, {} }
		for _, seed in bad do
			A.throws(function()
				Rng.new(seed :: any, "")
			end, "u32", "seed " .. tostring(seed))
		end
		A.throws(function()
			Rng.new(nil :: any)
		end, "u32", "a nil seed")
		A.throws(function()
			Rng.new(1, 5 :: any)
		end, "tag must be a string", "a non-string tag")
		for _, seed in { 0, 1, 2, 0x7FFFFFFF, M32 - 1 } do
			A.eq(type(Rng.new(seed, "x"):nextU32()), "number", "seed " .. seed .. " accepted")
		end
		for _, v in { -1, 1.5, M32, 0 / 0 } do
			A.throws(function()
				Rng.hashU32(Rng.FNV_BASIS, v)
			end, "u32", "hashU32 word " .. tostring(v))
		end
		A.throws(function()
			Rng.hashU32(M32, 0)
		end, "u32", "hashU32 state")
		A.throws(function()
			Rng.fromState(1, 2, 3, M32)
		end, "u32", "fromState word")
		A.throws(function()
			Rng.fromState(0, 0, 0, 0)
		end, "all-zero", "fromState all zero")
	end)

	-- ── T-RNG-04 uniformity ───────────────────────────────────────────────────────────────────────────────────

	t.it("T-RNG-04 fast: top 4 bits into 16 buckets, 16,000 draws on two streams, χ² < CHI2_CRIT", function()
		for _, seed in { 1, 2 } do
			local x = topBits(seed, "", N_FAST)
			A.truthy(x < Tol.CHI2_CRIT, string.format("seed %d: χ² %.2f < %.2f", seed, x, Tol.CHI2_CRIT))
		end
	end)

	t.slow("T-RNG-04 top 4 bits into 16 buckets, 160,000 draws per stream, 20 streams; int(1, 16) on 5", function()
		for _, seed in { 1, 2, 3, 0xC0FFEE } do
			for _, tag in TAGS do
				local x = topBits(seed, tag, N)
				A.truthy(x < Tol.CHI2_CRIT, string.format("seed %d tag %q: χ² %.2f < %.2f", seed, tag, x, Tol.CHI2_CRIT))
			end
		end
		-- int(1, 16) uses every value: an off-by-one leaves a bucket empty
		for _, tag in TAGS do
			local r = Rng.new(1, tag)
			local counts = table.create(16, 0)
			for _ = 1, N do
				local k = r:int(1, 16)
				counts[k] += 1
			end
			local x = chi2(counts, N)
			A.truthy(x < Tol.CHI2_CRIT, string.format("int(1, 16) seed 1 tag %q: χ² %.2f < %.2f", tag, x, Tol.CHI2_CRIT))
		end
	end)

	-- ── T-RNG-05 derived tags ─────────────────────────────────────────────────────────────────────────────────

	t.it("T-RNG-05 1,000 derived tags and the 4 game tags: distinct hashes, states and first outputs", function()
		local tags: { string } = {}
		for i = 1, 1000 do
			table.insert(tags, "T-RNG-05/" .. i)
		end
		for _, tag in GAME_TAGS do
			table.insert(tags, tag)
		end
		local hashes: { [number]: string } = {}
		for _, tag in tags do
			local h = Rng.fnv1a32(tag)
			if hashes[h] then
				A.fail(string.format("tags %q and %q share the hash %d", hashes[h], tag, h))
			end
			hashes[h] = tag
		end
		for _, seed in { 0, 1, 0xFFFFFFFF } do
			local states: { [string]: string } = {}
			local firsts: { [number]: string } = {}
			for _, tag in tags do
				local r = Rng.new(seed, tag)
				local key = table.concat(state(r), ",")
				if states[key] then
					A.fail(string.format("seed %d: tags %q and %q start in one state", seed, states[key], tag))
				end
				states[key] = tag
				local first = r:nextU32()
				if firsts[first] then
					A.fail(string.format("seed %d: tags %q and %q share the first output", seed, firsts[first], tag))
				end
				firsts[first] = tag
			end
		end
	end)

	-- ── T-RNG-06 independence ─────────────────────────────────────────────────────────────────────────────────

	t.slow("T-RNG-06 2-D χ² over 4 × 4 cells: game-tag pairs, seed pairs s and s + 1, lag-1 pairs", function()
		local function check(what: string, x: number)
			A.truthy(x < Tol.CHI2_CRIT, string.format("%s: χ² %.2f < %.2f", what, x, Tol.CHI2_CRIT))
		end
		-- every pair of the four game tags, at two seeds (12)
		for _, seed in { 1, 0xDEADBEEF } do
			local streams: { { number } } = {}
			for k, tag in GAME_TAGS do
				streams[k] = u32s(Rng.new(seed, tag), N)
			end
			for i = 1, #GAME_TAGS do
				for j = i + 1, #GAME_TAGS do
					check(string.format("seed %d tags %s | %s", seed, GAME_TAGS[i], GAME_TAGS[j]), pairs2d(streams[i], streams[j]))
				end
			end
		end
		-- one tag at seeds s and s + 1 (15)
		for _, s in { 1, 1000, 0xFFFFFFFE } do
			for _, tag in TAGS do
				check(string.format("seeds %d, %d tag %q", s, s + 1, tag),
					pairs2d(u32s(Rng.new(s, tag), N), u32s(Rng.new(s + 1, tag), N)))
			end
		end
		-- lag 1 inside one stream, on non-overlapping pairs (x1, x2), (x3, x4), …: overlapping pairs are correlated
		-- cells, whose statistic exceeds 37.70 with probability 0.0049, not 0.001 (5)
		for _, tag in TAGS do
			local r = Rng.new(1, tag)
			local xs, ys = table.create(N, 0), table.create(N, 0)
			for i = 1, N do
				xs[i] = r:nextU32()
				ys[i] = r:nextU32()
			end
			check(string.format("lag 1, seed 1 tag %q", tag), pairs2d(xs, ys))
		end
	end)
end)
