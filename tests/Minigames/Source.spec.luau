--!strict
-- Minigames/Source (SPEC §6.4, §14.4, §14.5 P-PURE): §6.4's arithmetic as a whitelist over the authoritative
-- Minigames files (every one but Bots, which may use libm on tagged lines and stays outside §6.4). T-META-03 and 04
-- already ban transcendental prefixes, `^`, native code and keyed accumulation there; this adds what a list of banned
-- prefixes lets through: every `math.` member is one of floor, ceil, round, abs, min, max, clamp, sqrt and huge (so no
-- math.lerp, which a compiler may fuse into one FMA on an ARM64 client, nor fmod, noise or map); no `vector.` (float32);
-- no float buffer reads or writes; no `%`, `//` or their compound forms (integer reductions are x − floor(x/m)·m, I6);
-- every generic `for` iterates `ipairs(...)` and nothing names `pairs` or calls `next` (`next(t)`, `next{}` or
-- `next 'x'`; §6.4 rule 4: arrays in index order, maps looked up, never iterated); no getfenv, setfenv, _G, rawget or
-- rawset, which reach a library around the whitelist (getfenv().math.cos). Planted violations show each rule still
-- bites. Then every module loads under Lune (P-PURE) and returns a deep-frozen table (no module-level state), and the
-- folder holds only §1.2's modules. Token scans skip strings and comments (tests/Meta/Lex). Over-matches, flagged
-- though not the global (none in the tree): a table key or type field named after a banned global (`{ getfenv = 1 }`,
-- `{ rawget: number }`), and a local function or local named next that is called. What still slips: a module-level memo
-- the export does not reach (the deep-freeze sees only what the module returns), printf rounding
-- (tonumber(string.format("%.3f", x))), and next taken as a value (`local f = next`, `(next)(t)`).

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Lex = require("../Meta/Lex")
local Tree = require("../Meta/Tree")

type Token = Lex.Token
type Problem = { path: string, line: number?, message: string }

local DIR = "src/shared/Minigames"
local NOT_AUTHORITATIVE = { "Bots" } -- §6.4 "all of Minigames/ except Bots"
-- §1.2's module map for Minigames/
local MODULES = {
	"Minigames", "Types", "Rng", "Params", "Timeline", "Checks", "Input", "HoldZone", "TimingStrike", "PrecisionTrace",
	"Bots",
}
local MATH_ALLOWED: { [string]: boolean } = {
	floor = true, ceil = true, round = true, abs = true, min = true, max = true, clamp = true, sqrt = true, huge = true,
}
local BUFFER_FLOAT: { [string]: boolean } = { readf32 = true, readf64 = true, writef32 = true, writef64 = true }
local BANNED_OPS: { [string]: string } = {
	["%"] = "integer reductions are x − math.floor(x / m)·m",
	["%="] = "integer reductions are x − math.floor(x / m)·m",
	["//"] = "write math.floor(a / b)",
	["//="] = "write math.floor(a / b)",
}
-- globals that reach a library around the whitelist (getfenv().math.cos, _G.math.exp), where `math` reads as a member
local BANNED_GLOBALS: { [string]: string } = {
	getfenv = "reaches globals around the whitelist, as in getfenv().math.cos",
	setfenv = "rewrites the globals",
	_G = "reaches globals around the whitelist, as in _G.math.exp",
	rawget = "reads a library around the whitelist",
	rawset = "writes a library",
}
local PLANTED = DIR .. "/Planted.luau"

local function isOp(tok: Token?, text: string): boolean
	return tok ~= nil and tok.kind == "op" and tok.text == text
end

-- a name read as a member (t.name, t:name) is not the global
local function isMember(tokens: { Token }, i: number): boolean
	local prev = tokens[i - 1]
	return isOp(prev, ".") or isOp(prev, ":")
end

