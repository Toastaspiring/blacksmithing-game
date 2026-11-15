--!strict
-- T-META-01, 02, 03, 04, 06 (SPEC §14.4): source rules over every file of the real tree, and planted violations
-- that each rule must catch (so a rule that stops biting fails here). Token scans skip strings and comments.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Lex = require("./Lex")
local Rules = require("./Rules")
local Requires = require("./Requires")
local Tree = require("./Tree")

type Problem = Rules.Problem
type View = Tree.View

local function show(problems: { Problem }): string
	local lines: { string } = {}
	for k, p in problems do
		if k > 20 then
			table.insert(lines, string.format("... and %d more", #problems - 20))
			break
		end
		table.insert(lines, string.format("%s:%s: %s", p.path, tostring(p.line or "-"), p.message))
	end
	return table.concat(lines, "\n")
end

local function expectClean(problems: { Problem }, what: string)
	if #problems > 0 then
		A.fail(what .. ": " .. #problems .. " problem(s)\n" .. show(problems))
	end
end

local function expectCaught(problems: { Problem }, what: string, needle: string?)
	if #problems == 0 then
		A.fail("planted violation not caught: " .. what)
	end
	if needle and not string.find(show(problems), needle, 1, true) then
		A.fail("planted violation " .. what .. " caught without '" .. needle .. "':\n" .. show(problems))
	end
end

-- ── T-META-02 as one check over a view (allowlist, tokens, requires of @roblox-bound files) ───────────────────

local function purityOf(view: View, path: string): { Problem }
	local src = view.readFile(path)
	if Rules.isRobloxBound(src) then
		if Rules.isAllowlisted(path) then
			return {}
		end
		return { { path = path, line = 2, message = "-- @roblox-bound on a file outside the tests/Meta allowlist ("
			.. table.concat(Rules.ROBLOX_BOUND_ALLOWLIST, ", ") .. ")" } }
	end
	local problems = Rules.purity(path, src)
	if string.match(path, "/init%.luau?$") then
		table.insert(problems, { path = path, line = 1, message = "pure modules use no init.luau (SPEC §1.3 L3)" })
	end
	for _, ref in Requires.extract(src) do
		if ref.form == "string" then
			local target = Requires.resolveDisk(view, path, ref.spec)
			if target and Rules.isRobloxBound(view.readFile(target)) then
				table.insert(problems, { path = path, line = ref.line, message = string.format(
					"pure module requires the @roblox-bound %s", target) })
			end
		end
	end
	return problems
end

local function each(view: View, dirs: { string }, rule: (string, string) -> { Problem }, filter: ((string) -> boolean)?): ({ Problem }, number)
	local problems: { Problem } = {}
	local count = 0
	for _, dir in dirs do
		for _, path in Tree.files(view, dir, { ".luau" }) do
			if filter == nil or filter(path) then
				count += 1
				for _, p in rule(path, view.readFile(path)) do
					table.insert(problems, p)
				end
			end
		end
	end
	return problems, count
end

local disk = Tree.disk()

local PURE = "src/shared/Definitions/Planted.luau"
local AUTH = "src/shared/Physics/Planted.luau"

return Test.suite("Meta/Source", function(t)
	-- ── the lexer the scans rely on ───────────────────────────────────────────────────────────────────────────

	t.it("lexer: strings, long strings, comments and interpolation hide their text from the scans", function()
		local src = table.concat({
			"--!strict",
			'local a = "game \\" print" .. \'workspace\'',
			"local b = [==[ script ]] task. ]==]",
			"--[[ Vector3.new(1, 2, 3)",
			"     still a comment ]] local c = 1",
			"local d = `text {e .. `{f}`} {g} \\{h} more`",
			"-- warn(game)",
		}, "\n")
		local lexed = Lex.lex(src)
		A.eq(#lexed.errors, 0, "errors")
		local names: { string } = {}
		for _, tok in lexed.tokens do
			if tok.kind == "name" then
				table.insert(names, tok.text)
			end
		end
		A.eq(table.concat(names, " "), "a b c d e f g", "names outside strings and comments")
		local last = lexed.tokens[#lexed.tokens]
		A.eq(last.line, 6, "line count across a long comment")
		A.eq(lexed.tokens[4].text, "game \" print", "decoded string value")
		A.eq(#lexed.comments, 3, "comments")
	end)

	t.it("lexer: never throws on broken input", function()
		for _, src in { '"unterminated', "[[ open", "--[==[ open", "`a {b", "x = 1 }}} ))) ", "\0\1\2 \255" } do
			local result = Lex.lex(src)
			A.truthy(result ~= nil, src)
		end
	end)

	-- ── T-META-01 ─────────────────────────────────────────────────────────────────────────────────────────────

	t.it("T-META-01 every .luau under src/ and tests/ starts with --!strict", function()
		local problems, count = each(disk, { "src", "tests" }, Rules.strictHeader)
		A.truthy(count > 0, "no files found: run from the repo root")
		expectClean(problems, "T-META-01")
		local stray = Tree.files(disk, "src", { ".lua" })
		for _, f in Tree.files(disk, "tests", { ".lua" }) do
			table.insert(stray, f)
		end
		A.eq(#stray, 0, "Luau sources use .luau (found " .. table.concat(stray, ", ") .. ")")
	end)

	t.it("T-META-01 catches planted headers", function()
		for _, src in { "local x = 1\n", "--!nonstrict\nreturn 1\n", "\239\187\191--!strict\n", " --!strict\n", "" } do
			expectCaught(Rules.strictHeader("src/x.luau", src), string.format("%q", src))
		end
		expectClean(Rules.strictHeader("src/x.luau", "--!strict\r\nreturn 1\r\n"), "CRLF header")
		expectClean(Rules.strictHeader("src/x.luau", "--!strict"), "header without newline")
	end)

	-- ── T-META-02 ─────────────────────────────────────────────────────────────────────────────────────────────

	t.it("T-META-02 src/shared is pure outside the @roblox-bound allowlist", function()
		local problems, count = each(disk, { "src/shared" }, function(path: string, _src: string): { Problem }
			return purityOf(disk, path)
		end)
		A.truthy(count > 0, "no files in scope")
		expectClean(problems, "T-META-02")
	end)

	t.it("T-META-02 catches each planted Roblox or clock use in a pure module", function()
		local plants = {
			'local p = game:GetService("Players")', "local g = workspace.Gravity", "local s = script.Parent",
			'local p = Instance.new("Part")', "local v = Vector3.new(1, 2, 3)", "local c: CFrame? = nil",
			"local c = Color3.new(1, 0, 0)", "local r = Random.new(1)", "local x = math.random()",
			"local t = os.time()", "local t = os.clock()", "local t = tick()", "local d = DateTime.now()",
			"task.wait(1)", "wait(1)", 'print("x")', 'warn("x")', "local s = `{game.PlaceId}`",
			"local f = function(v: Vector3) end", "local t: { [string]: Color3 } = {}",
			'local t = { game:GetService("Players") }', "local t = { x = game }", "local t = { [print] = 1 }",
			"local function f() return tick() end", "local a; wait(1)", "local n: number = 0 task.wait(n)",
			"local task = task\ntask.wait(1)", "local function f() local wait = 1 end\nwait(5)",
			"local m = Enum.Material.Metal", "local u = UDim2.new(0, 1, 0, 1)", 'local d = os.date("%Y")',
			"local b = BrickColor.new(1)", "local t = TweenInfo.new(1)",
		}
		for _, line in plants do
			expectCaught(Rules.purity(PURE, "--!strict\n" .. line .. "\n"), line, "pure module uses")
		end
	end)

	t.it("T-META-02 tick( wait( task. are banned as tokens: a local of that name does not exempt them", function()
		-- SPEC §14.4's literal token list, whatever is in scope
		local tokens = {
			"local wait = wait\nwait(1)", "local tick = function()\n\treturn tick()\nend",
			"if x then\n\tlocal wait = 1\nelse\n\twait(5)\nend", "for wait = 1, 2 do end\nwait(5)",
			"do local tick = 0 end\ntick()", "function wait() end", "repeat local tick = 0 until true\ntick()",
			"local s = `{wait(1)}`", "local f = function(task) return task end\ntask.spawn(f)",
			"local function tick(n: number): number\n\tif n > 0 then\n\t\treturn tick(n - 1)\n\tend\n\treturn n\nend",
			"local function delayed(wait: number, task: { id: number }): number\n\treturn wait + task.id\nend",
			"local t = {}\nfor _, task in t do\n\tlocal id = task.id\nend",
			"local wait = function(ms: number): number\n\treturn ms\nend\nlocal w = wait(5)",
			"local task = { id = 1 }\nlocal id = task.id", "local tick = function(t: any) end\ntick {}",
			"local wait = function(s: string) end\nwait 'x'",
		}
		for _, src in tokens do
			expectCaught(Rules.purity(PURE, "--!strict\n" .. src .. "\n"), src, "SPEC §14.4's token list")
		end
		-- stricter than the list: the bare Roblox globals as values, when no local of that name is in scope
		local globals = {
			"local tick = tick", "local t = task\nt.spawn(f)", "local ok = pcall(wait, 1)", "local x: typeof(task) = nil",
			"local w = if x then wait else nil",
		}
		for _, src in globals do
			expectCaught(Rules.purity(PURE, "--!strict\n" .. src .. "\n"), src, "the Roblox global as a value")
		end
		-- locals of those names used as values, fields, methods and keys use none of the tokens
		local clean = {
			"local n = 0\nif n > 0 then\n\tlocal tick = 1\n\tn = tick\nelseif n < 0 then\n\tlocal tick = 2\n"
				.. "\tn = tick\nelse\n\tlocal tick = 3\n\tn = tick\nend",
			"repeat\n\tlocal wait = 1\nuntil wait > 0",
			"local tick = if true then 1 else 2\nlocal y = tick",
			"local wait: number,\n\ttick: number = 1, 2\nlocal sum = wait + tick",
			"local wait = (function()\n\treturn 1\nend)()\nlocal v = wait",
			"local session = {}\nfunction session.tick(s) return s end\nfunction session:wait() return self end",
			"local function count(task: number): number\n\treturn task + 1\nend",
			"local obj: any = { task = { id = 1 } }\nlocal id = obj.task.id\nlocal ok = obj:wait()\nlocal t = obj.tick(1)",
			"local t = { tick = 1, wait = 2, task = 3 }\nlocal s = t.tick + t.wait + t.task",
			"local tick = 0\ntick += 1",
		}
		for _, src in clean do
			expectClean(Rules.purity(PURE, "--!strict\n" .. src .. "\n"), src)
		end
	end)

	t.it("T-META-02 leaves strings, comments, members, table keys and local names alone", function()
		local clean = table.concat({
			"--!strict",
			'local s = "game workspace script print warn os.clock() math.random"',
			"-- print(game) task.wait() Vector3.new()",
			"local t = {}",
			"t.print = 1",
			"local obj = { game = 0, warn = { 255, 200, 0 }; script = 1 }",
			"type Colors = { warn: { number }, print: number }",
			"local n = obj.game + t.print",
			"local tick = 0",
			"tick += 1",
			"local wait = 5",
			"local w = wait + 1",
			"local gameState, scripts, printer = 1, 2, 3",
			"local m = math.floor(1.5) + math.sqrt(4)",
			"return { s, n, w, gameState, scripts, printer, m }",
		}, "\n")
		expectClean(Rules.purity(PURE, clean), "clean pure module")
	end)

	t.it("T-META-02 allowlist and @roblox-bound requires", function()
		local view = Tree.memory({
			["src/shared/Net/Remotes.luau"] = "--!strict\n-- @roblox-bound\nlocal x = game\nreturn {}\n",
			["src/shared/Util/Helper.luau"] = "--!strict\n-- @roblox-bound\nreturn {}\n",
			["src/shared/Net/Client.luau"] = "--!strict\nlocal p = game.Players\nreturn {}\n",
			["src/shared/Definitions/Uses.luau"] = '--!strict\nlocal R = require("../Net/Remotes")\nreturn {}\n',
			["src/shared/Definitions/Clean.luau"] = '--!strict\nlocal U = require("./Uses")\nreturn {}\n',
			["src/shared/Util/Sub/init.luau"] = "--!strict\nreturn {}\n",
		})
		expectCaught(purityOf(view, "src/shared/Util/Sub/init.luau"), "a pure init.luau", "no init.luau")
		expectClean(purityOf(view, "src/shared/Net/Remotes.luau"), "allowlisted and tagged")
		expectCaught(purityOf(view, "src/shared/Util/Helper.luau"), "tag outside the allowlist", "allowlist")
		expectCaught(purityOf(view, "src/shared/Net/Client.luau"), "allowlisted but untagged, so pure", "'game'")
		expectCaught(purityOf(view, "src/shared/Definitions/Uses.luau"), "pure requires @roblox-bound",
			"requires the @roblox-bound src/shared/Net/Remotes.luau")
		expectClean(purityOf(view, "src/shared/Definitions/Clean.luau"), "pure requires pure")
	end)

	-- ── T-META-03 ─────────────────────────────────────────────────────────────────────────────────────────────

	t.it("T-META-03 authoritative modules use no transcendental math or ^, and no native code", function()
		local problems, count = each(disk, { "src/shared" }, Rules.transcendental, Rules.isAuthoritative)
		A.truthy(count > 0, "no files in scope")
		expectClean(problems, "T-META-03")
	end)

	t.it("T-META-03 catches planted transcendental calls, powers and native code", function()
		for _, line in
			{
				"local y = math.sin(x)", "local y = math.cos(x)", "local y = math.tan(x)", "local y = math.exp(x)",
				"local y = math.log(x)", "local y = math.log10(x)", "local y = math.pow(x, 2)",
				"local y = math.atan2(1, x)", "local y = math.asin(x)", "local y = math.acos(x)",
				"local y = math.sinh(x)", "local y = x ^ 2", "y ^= 2",
				"local y = math.sin(x) -- allow-transcendental:", "local y = math.sin(x) -- allow-transcendental",
				"local f = math.atan -- a reference counts too",
			}
		do
			expectCaught(Rules.transcendental(AUTH, "--!strict\nlocal x, y = 1, 1\n" .. line .. "\n"), line, "uses ")
		end
		-- §4.1: no native code, as a directive or on one function
		expectCaught(Rules.transcendental(AUTH, "--!strict\n--!native\nlocal x = 1\n"), "--!native", "--!native")
		expectCaught(Rules.transcendental(AUTH, "--!strict\r\n--!native\r\nlocal x = 1\r\n"), "--!native, CRLF", "--!native")
		expectCaught(Rules.transcendental(AUTH, "--!strict\n@native\nlocal function f() end\n"), "@native", "@native")
		expectCaught(Rules.transcendental(AUTH, "--!strict\nlocal f = @native function() end\n"), "@native on a value", "@native")
		local clean = table.concat({
			"--!strict",
			"local x = 2",
			"local a = math.sin(x) -- allow-transcendental: editor display only",
			'local b = "x^2 math.sin --!native @native" -- x^2 in a comment, and no --!native here',
			"local c = math.sqrt(x) * math.abs(-x) + math.floor(x)",
			"local native = c + 1",
			"return { a, b, c, native }",
		}, "\n")
		expectClean(Rules.transcendental(AUTH, clean), "allowed, strings, comments, exact ops")
		for _, path in
			{
				"src/shared/Blueprint/X.luau", "src/shared/Physics/Sub/X.luau", "src/shared/Minigames/X.luau",
				"src/shared/Crafting/X.luau", "src/shared/Pipeline.luau", "src/shared/Items/X.luau",
				"src/shared/Session/X.luau",
			}
		do
			A.truthy(Rules.isAuthoritative(path), path .. " is in scope")
		end
		for _, path in { "src/shared/Definitions/X.luau", "src/shared/PipelineX.luau", "src/shared/EditorCore/X.luau", "src/server/Physics/X.luau" } do
			A.falsy(Rules.isAuthoritative(path), path .. " is out of scope")
		end
	end)

	-- ── T-META-04 ─────────────────────────────────────────────────────────────────────────────────────────────

	t.it("T-META-04 authoritative modules never accumulate floats while iterating a keyed table", function()
		local problems, count = each(disk, { "src/shared" }, Rules.keyedAccumulation, Rules.isAuthoritative)
		A.truthy(count > 0, "no files in scope")
		expectClean(problems, "T-META-04")
	end)

	t.it("T-META-04 catches planted keyed accumulations", function()
		local plants = {
			"for _, v in pairs(t) do\n\ts += v\nend",
			"for k, v in t do s = s + v end",
			"for k, v in next, t do s = v + s end",
			"for _, v in self.map do\n\tself.total += v.mass\nend",
			"for k, v in pairs(t) do\n\tfor i = 1, 3 do\n\t\ts += v[i]\n\tend\nend",
			"for k, v in pairs(t) do s *= v end",
			"for k, v in pairs(t) do acc[1] = acc[1]\n\t\t+ v end",
			"for k, v in pairs(t) do\n\tlocal y = if v > 0 then v else -v\n\ts -= y\nend",
			"for k, v in pairs(t) do s += 0.5 end",
			"for k, v in pairs(t) do f(function() s += v end) end",
			"for k, v in (t) do s += v end",
			"for k, v in t :: { [string]: number } do s += v end",
		}
		for _, body in plants do
			expectCaught(Rules.keyedAccumulation(AUTH, "--!strict\nlocal s, t, acc = 0, {}, {0}\n" .. body .. "\n"), body,
				"accumulates into")
		end
	end)

	t.it("T-META-04 allows ordered loops, counters, per-iteration locals and non-arithmetic updates", function()
		local clean = {
			"for _, v in ipairs(t) do s += v end",
			"for i = 1, #t do s += t[i] end",
			"for k, v in pairs(t) do n += 1 end",
			"for k, v in pairs(t) do n = n + 1 end",
			"for k, v in pairs(t) do\n\tlocal x = 0\n\tx += v\n\tout[k] = x\nend",
			"for k, v in pairs(t) do out[k] = v * 2 end",
			"for k, v in pairs(t) do m = math.max(m, v) end",
			'for w in string.gmatch(str, "%a+") do s += #w end',
			"for k, v in pairs(t) do out[k] = { sum = s + v } end",
			"for k, v in sortedPairs(t) do s += v end",
			"for k, v in pairs(t) do\n\tlocal y = if v then 1 else 2\n\tout[k] = y\nend\ns += 1.5",
			"for k, v in pairs(t) do names = names .. k end",
		}
		for _, body in clean do
			expectClean(Rules.keyedAccumulation(AUTH, "--!strict\nlocal s, n, m, t, out, str, names = 0, 0, 0, {}, {}, '', ''\n"
				.. body .. "\n"), body)
		end
	end)

	-- ── T-META-06 ─────────────────────────────────────────────────────────────────────────────────────────────

	t.it("T-META-06 no :Reconcile( in src/", function()
		local problems, count = each(disk, { "src" }, Rules.reconcile)
		A.truthy(count > 0, "no files in scope")
		expectClean(problems, "T-META-06")
	end)

	t.it("T-META-06 catches planted Reconcile calls", function()
		for _, line in { "profile:Reconcile()", "profile.Reconcile(profile)", "store.profile:Reconcile ()" } do
			expectCaught(Rules.reconcile("src/server/DataService.luau", "--!strict\n" .. line .. "\n"), line, "Reconcile(")
		end
		local clean = "--!strict\n-- profile:Reconcile()\nlocal s = \"profile:Reconcile()\"\nprofile:ReconcileLater()\n"
		expectClean(Rules.reconcile("src/server/DataService.luau", clean), "comments, strings, other names")
	end)
end)
