--!strict
-- tests/lib/Assert.luau — tiny assertion helper. Every failure raises a string that
-- starts with "assert:" so the runner can tell assertion failures from crashes.
-- PROTOTYPE (S8).

local Dump = require("./Dump")

local A = {}

local function fail(msg: string, level: number?): never
	error("assert: " .. msg, (level or 1) + 2)
end

local function label(msg: string?): string
	return if msg then msg .. ": " else ""
end

function A.fail(msg: string): never
	fail(msg)
end

function A.truthy(v: any, msg: string?)
	if not v then fail(label(msg) .. "expected truthy, got " .. Dump.short(v)) end
end

function A.falsy(v: any, msg: string?)
	if v then fail(label(msg) .. "expected falsy, got " .. Dump.short(v)) end
end

function A.eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		fail(label(msg) .. "expected " .. Dump.short(expected) .. ", got " .. Dump.short(actual))
	end
end

function A.finite(v: any, msg: string?)
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		fail(label(msg) .. "expected finite number, got " .. Dump.short(v))
	end
end

-- |actual - expected| <= absTol
function A.near(actual: number, expected: number, absTol: number, msg: string?)
	A.finite(actual, msg)
	if math.abs(actual - expected) > absTol then
		fail(string.format("%sexpected %.17g ± %g, got %.17g (diff %.3g)", label(msg), expected, absTol, actual, actual - expected))
	end
end

-- |actual - expected| <= relTol * max(|expected|, 1e-300)
function A.rel(actual: number, expected: number, relTol: number, msg: string?)
	A.finite(actual, msg)
	local scale = math.max(math.abs(expected), 1e-300)
	if math.abs(actual - expected) > relTol * scale then
		fail(string.format("%sexpected %.17g ±%g%%, got %.17g (rel %.3g)", label(msg), expected, relTol * 100, actual, (actual - expected) / scale))
	end
end

function A.within(v: number, lo: number, hi: number, msg: string?)
	A.finite(v, msg)
	if v < lo or v > hi then
		fail(string.format("%sexpected in [%.17g, %.17g], got %.17g", label(msg), lo, hi, v))
	end
end

-- Structural equality; numbers compared exactly (bit-identical except -0 == +0).
function A.deepEq(actual: any, expected: any, msg: string?)
	local path = Dump.firstDifference(actual, expected)
	if path then fail(label(msg) .. "values differ at " .. path) end
end

-- Expects fn to raise; optional plain-text substring the message must contain.
function A.throws(fn: () -> (), contains: string?, msg: string?)
	local ok, err = pcall(fn)
	if ok then fail(label(msg) .. "expected an error, none raised") end
	if contains and not string.find(tostring(err), contains, 1, true) then
		fail(label(msg) .. "error '" .. tostring(err) .. "' does not contain '" .. contains .. "'")
	end
end

-- For result-style APIs: { ok = false, code = "..." }
function A.errCode(result: any, code: string, msg: string?)
	if type(result) ~= "table" or result.ok ~= false then
		fail(label(msg) .. "expected {ok=false, code=" .. code .. "}, got " .. Dump.short(result))
	end
	if result.code ~= code then
		fail(label(msg) .. "expected code " .. code .. ", got " .. tostring(result.code))
	end
end

return A
