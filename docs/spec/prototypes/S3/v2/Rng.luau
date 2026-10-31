--!strict
-- S3 prototype: pure-Luau 32-bit PRNG (xoshiro128** 1.1), seeded by SplitMix32, streams by FNV-1a tag.
-- Only bit32 + exact integer arithmetic (< 2^53) is used, so results are bit-identical everywhere.

local M32 = 4294967296 -- 2^32

local band, bxor, rshift, lshift, lrotate = bit32.band, bit32.bxor, bit32.rshift, bit32.lshift, bit32.lrotate

-- (a * b) mod 2^32 for a, b in [0, 2^32). Splits a into 16-bit halves so every partial product is < 2^49 (exact).
local function mul32(a: number, b: number): number
	local ah = rshift(a, 16)
	local al = band(a, 0xFFFF)
	return ((ah * b) % 65536 * 65536 + al * b) % M32
end

-- FNV-1a 32-bit over the bytes of a string.
local function fnv1a32(s: string): number
	local h = 0x811C9DC5
	for i = 1, #s do
		h = mul32(bxor(h, string.byte(s, i)), 0x01000193)
	end
	return h
end

-- MurmurHash3 fmix32 finalizer (bijective on u32).
local function fmix32(z: number): number
	z = mul32(bxor(z, rshift(z, 16)), 0x85EBCA6B)
	z = mul32(bxor(z, rshift(z, 13)), 0xC2B2AE35)
	return bxor(z, rshift(z, 16))
end

export type RngState = { s0: number, s1: number, s2: number, s3: number }

local Rng = {}
Rng.__index = Rng

export type Rng = typeof(setmetatable({} :: RngState, Rng))

-- seed: u32 from the server. tag: purpose string (sub-stream), "" allowed.
function Rng.new(seed: number, tag: string?): Rng
	assert(seed == math.floor(seed) and seed >= 0 and seed < M32, "seed must be a u32")
	local x = bxor(seed, fnv1a32(tag or ""))
	local s = {}
	for i = 1, 4 do
		x = (x + 0x9E3779B9) % M32 -- Weyl step (SplitMix32)
		s[i] = fmix32(x)
	end
	-- fmix32 is a bijection and the 4 Weyl inputs are distinct, so at most one word can be 0: never all-zero.
	return setmetatable({ s0 = s[1], s1 = s[2], s2 = s[3], s3 = s[4] }, Rng)
end

function Rng.fromState(s0: number, s1: number, s2: number, s3: number): Rng
	return setmetatable({ s0 = s0, s1 = s1, s2 = s2, s3 = s3 }, Rng)
end

-- xoshiro128** 1.1 (Blackman & Vigna). Returns u32.
function Rng.nextU32(self: Rng): number
	local s0, s1, s2, s3 = self.s0, self.s1, self.s2, self.s3
	local result = (lrotate((s1 * 5) % M32, 7) * 9) % M32
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

-- [0, 1) with 2^-32 resolution; division by a power of two is exact.
function Rng.nextFloat(self: Rng): number
	return self:nextU32() / M32
end

-- uniform float in [lo, hi)
function Rng.range(self: Rng, lo: number, hi: number): number
	return lo + (hi - lo) * self:nextFloat()
end

-- uniform integer in [lo, hi] (inclusive). Bias <= (hi-lo+1)/2^32, irrelevant for n < 2^20.
function Rng.int(self: Rng, lo: number, hi: number): number
	return lo + math.floor(self:nextFloat() * (hi - lo + 1))
end

function Rng.chance(self: Rng, p: number): boolean
	return self:nextFloat() < p
end

function Rng.sign(self: Rng): number
	return if self:nextFloat() < 0.5 then -1 else 1
end

return {
	Rng = Rng,
	mul32 = mul32,
	fnv1a32 = fnv1a32,
	fmix32 = fmix32,
	M32 = M32,
}
