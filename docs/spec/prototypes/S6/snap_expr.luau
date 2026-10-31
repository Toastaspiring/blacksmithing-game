--!strict
-- S6 prototype: snapping helpers + numeric-field expression parser (pure Luau).
-- Run: lune run snap_expr.luau

local Snap = {}

-- Clean float noise from snapped/typed values: nearest double to the 9-decimal value.
function Snap.clean(v: number): number
	if math.abs(v) >= 1e6 then
		return v
	end
	local r = math.floor(v * 1e9 + 0.5) / 1e9
	return r
end

-- Relative snapping: the delta is a multiple of inc.
function Snap.delta(delta: number, inc: number): number
	return Snap.clean(math.floor(delta / inc + 0.5) * inc)
end

-- Absolute snapping: the resulting coordinate is a multiple of inc.
function Snap.absolute(start: number, delta: number, inc: number): number
	local target = start + delta
	return Snap.clean(math.floor(target / inc + 0.5) * inc) - start
end

-- ---------------------------------------------------------------- expression parser
-- grammar: input := [op '='] expr [unit]
--          expr := term (('+'|'-') term)* ; term := unary (('*'|'/') unary)* ;
--          unary := ('+'|'-') unary | primary ; primary := number | '(' expr ')'
-- number: digits with '.' or ',' decimal separator; units ignored: deg, °, st, studs
export type ParseResult = { ok: true, value: number, op: string? } | { ok: false, err: string }

local MAX_LEN = 64

local function parse(text: string): ParseResult
	if #text > MAX_LEN then
		return { ok = false, err = "TooLong" }
	end
	local s = string.lower(text)
	s = string.gsub(s, "%s+", "")
	s = string.gsub(s, "°", "")
	s = string.gsub(s, "studs$", "")
	s = string.gsub(s, "st$", "")
	s = string.gsub(s, "deg$", "")
	s = string.gsub(s, ",", ".")
	local op: string? = nil
	local first2 = string.sub(s, 1, 2)
	if first2 == "+=" or first2 == "-=" or first2 == "*=" or first2 == "/=" then
		op = string.sub(s, 1, 1)
		s = string.sub(s, 3)
	end
	local pos = 1
	local function peek(): string
		return string.sub(s, pos, pos)
	end
	local expr: () -> number?
	local function primary(): number?
		local c = peek()
		if c == "(" then
			pos += 1
			local v = expr()
			if v == nil or peek() ~= ")" then
				return nil
			end
			pos += 1
			return v
		end
		local num = string.match(s, "^%d+%.%d*", pos) or string.match(s, "^%.%d+", pos) or string.match(s, "^%d+", pos)
		if num == nil or num == "" or num == "." then
			return nil
		end
		pos += #num
		return tonumber(num)
	end
	local function unary(): number?
		local c = peek()
		if c == "-" then
			pos += 1
			local v = unary()
			return if v then -v else nil
		elseif c == "+" then
			pos += 1
			return unary()
		end
		return primary()
	end
	local function term(): number?
		local v = unary()
		while v ~= nil do
			local c = peek()
			if c == "*" or c == "/" then
				pos += 1
				local r = unary()
				if r == nil then
					return nil
				end
				v = if c == "*" then v * r else v / r
			else
				break
			end
		end
		return v
	end
	expr = function(): number?
		local v = term()
		while v ~= nil do
			local c = peek()
			if c == "+" or c == "-" then
				pos += 1
				local r = term()
				if r == nil then
					return nil
				end
				v = if c == "+" then v + r else v - r
			else
				break
			end
		end
		return v
	end
	local v = expr()
	if v == nil or pos <= #s then
		return { ok = false, err = "Syntax" }
	end
	if v ~= v or v == math.huge or v == -math.huge then
		return { ok = false, err = "NotFinite" }
	end
	return { ok = true, value = Snap.clean(v), op = op }
end

-- ---------------------------------------------------------------- tests
local cases = {
	"0.25", "1/8", "0,5", ".5", "5.", "2*(0.1+0.05)", "-0.3", "+=0.125", "-=1/16", "*=2", "/=3",
	"15°", "22.5 deg", "0.4 st", "1/0", "abc", "1..2", "((1)", "-(-2)", "3e2",
}
print("expression parser:")
for _, c in cases do
	local r = parse(c)
	if r.ok then
		print(string.format("  %-14s -> %.10g %s", c, r.value, r.op and ("(op " .. r.op .. "=)") or ""))
	else
		print(string.format("  %-14s -> error %s", c, r.err))
	end
end

print("\nfloat hygiene (absolute snap to 0.1, start 0):")
for i = 1, 7 do
	local raw = math.floor((0.1 * i) / 0.1 + 0.5) * 0.1
	local cleaned = Snap.absolute(0, 0.1 * i, 0.1)
	print(string.format("  i=%d raw=%.17g cleaned=%.17g equalsTyped=%s", i, raw, cleaned, tostring(cleaned == tonumber(string.format("%.1f", 0.1 * i)))))
end

print("\nrelative vs absolute (start 0.3, inc 0.25):")
for _, d in { 0.1, 0.2, 0.4, 0.6, -0.2 } do
	print(string.format("  drag %.2f -> relative lands %.4f, absolute lands %.4f", d, 0.3 + Snap.delta(d, 0.25), 0.3 + Snap.absolute(0.3, d, 0.25)))
end

-- float noise at a hitbox boundary (scale-snapped size 3 x 0.1, centre 2.35, hitbox max 2.5)
local rawSize = math.floor(0.3 / 0.1 + 0.5) * 0.1
local cleanSize = Snap.clean(rawSize)
print(string.format("\nraw size %.17g -> max face %.17g (<= 2.5? %s)", rawSize, 2.35 + rawSize / 2, tostring(2.35 + rawSize / 2 <= 2.5)))
print(string.format("clean size %.17g -> max face %.17g (<= 2.5? %s)", cleanSize, 2.35 + cleanSize / 2, tostring(2.35 + cleanSize / 2 <= 2.5)))
local c3 = 0.1 + 0.2
print(string.format("0.1+0.2 = %.17g ; exceeds 0.3 by %.3g -> containment must use an epsilon", c3, c3 - 0.3))
