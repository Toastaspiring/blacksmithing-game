--!nocheck
-- A small deterministic PRNG (xorshift32 pair), Random-like: NextNumber() in [0, 1), NextInteger(a, b) inclusive.
local R = {}
R.__index = R
function R.new(seed)
	local s = math.floor(seed or 1) % 4294967296
	if s == 0 then s = 0x9E3779B9 end
	local self = setmetatable({ a = s, b = bit32.bxor(s, 0x6C8E9CF5) }, R)
	if self.b == 0 then self.b = 1 end
	for _ = 1, 8 do self:NextNumber() end
	return self
end
local function xs(x)
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	return x
end
function R:NextNumber()
	self.a = xs(self.a)
	self.b = xs(bit32.bxor(self.b, 0x2545F491))
	local hi = bit32.rshift(self.a, 5) -- 27 bits
	local lo = bit32.rshift(self.b, 6) -- 26 bits
	return (hi * 67108864 + lo) / 9007199254740992
end
function R:NextInteger(a, b)
	return a + math.floor(self:NextNumber() * (b - a + 1))
end
return R