-- §6.4's whitelist over one authoritative file
local function whitelist(path: string, src: string): { Problem }
	local out: { Problem } = {}
	local function problem(line: number?, message: string)
		table.insert(out, { path = path, line = line, message = message })
	end
	local lexed = Lex.lex(src)
	for _, e in lexed.errors do
		problem(nil, "cannot tokenize: " .. e)
	end
	local tokens = lexed.tokens
	for i, tok in tokens do
		if tok.kind == "name" and not isMember(tokens, i) then
			local nextTok = tokens[i + 1]
			if tok.text == "math" then
				local member = tokens[i + 2]
				if not isOp(nextTok, ".") or member == nil or member.kind ~= "name" then
					problem(tok.line, "math used as a value (§6.4: name each allowed math function)")
				elseif not MATH_ALLOWED[member.text] then
					problem(tok.line, "uses math." .. member.text .. " (§6.4: + − × ÷, sqrt, floor/ceil/round, abs, "
						.. "min/max/clamp only)")
				end
			elseif tok.text == "vector" then
				problem(tok.line, "uses vector (float32 lanes; §6.4)")
			elseif tok.text == "buffer" and isOp(nextTok, ".") then
				local member = tokens[i + 2]
				if member and BUFFER_FLOAT[member.text] then
					problem(tok.line, "uses buffer." .. member.text .. " (timelines hold integers only)")
				end
			elseif tok.text == "pairs" then
				problem(tok.line, "names pairs (§6.4 rule 4: iterate arrays with ipairs, look maps up)")
			elseif BANNED_GLOBALS[tok.text] then
				problem(tok.line, "uses " .. tok.text .. " (" .. BANNED_GLOBALS[tok.text] .. ", §6.4)")
			elseif tok.text == "next" and (isOp(nextTok, "(") or isOp(nextTok, "{")
				or (nextTok ~= nil and (nextTok.kind == "string" or nextTok.kind == "istring")))
			then
				problem(tok.line, "calls next (§6.4 rule 4: a map's keys come in hash order)")
			end
		elseif tok.kind == "op" and BANNED_OPS[tok.text] then
			problem(tok.line, "uses '" .. tok.text .. "' (" .. BANNED_OPS[tok.text] .. ", §6.4)")
		elseif tok.kind == "keyword" and tok.text == "for" then
			-- a generic for: `for <names> in ipairs(...) do`; a numeric for meets `=` first
			local j = i + 1
			while tokens[j] and not (tokens[j].kind == "keyword" and tokens[j].text == "in") and not isOp(tokens[j], "=") do
				j += 1
			end
			local afterIn = tokens[j + 1]
			if tokens[j] and tokens[j].text == "in"
				and not (afterIn and afterIn.kind == "name" and afterIn.text == "ipairs" and isOp(tokens[j + 2], "("))
			then
				problem(tok.line, "a generic for that is not over ipairs(...) (§6.4 rule 4)")
			end
		end
	end
	return out
end

local function show(problems: { Problem }): string
	local lines: { string } = {}
	for _, p in problems do
		table.insert(lines, string.format("%s:%s: %s", p.path, tostring(p.line or "-"), p.message))
	end
	return table.concat(lines, "\n")
end

local function moduleName(path: string): string
	return string.match(path, "([^/]+)%.luau$") or path
end

-- the module files of the folder, by name
local function files(): { string }
	return Tree.files(Tree.disk(), DIR, { ".luau" })
end

-- every table reachable from v is frozen (functions are code, not state)
local function deepFrozen(v: any, path: string, seen: { [any]: boolean })
	if type(v) ~= "table" or seen[v] then
		return
	end
	seen[v] = true
	A.truthy(table.isfrozen(v), path .. " is frozen")
	for k, child in v do
		deepFrozen(child, path .. "." .. tostring(k), seen)
	end
end

