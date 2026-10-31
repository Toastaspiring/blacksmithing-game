--!strict
-- PROTOTYPE stand-in for S3's Minigames/Rng (algorithm choice belongs to S3).
-- xorshift32 (Marsaglia 2003, shifts 13/17/5), period 2^32-1, bit32 only.

export type Rng = { state: number }

local Rng = {}

local SEED_ZERO_REPLACEMENT = 0x6D2B79F5 -- xorshift has a fixed point at 0

-- bit32 silently maps NaN/inf to 0 and truncates fractions, so validate explicitly.
function Rng.isValidSeed(seed: any): boolean
	return type(seed) == "number" and seed == seed and seed % 1 == 0 and seed >= 0 and seed <= 0xFFFFFFFF
end

function Rng.new(seed: number): Rng
	if not Rng.isValidSeed(seed) then error("Rng.new: seed must be an integer in [0, 2^32)") end
	return { state = if seed == 0 then SEED_ZERO_REPLACEMENT else seed }
end

function Rng.nextU32(r: Rng): number
	local x = r.state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	r.state = x
	return x
end

-- [0, 1) with 32 bits of resolution
function Rng.nextFloat(r: Rng): number
	return Rng.nextU32(r) / 4294967296
end

-- Unbiased integer in [lo, hi] by rejection sampling.
function Rng.nextInt(r: Rng, lo: number, hi: number): number
	local span = hi - lo + 1
	assert(span >= 1 and span <= 4294967296 and span % 1 == 0, "Rng.nextInt: bad range")
	local limit = 4294967296 - (4294967296 % span)
	local v = Rng.nextU32(r)
	while v >= limit do v = Rng.nextU32(r) end
	return lo + v % span
end

-- Derive an independent sub-stream seed (e.g. one per craft step) from a session seed.
function Rng.derive(seed: number, salt: number): number
	local r = Rng.new(bit32.bxor(seed, bit32.band(salt * 0x9E3779B1, 0xFFFFFFFF)))
	Rng.nextU32(r); Rng.nextU32(r) -- warm-up decorrelates nearby seeds
	return Rng.nextU32(r)
end

return Rng
