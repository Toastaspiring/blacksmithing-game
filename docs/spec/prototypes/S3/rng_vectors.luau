--!strict
local R = require("./Rng")
local Rng = R.Rng

local function hex(n: number): string
	return string.format("0x%08X", n)
end

print("FNV-1a32('')       =", hex(R.fnv1a32("")))
print("FNV-1a32('a')      =", hex(R.fnv1a32("a")))
print("FNV-1a32('foobar') =", hex(R.fnv1a32("foobar")))
print("FNV-1a32('TimingStrike.Offsets') =", hex(R.fnv1a32("TimingStrike.Offsets")))

-- raw algorithm check against the rand_xoshiro reference vector (state 1,2,3,4)
local raw = Rng.fromState(1, 2, 3, 4)
local out = {}
for i = 1, 10 do
	out[i] = tostring(raw:nextU32())
end
print("xoshiro128** state(1,2,3,4):", table.concat(out, ", "))

local function vec(seed: number, tag: string)
	local r = Rng.new(seed, tag)
	local st = { hex(r.s0), hex(r.s1), hex(r.s2), hex(r.s3) }
	local u = {}
	for i = 1, 6 do
		u[i] = tostring(r:nextU32())
	end
	local f = {}
	for i = 1, 2 do
		f[i] = string.format("%.17g", r:nextFloat())
	end
	print(string.format("seed=%d tag=%q state=[%s]", seed, tag, table.concat(st, " ")))
	print("   u32[1..6] =", table.concat(u, ", "))
	print("   then nextFloat x2 =", table.concat(f, ", "))
end

vec(1, "")
vec(3735928559, "")
vec(1, "TimingStrike.Offsets")
vec(3735928559, "TimingStrike.Offsets")

-- int/range sanity + speed
local r = Rng.new(12345, "bench")
local t0 = os.clock()
local acc = 0
for _ = 1, 1000000 do
	acc += r:nextU32()
end
print(string.format("1e6 nextU32 in %.3f s (acc %d)", os.clock() - t0, acc % 1000))
local hist = { 0, 0, 0, 0, 0, 0 }
for _ = 1, 600000 do
	local k = r:int(1, 6)
	hist[k] += 1
end
print("int(1,6) histogram:", table.concat(hist, " "))
