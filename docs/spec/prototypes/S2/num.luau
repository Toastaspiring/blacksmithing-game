--!strict
-- S2 prototype: deterministic numeric helpers (only + - * / sqrt floor ceil in authoritative paths).
local Num = {}

Num.PI = 3.141592653589793

-- Unit circle table, 32 directions. In the real module these are LITERAL constants
-- (generated offline) so no cos/sin is evaluated at runtime. The prototype computes them once.
Num.CIRCLE_N = 32
Num.COS = table.create(32, 0) :: { number }
Num.SIN = table.create(32, 0) :: { number }
for k = 0, 31 do
	local a = 2 * Num.PI * k / 32
	Num.COS[k + 1] = math.cos(a)
	Num.SIN[k + 1] = math.sin(a)
end

function Num.clamp01(x: number): number
	if x < 0 then
		return 0
	elseif x > 1 then
		return 1
	end
	return x
end

function Num.norm(x: number, lo: number, hi: number): number
	return Num.clamp01((x - lo) / (hi - lo))
end

-- Deterministic cube root: exact power-of-two range reduction + 8 fixed Newton steps.
function Num.cbrt(v: number): number
	if v <= 0 then
		return 0
	end
	local m, k = v, 0
	while m >= 8 do
		m = m / 8
		k += 1
	end
	while m < 1 do
		m = m * 8
		k -= 1
	end
	local x = 1.5
	for _ = 1, 8 do
		x = (2 * x + m / (x * x)) / 3
	end
	if k > 0 then
		for _ = 1, k do
			x = x * 2
		end
	else
		for _ = 1, -k do
			x = x / 2
		end
	end
	return x
end

return Num