return Test.suite("Minigames/Source", function(t)
	t.it("§6.4's whitelist holds in every authoritative Minigames file", function()
		local count = 0
		local problems: { Problem } = {}
		for _, path in files() do
			if table.find(NOT_AUTHORITATIVE, moduleName(path)) == nil then
				count += 1
				for _, p in whitelist(path, (Tree.disk().readFile(path))) do
					table.insert(problems, p)
				end
			end
		end
		A.truthy(count > 0, "no authoritative Minigames file found: run from the repo root")
		if #problems > 0 then
			A.fail(#problems .. " problem(s)\n" .. show(problems))
		end
	end)

	t.it("the whitelist catches each planted violation", function()
		local plants: { { string } } = {
			{ "local y = math.lerp(a, b, s)", "math.lerp" },
			{ "local y = math.fmod(a, b)", "math.fmod" },
			{ "local y = math.noise(a)", "math.noise" },
			{ "local y = math.map(a, 0, 1, 2, 3)", "math.map" },
			{ "local y = math.sign(a)", "math.sign" },
			{ "local y = math.pi * a", "math.pi" },
			{ "local m = math\nlocal y = m.sin(a)", "math used as a value" },
			{ "local y = math[name](a)", "math used as a value" },
			{ "local v = vector.create(a, b, 0)", "uses vector" },
			{ "local y = buffer.readf32(buf, 0)", "buffer.readf32" },
			{ "buffer.writef64(buf, 0, a)", "buffer.writef64" },
			{ "local y = a % b", "'%'" },
			{ "a %= 2", "'%='" },
			{ "local y = a // b", "'//'" },
			{ "a //= 2", "'//='" },
			{ "for k, v in pairs(list) do end", "names pairs" },
			{ "for _, v in list do end", "not over ipairs" },
			{ "for k, v in next, list do end", "not over ipairs" },
			{ "for i: number, v: number in list do end", "not over ipairs" },
			{ "local p = pairs", "names pairs" },
			{ "local y = (getfenv() :: any).math.cos(a)", "uses getfenv" },
			{ "local env = getfenv()\nlocal y = env.math.exp(a)", "uses getfenv" },
			{ "setfenv(1, {})", "uses setfenv" },
			{ "local y = _G.math.lerp(a, b, s)", "uses _G" },
			{ "local f = rawget(list, 'cos')", "uses rawget" },
			{ "rawset(list, 'cos', a)", "uses rawset" },
			{ "local k, v = next(list)", "calls next" },
			{ "local k = next{}", "calls next" },
			{ "local k = next 'x'", "calls next" },
		}
		local head = "--!strict\nlocal a, b, s, buf, list, name = 1, 2, 0.5, buffer.create(8), {}, 'x'\n"
		for _, plant in plants do
			local problems = whitelist(PLANTED, head .. plant[1] .. "\n")
			if #problems == 0 then
				A.fail("planted violation not caught: " .. plant[1])
			end
			A.contains(show(problems), plant[2], plant[1])
		end
	end)

	t.it("the whitelist leaves allowed math, integer buffers, ipairs, strings, comments and members alone", function()
		local clean = table.concat({
			"--!strict",
			"local list, view, buf = { 3, 1, 2 }, { next = 1 }, buffer.create(8)",
			"local a = math.floor(1.5) + math.ceil(0.5) + math.round(2.5) + math.abs(-1) + math.sqrt(4)",
			"local b = math.min(1, 2) + math.max(1, 2) + math.clamp(3, 0, 1) + (if a < math.huge then 1 else 0)",
			"local c = buffer.readu16(buf, 0) + buffer.readu8(buf, 2)",
			"buffer.writeu32(buf, 4, 7)",
			"for i = 1, #list do a += list[i] end",
			"for i, x in ipairs(list) do b += x * i end",
			"local s = string.format('%d // %s', 1, 'math.lerp') -- pairs(t), next(t), _G, a % b and vector.one in a comment",
			"local n = view.next + bit32.band(7, 3)",
			"local mod = a - math.floor(a / 4) * 4",
			"return { a, b, c, s, n, mod }",
		}, "\n")
		local problems = whitelist(PLANTED, clean)
		if #problems > 0 then
			A.fail("clean source flagged:\n" .. show(problems))
		end
	end)

	t.it("P-PURE: every Minigames module loads under Lune and returns a deep-frozen table", function()
		local count = 0
		for _, path in files() do
			count += 1
			local name = moduleName(path)
			local module = (require :: any)("../../" .. DIR .. "/" .. name)
			A.eq(type(module), "table", name .. " returns a table")
			deepFrozen(module, name, {})
		end
		A.truthy(count > 0, "no Minigames module found")
	end)

	t.it("the folder holds only §1.2's Minigames modules, no init.luau", function()
		for _, path in files() do
			local name = moduleName(path)
			A.truthy(table.find(MODULES, name) ~= nil, path .. " is not one of §1.2's Minigames modules")
			A.eq(string.find(path, "/", #DIR + 2, true), nil, path .. ": the folder is flat")
		end
	end)
end)
