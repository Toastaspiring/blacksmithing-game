--!strict
-- Minigames/Rng (SPEC §6.3, §16.19, E-S3.1; owner S3): the minigames' only randomness. xoshiro128** 1.1 (four u32
-- words, period 2^128 − 1), seeded by SplitMix32 from the server's u32 seed, one stream per tag (FNV-1a 32 of the
-- tag); plus the FNV-1a step the pattern hashes use. Pure; every value is bit-identical in Lune, Studio and clients.
--
--   Rng.new(seed, tag?)   x = seed ⊕ fnv1a32(tag or ""); four times x = (x + GAMMA) mod 2^32, s_i = fmix32(x)
--   r:nextU32()           xoshiro128** 1.1          r:nextFloat()  u32 / 2^32, in [0, 1)
--   r:range(lo, hi)       lo + (hi − lo)·nextFloat, in [lo, hi)
--   r:int(lo, hi)         lo + floor(nextFloat·(hi − lo + 1)), inclusive
--   r:chance(p)           nextFloat < p            r:sign()       −1 when nextFloat < 0.5, else 1
--   Rng.hashU32(h, v)     one FNV-1a step over v's four bytes, little-endian: a pattern hashes its words in order
--                         from FNV_BASIS (§6.3 "FNV-1a over u32 little-endian words")
--
-- Integer arithmetic inside §6.4's whitelist: every intermediate is a non-negative integer below 2^53, so it is
-- exact, and the reductions §6.3 writes with `%` are mod(x, m) = x − floor(x / m)·m (for m = 2^16 and 2^32, the
-- division, floor, product and difference are each exact; Luau's `%` is the same expression). bit32 only ever gets
-- values already in [0, 2^32). The expressions follow the S3 prototype term by term (docs/spec/prototypes/S3/v2/
-- Rng.luau), which made E-S3's vectors, hashes and distributions. Renaming a tag changes every pattern: a BALANCE
-- change (§6.3), pinned by T-MG-13's hashes.

local band, bxor, rshift, lshift, lrotate = bit32.band, bit32.bxor, bit32.rshift, bit32.lshift, bit32.lrotate

local M32 = 4294967296 -- 2^32

local FNV_BASIS = 0x811C9DC5
local FNV_PRIME = 0x01000193
local RNG_SPLITMIX_GAMMA = 0x9E3779B9
local RNG_FMIX_C1 = 0x85EBCA6B
local RNG_FMIX_C2 = 0xC2B2AE35

export type Rng = {
	s0: number,
	s1: number,
	s2: number,
	s3: number,
	nextU32: (self: Rng) -> number,
	nextFloat: (self: Rng) -> number,
	range: (self: Rng, lo: number, hi: number) -> number,
	int: (self: Rng, lo: number, hi: number) -> number,
	chance: (self: Rng, p: number) -> boolean,
	sign: (self: Rng) -> number,
}

-- x mod m for an integer 0 ≤ x < 2^53 and m a power of two up to 2^32: exact
local function mod(x: number, m: number): number
	return x - math.floor(x / m) * m
end

local function isU32(v: any): boolean
	return type(v) == "number" and v >= 0 and v < M32 and math.floor(v) == v
end

-- (a · b) mod 2^32 for a, b in [0, 2^32): a splits into 16-bit halves, so ah·b < 2^48 and the sum < 2^49
local function mul32(a: number, b: number): number
	local ah = rshift(a, 16)
	local al = band(a, 0xFFFF)
	local hi = mod(ah * b, 65536)
	return mod(hi * 65536 + al * b, M32)
end

-- FNV-1a 32 over the bytes of s
local function fnv1a32(s: string): number
	local h = FNV_BASIS
	for i = 1, #s do
		h = mul32(bxor(h, string.byte(s, i)), FNV_PRIME)
	end
	return h
end

-- MurmurHash3's fmix32 finalizer (a bijection on u32)
local function fmix32(z: number): number
	z = mul32(bxor(z, rshift(z, 16)), RNG_FMIX_C1)
	z = mul32(bxor(z, rshift(z, 13)), RNG_FMIX_C2)
	return bxor(z, rshift(z, 16))
end

-- one FNV-1a step per byte of the u32 v, low byte first
local function hashU32(h: number, v: number): number
	if not (isU32(h) and isU32(v)) then
		error(string.format("Rng.hashU32: h and v must be u32 integers, got %s and %s", tostring(h), tostring(v)), 2)
	end
	for _ = 1, 4 do
		h = mul32(bxor(h, band(v, 0xFF)), FNV_PRIME)
		v = rshift(v, 8)
	end
	return h
end

local methods = {}

-- xoshiro128** 1.1 (Blackman and Vigna): one u32
function methods.nextU32(self: Rng): number
	local s0, s1, s2, s3 = self.s0, self.s1, self.s2, self.s3
	local result = mod(lrotate(mod(s1 * 5, M32), 7) * 9, M32)
	local t = lshift(s1, 9)
	s2 = bxor(s2, s0)
	s3 = bxor(s3, s1)
	s1 = bxor(s1, s2)
	s0 = bxor(s0, s3)
	s2 = bxor(s2, t)
	s3 = lrotate(s3, 11)
	self.s0, self.s1, self.s2, self.s3 = s0, s1, s2, s3
	return result
end

-- [0, 1) at 2^-32 resolution; the division by a power of two is exact
function methods.nextFloat(self: Rng): number
	return self:nextU32() / M32
end

function methods.range(self: Rng, lo: number, hi: number): number
	return lo + (hi - lo) * self:nextFloat()
end

-- inclusive; the bias, at most (hi − lo + 1)/2^32, is irrelevant below 2^20 values
function methods.int(self: Rng, lo: number, hi: number): number
	return lo + math.floor(self:nextFloat() * (hi - lo + 1))
end

function methods.chance(self: Rng, p: number): boolean
	return self:nextFloat() < p
end

function methods.sign(self: Rng): number
	return if self:nextFloat() < 0.5 then -1 else 1
end

-- the instances' metatable: shared and frozen; each instance keeps its own four words
local INSTANCE = table.freeze({ __index = table.freeze(methods) })

local Rng = {
	FNV_BASIS = FNV_BASIS,
	FNV_PRIME = FNV_PRIME,
	RNG_SPLITMIX_GAMMA = RNG_SPLITMIX_GAMMA,
	RNG_FMIX_C1 = RNG_FMIX_C1,
	RNG_FMIX_C2 = RNG_FMIX_C2,
	-- the pattern streams (§6.3); renaming one is a BALANCE change
	TAGS = table.freeze({
		HoldZoneTarget = "HoldZone.Target",
		TimingStrikeTempo = "TimingStrike.Tempo",
		TimingStrikeOffsets = "TimingStrike.Offsets",
		PrecisionTracePerturb = "PrecisionTrace.Perturb",
	}),
	mul32 = mul32,
	fnv1a32 = fnv1a32,
	fmix32 = fmix32,
	hashU32 = hashU32,
}

-- seed: the server's u32 (bit32 would silently wrap or truncate anything else, so it is refused); tag: the stream,
-- nil ≡ "". fmix32 is a bijection and the four Weyl inputs differ, so at most one word is 0, never all four.
function Rng.new(seed: number, tag: string?): Rng
	if not isU32(seed) then
		error("Rng.new: seed must be a u32 integer in [0, 2^32), got " .. tostring(seed), 2)
	end
	if tag ~= nil and type(tag) ~= "string" then
		error("Rng.new: tag must be a string or nil, got " .. type(tag), 2)
	end
	local x = bxor(seed, fnv1a32(tag or ""))
	x = mod(x + RNG_SPLITMIX_GAMMA, M32)
	local s0 = fmix32(x)
	x = mod(x + RNG_SPLITMIX_GAMMA, M32)
	local s1 = fmix32(x)
	x = mod(x + RNG_SPLITMIX_GAMMA, M32)
	local s2 = fmix32(x)
	x = mod(x + RNG_SPLITMIX_GAMMA, M32)
	local s3 = fmix32(x)
	return (setmetatable({ s0 = s0, s1 = s1, s2 = s2, s3 = s3 }, INSTANCE) :: any) :: Rng
end

-- A raw xoshiro128** state (tests: the reference vectors); four u32 words, not all 0.
function Rng.fromState(s0: number, s1: number, s2: number, s3: number): Rng
	if not (isU32(s0) and isU32(s1) and isU32(s2) and isU32(s3)) then
		error("Rng.fromState: the state words must be u32 integers", 2)
	end
	if s0 == 0 and s1 == 0 and s2 == 0 and s3 == 0 then
		error("Rng.fromState: the all-zero state never leaves 0", 2)
	end
	return (setmetatable({ s0 = s0, s1 = s1, s2 = s2, s3 = s3 }, INSTANCE) :: any) :: Rng
end

return table.freeze(Rng)
