--!strict
-- tests/lib/TestRng.luau — test-only PRNG for generators and bots (SPEC §14.3). Independent of
-- src/shared/Minigames/Rng, so changing the game PRNG never changes fuzz inputs. xorshift32 (13/17/5) plus an
-- Irwin–Hall normal: no transcendental functions, so streams are identical on every machine. Pure Luau.

export type TestRng = {
	state: number,
	u32: (self: TestRng) -> number,
	float: (self: TestRng) -> number, -- [0, 1)
	range: (self: TestRng, lo: number, hi: number) -> number, -- [lo, hi)
	int: (self: TestRng, lo: number, hi: number) -> number, -- inclusive
	normal: (self: TestRng, mean: number, sd: number) -> number,
	pick: <T>(self: TestRng, list: { T }) -> T,
	fork: (self: TestRng, salt: number) -> TestRng,
}

local TestRng = {}
local methods = {}
local mt = { __index = methods }

-- Any number is accepted; the seed is reduced to 32 bits and 0 (a fixed point of xorshift) is remapped.
function TestRng.new(seed: number): TestRng
	local s = bit32.band(seed, 0xFFFFFFFF)
	if s == 0 then
		s = 0x6D2B79F5
	end
	return (setmetatable({ state = s }, mt) :: any) :: TestRng
end

function methods.u32(self: TestRng): number
	local x = self.state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self.state = x
	return x
end

function methods.float(self: TestRng): number
	return self:u32() / 4294967296
end

function methods.range(self: TestRng, lo: number, hi: number): number
	return lo + (hi - lo) * self:float()
end

function methods.int(self: TestRng, lo: number, hi: number): number
	return lo + (self:u32() % (hi - lo + 1)) -- the small modulo bias does not matter for tests
end

-- Irwin–Hall(12) − 6 ≈ N(0, 1), bounded at ±6σ by construction.
function methods.normal(self: TestRng, mean: number, sd: number): number
	local s = 0
	for _ = 1, 12 do
		s += self:float()
	end
	return mean + sd * (s - 6)
end

function methods.pick<T>(self: TestRng, list: { T }): T
	return list[self:int(1, #list)]
end

function methods.fork(self: TestRng, salt: number): TestRng
	return TestRng.new(bit32.bxor(self:u32(), bit32.band(salt * 0x9E3779B1, 0xFFFFFFFF)))
end

return TestRng
