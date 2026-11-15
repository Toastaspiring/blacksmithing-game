--!strict
-- tests/Meta/Rules.luau — the source rules of SPEC §14.4 as pure functions over (path, source):
--   T-META-01 strict header · T-META-02 purity of src/shared · T-META-03 no transcendental math, no native code ·
--   T-META-04 no float accumulation while iterating a keyed table · T-META-06 no :Reconcile( in src/.
-- Token scans skip strings and comments (tests/Meta/Lex). Paths are repo-relative with forward slashes.
-- Each rule returns a list of Problems; an empty list means the file passes.

local Lex = require("./Lex")

type Token = Lex.Token
export type Problem = { path: string, line: number?, message: string }

local Rules = {}

Rules.STRICT_HEADER = "--!strict"
Rules.ROBLOX_BOUND_TAG = "-- @roblox-bound"
-- T-META-02: the only src/shared files that may be Roblox-bound (SPEC §1.2, §1.3 L3).
Rules.ROBLOX_BOUND_ALLOWLIST = table.freeze({
	"src/shared/Net/Remotes.luau",
	"src/shared/Net/Client.luau",
	"src/shared/Util/Signal.luau",
	"src/shared/ItemRender/ItemModelBuilder.luau",
})
-- T-META-03 and T-META-04 cover these folders and the Pipeline module.
Rules.AUTHORITATIVE = table.freeze({
	"src/shared/Blueprint/",
	"src/shared/Physics/",
	"src/shared/Minigames/",
	"src/shared/Crafting/",
	"src/shared/Pipeline",
	"src/shared/Items/",
	"src/shared/Session/",
})
Rules.ALLOW_TRANSCENDENTAL = "allow-transcendental"

local function problem(out: { Problem }, path: string, line: number?, message: string)
	table.insert(out, { path = path, line = line, message = message })
end

local function lexOrReport(path: string, src: string, out: { Problem }): Lex.Result
	local result = Lex.lex(src)
	for _, e in result.errors do
		problem(out, path, nil, "cannot tokenize: " .. e)
	end
	return result
end

function Rules.isAuthoritative(path: string): boolean
	for _, prefix in Rules.AUTHORITATIVE do
		if prefix == "src/shared/Pipeline" then
			if path == "src/shared/Pipeline.luau" or string.sub(path, 1, 20) == "src/shared/Pipeline/" then
				return true
			end
		elseif string.sub(path, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

function Rules.isAllowlisted(path: string): boolean
	return table.find(Rules.ROBLOX_BOUND_ALLOWLIST, path) ~= nil
end

-- Line 2 is exactly "-- @roblox-bound" (trailing spaces ignored).
function Rules.isRobloxBound(src: string): boolean
	local lines = Lex.lines(src)
	local second = lines[2]
	return second ~= nil and string.gsub(second, "%s+$", "") == Rules.ROBLOX_BOUND_TAG
end

-- ── token helpers ─────────────────────────────────────────────────────────────────────────────────────────────

local function isOp(tok: Token?, text: string): boolean
	return tok ~= nil and tok.kind == "op" and tok.text == text
end

local function isKeyword(tok: Token?, text: string): boolean
	return tok ~= nil and tok.kind == "keyword" and tok.text == text
end

local function isCallOpener(tok: Token?): boolean
	return tok ~= nil and ((tok.kind == "op" and (tok.text == "(" or tok.text == "{")) or tok.kind == "string"
		or tok.kind == "istring")
end

-- A name used as a field or method (a.name, a:name(...)) is not a global. "x: T" (a type annotation) is.
local function isMember(tokens: { Token }, idx: number): boolean
	local prev = tokens[idx - 1]
	if isOp(prev, ".") then
		return true
	end
	if isOp(prev, ":") then
		return isCallOpener(tokens[idx + 1])
	end
	return false
end

-- Names declared as locals, local functions, function parameters or for-loop variables in tokens[from..to],
-- whatever their scope. Over-approximate on purpose (type names in annotations land here too): T-META-04 uses it
-- only to skip per-iteration locals. T-META-02 resolves scopes properly (Rules.scopes).
local function declaredNames(tokens: { Token }, from: number, to: number): { [string]: boolean }
	local names: { [string]: boolean } = {}
	local k = from
	while k <= to do
		local tok = tokens[k]
		local nextTok = tokens[k + 1]
		local isConst = tok.kind == "name" and tok.text == "const" and nextTok ~= nil and nextTok.kind == "name"
		if isKeyword(tok, "local") and isKeyword(nextTok, "function") then
			local name = tokens[k + 2]
			if name and name.kind == "name" then
				names[name.text] = true
			end
		elseif isKeyword(tok, "local") or isConst then
			-- name list `a [: T], b [: T]` up to "=", ";" or the end of the line; commas inside types are skipped
			local j = k + 1
			local expectName = true
			local depth = 0
			while j <= to do
				local t = tokens[j]
				if depth == 0 and (isOp(t, "=") or isOp(t, ";") or t.line ~= tok.line) then
					break
				end
				if expectName then
					if t.kind == "name" then
						names[t.text] = true
					end
					expectName = false
				elseif depth == 0 and isOp(t, ",") then
					expectName = true
				elseif isOp(t, "(") or isOp(t, "{") or isOp(t, "[") or isOp(t, "<") then
					depth += 1
				elseif isOp(t, ")") or isOp(t, "}") or isOp(t, "]") or isOp(t, ">") then
					depth -= 1
				end
				j += 1
			end
		elseif isKeyword(tok, "function") then
			local j = k + 1
			while j <= to and not isOp(tokens[j], "(") do
				j += 1
			end
			local depth = 0
			while j <= to do
				local t = tokens[j]
				if isOp(t, "(") then
					depth += 1
				elseif isOp(t, ")") then
					depth -= 1
					if depth == 0 then
						break
					end
				elseif t.kind == "name" then
					names[t.text] = true
				end
				j += 1
			end
		elseif isKeyword(tok, "for") then
			local j = k + 1
			while j <= to and not isKeyword(tokens[j], "in") and not isOp(tokens[j], "=") do
				if tokens[j].kind == "name" then
					names[tokens[j].text] = true
				end
				j += 1
			end
		end
		k += 1
	end
	return names
end

-- ── block structure (T-META-02 scopes, T-META-04) ─────────────────────────────────────────────────────────────

local EXPR_PREV_OPS: { [string]: boolean } = {}
for _, op in
	{
		"=", "(", ",", "{", "[", "+", "-", "*", "/", "//", "%", "^", "..", "==", "~=", "<", "<=", ">", ">=", "#",
		"+=", "-=", "*=", "/=", "//=", "%=", "^=", "..=",
	}
do
	EXPR_PREV_OPS[op] = true
end
local EXPR_PREV_KEYWORDS = {
	["return"] = true, ["and"] = true, ["or"] = true, ["not"] = true, ["in"] = true, ["if"] = true,
	["elseif"] = true, ["while"] = true, ["until"] = true,
}

-- Maps each block opener (do, function, statement if, repeat) to its closing end / until. An `if` in expression
-- position (Luau if-then-else expression) opens no block. Second result: each then / elseif / else → true when its
-- if is such an expression, false when it is a statement (a branch boundary).
local function blockEnds(tokens: { Token }): ({ [number]: number }, { [number]: boolean })
	local closeOf: { [number]: number } = {}
	local stack: { { kind: string, idx: number } } = {}
	local ifIsExpr: { boolean } = {}
	local ownerIsExpr: { [number]: boolean } = {}
	for idx, tok in tokens do
		if tok.kind ~= "keyword" then
			continue
		end
		local word = tok.text
		if word == "if" then
			local prev = tokens[idx - 1]
			local isExpr = false
			if prev and prev.kind == "op" and EXPR_PREV_OPS[prev.text] then
				isExpr = true
			elseif prev and prev.kind == "keyword" and EXPR_PREV_KEYWORDS[prev.text] then
				isExpr = true
			elseif prev and prev.kind == "keyword" and (prev.text == "then" or prev.text == "else") then
				isExpr = ownerIsExpr[idx - 1] == true
			end
			table.insert(ifIsExpr, isExpr)
			if not isExpr then
				table.insert(stack, { kind = "if", idx = idx })
			end
		elseif word == "then" or word == "elseif" then
			ownerIsExpr[idx] = ifIsExpr[#ifIsExpr] == true
		elseif word == "else" then
			local top = ifIsExpr[#ifIsExpr]
			ownerIsExpr[idx] = top == true
			if top == true then
				table.remove(ifIsExpr)
			end
		elseif word == "do" or word == "function" or word == "repeat" then
			local kind: string = word
			table.insert(stack, { kind = kind, idx = idx })
		elseif word == "end" or word == "until" then
			local open = table.remove(stack)
			if open then
				closeOf[open.idx] = idx
				if open.kind == "if" then
					while #ifIsExpr > 0 do
						if table.remove(ifIsExpr) == false then
							break
						end
					end
				end
			end
		end
	end
	return closeOf, ownerIsExpr
end
Rules.blockEnds = blockEnds

-- ── scopes (T-META-02: the bare globals tick, wait and task used as values, unless a local is in scope) ───────

-- Keywords an expression list never runs past (then / elseif / else only when their if is a statement).
local STATEMENT_START: { [string]: boolean } = {
	["local"] = true, ["return"] = true, ["for"] = true, ["while"] = true, ["repeat"] = true, ["do"] = true,
	["end"] = true, ["until"] = true, ["break"] = true, ["in"] = true, ["then"] = true, ["elseif"] = true,
	["else"] = true,
}
-- A line ending on one of these continues on the next; a line starting with one of these continues the previous.
local JOIN_AFTER: { [string]: boolean } = {}
for _, op in
	{
		"=", "(", "[", "{", ",", ".", ":", "::", "->", "+", "-", "*", "/", "//", "%", "^", "..", "==", "~=", "<",
		"<=", ">", ">=", "#",
	}
do
	JOIN_AFTER[op] = true
end
local JOIN_BEFORE: { [string]: boolean } = {}
for _, op in { ".", ":", "::", "+", "-", "*", "/", "//", "%", "^", "..", "==", "~=", "<", "<=", ">", ">=" } do
	JOIN_BEFORE[op] = true
end

-- and / or / not, and the if / then / elseif / else of an if-then-else expression.
local function isExprKeyword(tokens: { Token }, k: number, closeOf: { [number]: number },
	ownerIsExpr: { [number]: boolean }): boolean
	local t = tokens[k]
	if t == nil or t.kind ~= "keyword" then
		return false
	elseif t.text == "and" or t.text == "or" or t.text == "not" then
		return true
	elseif t.text == "if" then
		return closeOf[k] == nil
	elseif t.text == "then" or t.text == "elseif" or t.text == "else" then
		return ownerIsExpr[k] == true
	end
	return false
end

-- Index of the last token of the expression list that starts at tokens[from] (function bodies included). When unsure
-- it runs long, e.g. over a second statement on the same line: a local that comes into scope later only makes the
-- check stricter.
local function exprListEnd(tokens: { Token }, from: number, closeOf: { [number]: number },
	ownerIsExpr: { [number]: boolean }): number
	local depth = 0
	local last = from - 1
	local k = from
	while k <= #tokens do
		local t = tokens[k]
		if depth == 0 and k > from then
			local exprKw = isExprKeyword(tokens, k, closeOf, ownerIsExpr)
			if isOp(t, ";") or (t.kind == "keyword" and not exprKw and (STATEMENT_START[t.text] or t.text == "if")) then
				break
			end
			local prev = tokens[k - 1]
			if t.line ~= prev.line then
				local joined = exprKw or isExprKeyword(tokens, k - 1, closeOf, ownerIsExpr)
					or (prev.kind == "op" and JOIN_AFTER[prev.text] == true)
					or (t.kind == "op" and JOIN_BEFORE[t.text] == true)
				if not joined then
					break
				end
			end
		end
		if isKeyword(t, "function") and closeOf[k] then
			k = closeOf[k]
		elseif t.kind == "op" and (t.text == "(" or t.text == "[" or t.text == "{") then
			depth += 1
		elseif t.kind == "op" and (t.text == ")" or t.text == "]" or t.text == "}") then
			if depth == 0 then
				break -- closes a bracket opened before the list
			end
			depth -= 1
		end
		last = k
		k += 1
	end
	return last
end

-- `local a [: T], b [: T] [= ...]` from tokens[k] (local, or const): the declared name tokens, the index of "=" (nil
-- without one) and the last token of the name list.
local function localDecl(tokens: { Token }, k: number): ({ number }, number?, number)
	local names: { number } = {}
	local depth = 0
	local expectName = true
	local last = k
	local j = k + 1
	while j <= #tokens do
		local t = tokens[j]
		local prev = tokens[j - 1]
		if depth == 0 then
			if isOp(t, "=") then
				return names, j, last
			elseif isOp(t, ";") or (t.kind == "keyword" and t.text ~= "nil" and t.text ~= "true" and t.text ~= "false")
			then
				break
			elseif t.line ~= prev.line and not (prev.kind == "op" and (prev.text == "," or prev.text == ":"
				or prev.text == "|" or prev.text == "&" or prev.text == "->"))
			then
				break
			end
		end
		if expectName and depth == 0 then
			if t.kind == "name" then
				table.insert(names, j)
			end
			expectName = false
		elseif depth == 0 and isOp(t, ",") then
			expectName = true
		elseif isOp(t, "(") or isOp(t, "{") or isOp(t, "[") or isOp(t, "<") then
			depth += 1
		elseif isOp(t, ")") or isOp(t, "}") or isOp(t, "]") or isOp(t, ">") then
			depth -= 1
		end
		last = j
		j += 1
	end
	return names, nil, last
end

export type Scopes = {
	decl: { [number]: boolean }, -- name tokens that declare a local: local, local function, parameter, loop variable
	bound: { [number]: boolean }, -- other name tokens that name a local in scope there
}
type Frame = { names: { [string]: number }, closeAt: number, branch: boolean }

-- Lexical scopes over a token stream: the chunk, each function (its parameters), each do / while / for body (the
-- loop variables), each repeat body up to the end of its until condition, and each branch of a statement if. A
-- `local` comes into scope after its statement (so `local wait = wait` reads the global), a `local function` at its
-- name (so it can recurse).
function Rules.scopes(tokens: { Token }): Scopes
	local closeOf, ownerIsExpr = blockEnds(tokens)
	local decl: { [number]: boolean } = {}
	local bound: { [number]: boolean } = {}
	local stack: { Frame } = { { names = {}, closeAt = #tokens + 1, branch = false } }
	local loopVars: { [number]: { number } } = {} -- index of a loop's "do" → its variables

	local function bind(frame: Frame, nameIdx: number, from: number)
		local name = tokens[nameIdx].text
		local seen = frame.names[name]
		if seen == nil or from < seen then
			frame.names[name] = from
		end
		decl[nameIdx] = true
	end

	local function declareLocal(k: number)
		local names, eq, listEnd = localDecl(tokens, k)
		local from = (if eq then exprListEnd(tokens, eq + 1, closeOf, ownerIsExpr) else listEnd) + 1
		for _, n in names do
			bind(stack[#stack], n, from)
		end
	end

	for k, tok in tokens do
		while #stack > 1 and stack[#stack].closeAt < k do
			table.remove(stack)
		end
		local word = if tok.kind == "keyword" then tok.text else nil
		if word == "function" and closeOf[k] then
			local nameTok = tokens[k + 1]
			if isKeyword(tokens[k - 1], "local") and nameTok and nameTok.kind == "name" then
				bind(stack[#stack], k + 1, k + 1)
			end
			-- parameters: the names right after "(" or a "," of the parameter list (types after ":" are not)
			local frame: Frame = { names = {}, closeAt = closeOf[k], branch = false }
			local j = k + 1
			while j < closeOf[k] and not isOp(tokens[j], "(") do
				j += 1
			end
			local depth = 0
			while j < closeOf[k] do
				local t = tokens[j]
				if isOp(t, "(") or isOp(t, "{") or isOp(t, "[") or isOp(t, "<") then
					depth += 1
				elseif isOp(t, ")") or isOp(t, "}") or isOp(t, "]") or isOp(t, ">") then
					depth -= 1
					if depth == 0 then
						break
					end
				elseif depth == 1 and t.kind == "name" and (isOp(tokens[j - 1], "(") or isOp(tokens[j - 1], ",")) then
					bind(frame, j, j)
				end
				j += 1
			end
			table.insert(stack, frame)
		elseif word == "do" and closeOf[k] then
			local frame: Frame = { names = {}, closeAt = closeOf[k], branch = false }
			local vars: { number } = loopVars[k] or {}
			for _, v in vars do
				bind(frame, v, k)
			end
			table.insert(stack, frame)
		elseif word == "repeat" and closeOf[k] then
			local untilEnd = exprListEnd(tokens, closeOf[k] + 1, closeOf, ownerIsExpr)
			table.insert(stack, { names = {}, closeAt = untilEnd, branch = false })
		elseif word == "if" and closeOf[k] then
			table.insert(stack, { names = {}, closeAt = closeOf[k], branch = true })
		elseif (word == "elseif" or word == "else") and ownerIsExpr[k] == false then
			while #stack > 1 and not stack[#stack].branch do
				table.remove(stack)
			end
			if #stack > 1 then
				stack[#stack] = { names = {}, closeAt = stack[#stack].closeAt, branch = true }
			end
		elseif word == "for" then
			-- loop variables: the names after "for" or a "," up to "in" / "=", bound in the body the loop's "do" opens
			local vars: { number } = {}
			local depth = 0
			local j = k + 1
			while j <= #tokens do
				local t = tokens[j]
				if depth == 0 and (isKeyword(t, "in") or isOp(t, "=") or isKeyword(t, "do")) then
					break
				elseif isOp(t, "(") or isOp(t, "{") or isOp(t, "[") or isOp(t, "<") then
					depth += 1
				elseif isOp(t, ")") or isOp(t, "}") or isOp(t, "]") or isOp(t, ">") then
					depth -= 1
				elseif depth == 0 and t.kind == "name" and (j == k + 1 or isOp(tokens[j - 1], ",")) then
					table.insert(vars, j)
					decl[j] = true
				end
				j += 1
			end
			while j <= #tokens and not isKeyword(tokens[j], "do") do
				if isKeyword(tokens[j], "function") and closeOf[j] then
					j = closeOf[j]
				end
				j += 1
			end
			if j <= #tokens then
				loopVars[j] = vars
			end
		elseif word == "local" and not isKeyword(tokens[k + 1], "function") then
			declareLocal(k)
		elseif tok.kind == "name" and not decl[k] then
			local nextTok = tokens[k + 1]
			if tok.text == "const" and nextTok and nextTok.kind == "name" and not isMember(tokens, k) then
				declareLocal(k)
			else
				for f = #stack, 1, -1 do
					local from = stack[f].names[tok.text]
					if from ~= nil and from <= k then
						bound[k] = true
						break
					end
				end
			end
		end
	end
	return { decl = decl, bound = bound }
end

-- ── T-META-01 ─────────────────────────────────────────────────────────────────────────────────────────────────

function Rules.strictHeader(path: string, src: string): { Problem }
	local out: { Problem } = {}
	local first = Lex.lines(src)[1] or ""
	if first ~= Rules.STRICT_HEADER then
		problem(out, path, 1, "line 1 must be exactly " .. Rules.STRICT_HEADER .. " (got " .. string.format("%q", first) .. ")")
	end
	return out
end

-- ── T-META-02 (token part; the allowlist and the @roblox-bound requires are checked by the spec) ─────────────

local BARE_FORBIDDEN = {
	game = true, workspace = true, script = true, Vector3 = true, CFrame = true, Color3 = true,
	DateTime = true, print = true, warn = true,
	-- SPEC §1.3 L3 ("no Roblox datatypes"), beyond §14.4's original token list:
	Enum = true, Vector2 = true, UDim = true, UDim2 = true, Rect = true, Ray = true, Region3 = true,
	BrickColor = true, TweenInfo = true, NumberRange = true, NumberSequence = true, ColorSequence = true,
	PhysicalProperties = true, RaycastParams = true, OverlapParams = true, Font = true,
}
local DOTTED_FORBIDDEN: { [string]: { [string]: boolean } } = {
	Instance = { new = true },
	Random = { new = true },
	math = { random = true },
	os = { time = true, clock = true, date = true },
}
-- SPEC §14.4's literal tokens tick( wait( task. are banned as tokens: a local of that name does not exempt them
-- (`local function tick()` and `local task = {}; task.id` fail too). A call with a table or string argument
-- (`wait {…}`, `tick "x"`) counts as tick( / wait(. Fields and methods (`self.tick(x)`, `obj:wait()`) and table keys
-- are not the tokens. Stricter than the list: the bare Roblox globals tick, wait and task used as values (an alias
-- such as `local w = wait`, `pcall(wait, 1)`, `typeof(task)`) are banned unless a local of that name is in scope.
local CALL_TOKENS = { tick = true, wait = true }
local SCOPED_GLOBALS = { tick = true, wait = true, task = true }

-- A name used as a key inside a table constructor or table type: `{ warn = c }`, `{ warn: Color }`.
local function isTableKey(tokens: { Token }, idx: number, brackets: { string }): boolean
	if brackets[#brackets] ~= "{" then
		return false
	end
	local prev, nextTok = tokens[idx - 1], tokens[idx + 1]
	if not (isOp(prev, "{") or isOp(prev, ",") or isOp(prev, ";")) then
		return false
	end
	return isOp(nextTok, "=") or (isOp(nextTok, ":") and not isCallOpener(tokens[idx + 3]))
end

function Rules.purity(path: string, src: string): { Problem }
	local out: { Problem } = {}
	local tokens = lexOrReport(path, src, out).tokens
	local scopes = Rules.scopes(tokens)
	local brackets: { string } = {}
	for idx, tok in tokens do
		if tok.kind == "op" and (tok.text == "(" or tok.text == "[" or tok.text == "{") then
			table.insert(brackets, tok.text)
		elseif tok.kind == "op" and (tok.text == ")" or tok.text == "]" or tok.text == "}") then
			table.remove(brackets)
		end
		if tok.kind ~= "name" or isMember(tokens, idx) or isTableKey(tokens, idx, brackets) then
			continue
		end
		local name = tok.text
		local nextTok, afterNext = tokens[idx + 1], tokens[idx + 2]
		if BARE_FORBIDDEN[name] then
			problem(out, path, tok.line, "pure module uses '" .. name .. "'")
		elseif DOTTED_FORBIDDEN[name] and isOp(nextTok, ".") and afterNext and afterNext.kind == "name"
			and DOTTED_FORBIDDEN[name][afterNext.text]
		then
			problem(out, path, tok.line, "pure module uses '" .. name .. "." .. afterNext.text .. "'")
		elseif CALL_TOKENS[name] and isCallOpener(nextTok) then
			problem(out, path, tok.line, "pure module uses '" .. name .. "(' (SPEC §14.4's token list; a local of that "
				.. "name does not exempt it)")
		elseif name == "task" and isOp(nextTok, ".") then
			problem(out, path, tok.line, "pure module uses 'task.' (SPEC §14.4's token list; a local of that name does "
				.. "not exempt it)")
		elseif SCOPED_GLOBALS[name] and not scopes.decl[idx] and not scopes.bound[idx] then
			problem(out, path, tok.line, "pure module uses '" .. name .. "' (the Roblox global as a value; no local of "
				.. "that name is in scope)")
		end
	end
	return out
end

-- ── T-META-03 ─────────────────────────────────────────────────────────────────────────────────────────────────

local TRANSCENDENTAL_PREFIXES = { "sin", "cos", "tan", "exp", "log", "pow", "atan", "asin", "acos" }

-- Lines carrying a comment that starts with "allow-transcendental: <reason>".
local function allowedLines(comments: { Lex.Comment }): { [number]: boolean }
	local lines: { [number]: boolean } = {}
	for _, c in comments do
		if c.line == c.endLine and string.match(c.text, "^%s*allow%-transcendental:%s*%S") then
			lines[c.line] = true
		end
	end
	return lines
end

function Rules.transcendental(path: string, src: string): { Problem }
	local out: { Problem } = {}
	local lexed = lexOrReport(path, src, out)
	local tokens = lexed.tokens
	local allowed = allowedLines(lexed.comments)
	for idx, tok in tokens do
		if allowed[tok.line] then
			continue
		end
		if tok.kind == "name" and tok.text == "math" and not isMember(tokens, idx) and isOp(tokens[idx + 1], ".") then
			local fn = tokens[idx + 2]
			if fn and fn.kind == "name" then
				for _, prefix in TRANSCENDENTAL_PREFIXES do
					if string.sub(fn.text, 1, #prefix) == prefix then
						problem(out, path, tok.line, "uses math." .. fn.text .. " (exact + − × ÷ and sqrt only, or tag the line "
							.. "-- " .. Rules.ALLOW_TRANSCENDENTAL .. ": <reason>)")
						break
					end
				end
			end
		elseif tok.kind == "op" and (tok.text == "^" or tok.text == "^=") then
			problem(out, path, tok.line, "uses '" .. tok.text .. "' (powers by repeated multiplication, or tag the line "
				.. "-- " .. Rules.ALLOW_TRANSCENDENTAL .. ": <reason>)")
		end
	end
	-- §4.1: no native code generation in an authoritative module until S8's cross-platform digest passes
	for _, c in lexed.comments do
		if string.match(c.text, "^!native") then
			problem(out, path, c.line, "--!native in an authoritative module (SPEC §4.1)")
		end
	end
	for idx, tok in tokens do
		if isOp(tok, "@") and tokens[idx + 1] and tokens[idx + 1].text == "native" then
			problem(out, path, tok.line, "@native in an authoritative module (SPEC §4.1)")
		end
	end
	return out
end

-- ── T-META-04 ─────────────────────────────────────────────────────────────────────────────────────────────────

local COMPOUND: { [string]: boolean } = {
	["+="] = true, ["-="] = true, ["*="] = true, ["/="] = true, ["//="] = true, ["%="] = true, ["^="] = true,
}
local ARITH: { [string]: boolean } = {
	["+"] = true, ["-"] = true, ["*"] = true, ["/"] = true, ["//"] = true, ["%"] = true, ["^"] = true,
}
local CONTINUES: { [string]: boolean } = {
	["+"] = true, ["-"] = true, ["*"] = true, ["/"] = true, ["//"] = true, ["%"] = true, ["^"] = true,
	[".."] = true, ["("] = true, ["["] = true, ["."] = true, [":"] = true,
}

local function isIntegerLiteral(tok: Token?): boolean
	if tok == nil or tok.kind ~= "number" then
		return false
	end
	local t = tok.text
	return string.match(t, "^%d[%d_]*$") ~= nil or string.match(t, "^0[xX][%x_]+$") ~= nil
		or string.match(t, "^0[bB][01_]+$") ~= nil
end

-- Start index of the assignable expression that ends at tokens[last] (a, a.b, a[k], f(x).y), or nil.
local function lvalueStart(tokens: { Token }, last: number): number?
	local k = last
	local start: number? = nil
	while k >= 1 do
		local tok = tokens[k]
		if tok.kind == "name" then
			start = k
			if isOp(tokens[k - 1], ".") or isOp(tokens[k - 1], ":") then
				k -= 2
			else
				break
			end
		elseif isOp(tok, "]") or isOp(tok, ")") then
			local open = if tok.text == "]" then "[" else "("
			local depth = 0
			local j = k
			while j >= 1 do
				if isOp(tokens[j], tok.text) then
					depth += 1
				elseif isOp(tokens[j], open) then
					depth -= 1
					if depth == 0 then
						break
					end
				end
				j -= 1
			end
			k = j - 1
		else
			break
		end
	end
	return start
end

local function textOf(tokens: { Token }, from: number, to: number): string
	local parts = {}
	for k = from, to do
		table.insert(parts, tokens[k].text)
	end
	return table.concat(parts)
end

-- Kinds of generic-for iteration. "keyed": pairs(t), next, t, or a table expression (generalized iteration);
-- "ordered": ipairs(t) or another iterator call (gmatch, a sorted-keys helper).
local function iterationKind(tokens: { Token }, inIdx: number, doIdx: number): "keyed" | "ordered"
	local first = tokens[inIdx + 1]
	if first and first.kind == "name" and (first.text == "pairs" or first.text == "next") then
		return "keyed"
	elseif first and first.kind == "name" and first.text == "ipairs" then
		return "ordered"
	elseif isOp(tokens[doIdx - 1], ")") then
		-- ordered only when the final ")" closes a call: `iter(t)`, `a.b(t)`, `f()(t)`, not a parenthesized `(t)`
		local depth = 0
		local j = doIdx - 1
		while j > inIdx do
			if isOp(tokens[j], ")") then
				depth += 1
			elseif isOp(tokens[j], "(") then
				depth -= 1
				if depth == 0 then
					break
				end
			end
			j -= 1
		end
		local before = tokens[j - 1]
		if j - 1 > inIdx and before and (before.kind == "name" or isOp(before, ")") or isOp(before, "]")) then
			return "ordered"
		end
	end
	return "keyed"
end

local STATEMENT_KEYWORDS: { [string]: boolean } = {
	["end"] = true, ["until"] = true, ["local"] = true, ["return"] = true, ["for"] = true, ["while"] = true,
	["repeat"] = true, ["do"] = true, ["break"] = true,
}

-- Tokens of the right-hand side of the assignment whose "=" is tokens[eq]: the rest of its line, plus following
-- lines while a bracket is open or an operator joins the lines; it stops at a statement keyword.
local function rhsOf(tokens: { Token }, eq: number, limit: number): { Token }
	local rhs: { Token } = {}
	local depth = 0
	local m = eq + 1
	while m <= limit do
		local t = tokens[m]
		local prev = tokens[m - 1]
		local joined = (prev.kind == "op" and CONTINUES[prev.text] == true) or (t.kind == "op" and CONTINUES[t.text] == true)
		if t.line ~= tokens[eq].line and depth <= 0 and not joined then
			break
		end
		if depth <= 0 and t.kind == "keyword" and STATEMENT_KEYWORDS[t.text] then
			break
		end
		if t.kind == "op" and (t.text == "(" or t.text == "[" or t.text == "{") then
			depth += 1
		elseif t.kind == "op" and (t.text == ")" or t.text == "]" or t.text == "}") then
			depth -= 1
		end
		table.insert(rhs, t)
		m += 1
	end
	return rhs
end

local function sameTokens(a: { Token }, aFrom: number, b: { Token }, bFrom: number, width: number): boolean
	for w = 0, width - 1 do
		local x, y = a[aFrom + w], b[bFrom + w]
		if x == nil or y == nil or x.kind ~= y.kind or x.text ~= y.text then
			return false
		end
	end
	return true
end

-- Does the statement whose operator is tokens[k] (a compound "op=" or a plain "=") accumulate into its target?
-- Counters (`n += 1`, `n = n + 1`) are exact for integers and do not count.
local function accumulates(tokens: { Token }, k: number, start: number, limit: number): boolean
	local op = tokens[k]
	if COMPOUND[op.text] then
		local nextTok, afterTok = tokens[k + 1], tokens[k + 2]
		local counter = (op.text == "+=" or op.text == "-=") and isIntegerLiteral(nextTok)
			and not (afterTok ~= nil and nextTok ~= nil and afterTok.line == nextTok.line and afterTok.kind == "op"
				and CONTINUES[afterTok.text] == true)
		return not counter
	end
	local rhs = rhsOf(tokens, k, limit)
	local width = k - start
	if #rhs == width + 2 and sameTokens(rhs, 1, tokens, start, width) and isIntegerLiteral(rhs[width + 2])
		and (isOp(rhs[width + 1], "+") or isOp(rhs[width + 1], "-"))
	then
		return false
	end
	for r = 1, #rhs - width + 1 do
		if sameTokens(rhs, r, tokens, start, width) then
			local before, after = rhs[r - 1], rhs[r + width]
			local extended = isOp(before, ".") or isOp(before, ":") or isOp(after, ".") or isOp(after, "[")
				or isOp(after, "(") or isOp(after, ":")
			local nextToArith = (before ~= nil and before.kind == "op" and ARITH[before.text] == true)
				or (after ~= nil and after.kind == "op" and ARITH[after.text] == true)
			if nextToArith and not extended then
				return true
			end
		end
	end
	return false
end

function Rules.keyedAccumulation(path: string, src: string): { Problem }
	local out: { Problem } = {}
	local tokens = lexOrReport(path, src, out).tokens
	local closeOf = blockEnds(tokens)
	for forIdx, forTok in tokens do
		if not isKeyword(forTok, "for") then
			continue
		end
		-- header: find `in` (generic for) and the loop's `do`, skipping function bodies inside the header
		local j = forIdx + 1
		local inIdx: number? = nil
		local doIdx: number? = nil
		while j <= #tokens do
			local t = tokens[j]
			if isKeyword(t, "do") then
				doIdx = j
				break
			elseif isKeyword(t, "in") and inIdx == nil then
				inIdx = j
			elseif isKeyword(t, "function") and closeOf[j] then
				j = closeOf[j]
			end
			j += 1
		end
		if inIdx == nil or doIdx == nil or closeOf[doIdx] == nil or iterationKind(tokens, inIdx, doIdx) ~= "keyed" then
			continue
		end
		local bodyTo = closeOf[doIdx] - 1
		local declared = declaredNames(tokens, forIdx, bodyTo)
		-- bracket context: an "=" directly inside "{" is a table field, not an assignment
		local brackets: { string } = {}
		local functionEnds: { number } = {}
		for k = doIdx + 1, bodyTo do
			local tok = tokens[k]
			if functionEnds[#functionEnds] == k then
				table.remove(functionEnds)
				table.remove(brackets)
			end
			if isKeyword(tok, "function") and closeOf[k] then
				table.insert(functionEnds, closeOf[k])
				table.insert(brackets, "function")
			elseif tok.kind == "op" and (tok.text == "(" or tok.text == "[" or tok.text == "{") then
				table.insert(brackets, tok.text)
			elseif tok.kind == "op" and (tok.text == ")" or tok.text == "]" or tok.text == "}") then
				table.remove(brackets)
			elseif tok.kind == "op" and (COMPOUND[tok.text] or tok.text == "=") and brackets[#brackets] ~= "{" then
				local start = lvalueStart(tokens, k - 1)
				if start == nil then
					continue
				end
				-- walk back over "a, b, c" to skip local declarations and numeric for headers
				local s: number = start
				while isOp(tokens[s - 1], ",") do
					local prevStart = lvalueStart(tokens, s - 2)
					if prevStart == nil then
						break
					end
					s = prevStart
				end
				if isKeyword(tokens[s - 1], "local") or isKeyword(tokens[s - 1], "for") or declared[tokens[start].text] then
					continue
				end
				if accumulates(tokens, k, start, bodyTo) then
					problem(out, path, tok.line, string.format("accumulates into '%s' while iterating a possibly keyed "
						.. "table (for at line %d): iterate arrays with ipairs or a numeric for (SPEC §4.1, §6.4)",
						textOf(tokens, start, k - 1), forTok.line))
				end
			end
		end
	end
	return out
end

-- ── T-META-06 ─────────────────────────────────────────────────────────────────────────────────────────────────

function Rules.reconcile(path: string, src: string): { Problem }
	local out: { Problem } = {}
	local tokens = lexOrReport(path, src, out).tokens
	for idx, tok in tokens do
		if tok.kind == "name" and tok.text == "Reconcile" and (isOp(tokens[idx - 1], ":") or isOp(tokens[idx - 1], "."))
			and isCallOpener(tokens[idx + 1])
		then
			problem(out, path, tok.line, "calls " .. tokens[idx - 1].text .. "Reconcile( (the load pipeline replaces "
				.. "ProfileStore's Reconcile, SPEC §9.6)")
		end
	end
	return out
end

return Rules
