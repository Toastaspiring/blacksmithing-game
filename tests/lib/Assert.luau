--!strict
-- tests/lib/Assert.luau — assertions (SPEC §14.3). Every failure raises a message containing "assert: ", which the
-- runner reports as FAIL; any other error is reported as ERROR (a crash).

local Dump = require("./Dump")

local A = {}

local function fail(msg: string): never
	error("assert: " .. msg, 3)
end

local function label(msg: string?): string
	return if msg then msg .. ": " else ""
end

function A.fail(msg: string): never
	error("assert: " .. msg, 2)
end

function A.truthy(v: any, msg: string?)
	if not v then
		fail(label(msg) .. "expected truthy, got " .. Dump.short(v))
	end
end

function A.falsy(v: any, msg: string?)
	if v then
		fail(label(msg) .. "expected falsy, got " .. Dump.short(v))
	end
end

function A.eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		fail(label(msg) .. "expected " .. Dump.short(expected) .. ", got " .. Dump.short(actual))
	end
end

function A.finite(v: any, msg: string?)
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		fail(label(msg) .. "expected a finite number, got " .. Dump.short(v))
	end
end

-- |actual − expected| <= absTol
function A.near(actual: number, expected: number, absTol: number, msg: string?)
	A.finite(actual, msg)
	if math.abs(actual - expected) > absTol then
		fail(string.format("%sexpected %.17g ± %g, got %.17g (diff %.3g)", label(msg), expected, absTol, actual,
			actual - expected))
	end
end

-- |actual − expected| <= relTol · max(|expected|, 1e-300)
function A.rel(actual: number, expected: number, relTol: number, msg: string?)
	A.finite(actual, msg)
	local scale = math.max(math.abs(expected), 1e-300)
	if math.abs(actual - expected) > relTol * scale then
		fail(string.format("%sexpected %.17g ± %g relative, got %.17g (rel %.3g)", label(msg), expected, relTol,
			actual, (actual - expected) / scale))
	end
end

function A.within(v: number, lo: number, hi: number, msg: string?)
	A.finite(v, msg)
	if v < lo or v > hi then
		fail(string.format("%sexpected in [%.17g, %.17g], got %.17g", label(msg), lo, hi, v))
	end
end

-- Structural equality; numbers compared exactly (bit-identical except −0 == 0).
function A.deepEq(actual: any, expected: any, msg: string?)
	local path = Dump.firstDifference(actual, expected)
	if path then
		fail(label(msg) .. "values differ at " .. path)
	end
end

-- Plain-text substring check.
function A.contains(haystack: string, needle: string, msg: string?)
	if type(haystack) ~= "string" or not string.find(haystack, needle, 1, true) then
		fail(label(msg) .. "expected text containing " .. Dump.quote(needle) .. ", got " .. Dump.short(haystack))
	end
end

-- Expects fn to raise; optional plain-text substring the message must contain. Returns the message.
function A.throws(fn: () -> (), contains: string?, msg: string?): string
	local ok, err = pcall(fn :: any)
	if ok then
		fail(label(msg) .. "expected an error, none raised")
	end
	local text = tostring(err)
	if contains and not string.find(text, contains, 1, true) then
		fail(label(msg) .. "error " .. Dump.quote(text) .. " does not contain " .. Dump.quote(contains))
	end
	return text
end

-- Result-style APIs: { ok = false, code = "..." }.
function A.errCode(result: any, code: string, msg: string?)
	if type(result) ~= "table" or result.ok ~= false then
		fail(label(msg) .. "expected {ok = false, code = " .. code .. "}, got " .. Dump.short(result))
	end
	if result.code ~= code then
		fail(label(msg) .. "expected code " .. code .. ", got " .. Dump.short(result.code))
	end
end

return A
