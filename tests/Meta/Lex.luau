--!strict
-- tests/Meta/Lex.luau — Luau tokenizer for the meta rules (SPEC §14.4: "token scans skip strings and comments").
-- Strings, long strings and comments become single tokens or comment records, so rules only see code; the code
-- inside `{...}` of an interpolated string is tokenized as code. Never throws: problems go to `errors`.
-- Pure Luau, no requires.

export type Kind = "name" | "keyword" | "number" | "string" | "istring" | "op"
export type Token = {
	kind: Kind,
	text: string, -- source text; for "string" the decoded value; for "istring" the backquote
	line: number,
}
export type Comment = { line: number, endLine: number, text: string }
export type Result = { tokens: { Token }, comments: { Comment }, errors: { string } }

local Lex = {}

local KEYWORDS: { [string]: boolean } = {}
for _, k in
	{
		"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil",
		"not", "or", "repeat", "return", "then", "true", "until", "while",
	}
do
	KEYWORDS[k] = true
end
Lex.KEYWORDS = KEYWORDS

local OPS3 = { ["..."] = true, ["//="] = true, ["..="] = true }
local OPS2 = {
	["=="] = true, ["~="] = true, ["<="] = true, [">="] = true, ["//"] = true, [".."] = true, ["->"] = true,
	["::"] = true, ["+="] = true, ["-="] = true, ["*="] = true, ["/="] = true, ["%="] = true, ["^="] = true,
}

local SIMPLE_ESCAPES: { [string]: string } = {
	n = "\n", t = "\t", r = "\r", a = "\a", b = "\b", f = "\f", v = "\v",
	["\\"] = "\\", ['"'] = '"', ["'"] = "'", ["`"] = "`", ["{"] = "{", ["}"] = "}",
}

function Lex.lex(src: string): Result
	local tokens: { Token } = {}
	local comments: { Comment } = {}
	local errors: { string } = {}
	local n = #src
	local i = 1
	local line = 1
	-- one entry per open interpolated-string expression: the brace depth inside that expression
	local interp: { number } = {}

	local function push(kind: Kind, text: string, atLine: number)
		table.insert(tokens, { kind = kind, text = text, line = atLine })
	end

	local function countLines(s: string)
		for _ in string.gmatch(s, "\n") do
			line += 1
		end
	end

	-- Long bracket at position p ("[", "="*, "["): returns the level or nil.
	local function longOpen(p: number): number?
		local eq = string.match(src, "^%[(=*)%[", p)
		return if eq then #eq else nil
	end

	-- Reads a long bracket body starting at p (on the opening "["). Returns the body and the index after it.
	local function longBody(p: number, level: number): (string, number)
		local open = p + level + 2
		local close = "]" .. string.rep("=", level) .. "]"
		local s, e = string.find(src, close, open, true)
		local body: string
		local after: number
		if s == nil or e == nil then
			table.insert(errors, string.format("line %d: unterminated long bracket", line))
			body = string.sub(src, open)
			after = n + 1
		else
			body = string.sub(src, open, s - 1)
			after = e + 1
		end
		countLines(body)
		if string.sub(body, 1, 2) == "\r\n" then
			body = string.sub(body, 3)
		elseif string.sub(body, 1, 1) == "\n" then
			body = string.sub(body, 2)
		end
		return body, after
	end

	-- Quoted string from p (on the quote). Returns the decoded value and the index after the closing quote.
	local function quoted(p: number, q: string): (string, number)
		local parts: { string } = {}
		local j = p + 1
		while true do
			if j > n then
				table.insert(errors, string.format("line %d: unterminated string", line))
				return table.concat(parts), j
			end
			local c = string.sub(src, j, j)
			if c == q then
				return table.concat(parts), j + 1
			elseif c == "\n" then
				table.insert(errors, string.format("line %d: unterminated string", line))
				return table.concat(parts), j
			elseif c == "\\" then
				local e = string.sub(src, j + 1, j + 1)
				if SIMPLE_ESCAPES[e] then
					table.insert(parts, SIMPLE_ESCAPES[e])
					j += 2
				elseif e == "\n" then
					table.insert(parts, "\n")
					line += 1
					j += 2
				elseif e == "\r" then
					table.insert(parts, "\n")
					line += 1
					j += if string.sub(src, j + 2, j + 2) == "\n" then 3 else 2
				elseif e == "z" then
					j += 2
					while j <= n and string.find(string.sub(src, j, j), "^%s") do
						if string.sub(src, j, j) == "\n" then
							line += 1
						end
						j += 1
					end
				elseif e == "x" then
					local hex = string.match(src, "^%x%x", j + 2)
					table.insert(parts, if hex then string.char(tonumber(hex, 16) :: number) else "")
					j += 2 + (if hex then 2 else 0)
				elseif e == "u" then
					local hex = string.match(src, "^{(%x+)}", j + 2)
					local code = if hex then tonumber(hex, 16) else nil
					if code and code <= 0x10FFFF then
						table.insert(parts, utf8.char(code))
					end
					j += 2 + (if hex then #hex + 2 else 0)
				elseif string.find(e, "^%d") then
					local digits = string.match(src, "^%d%d?%d?", j + 1) :: string
					local code = tonumber(digits) :: number
					table.insert(parts, string.char(math.min(code, 255)))
					j += 1 + #digits
				else
					table.insert(parts, e)
					j += 2
				end
			else
				local s = string.find(src, "[\\\n" .. q .. "]", j)
				local stop = if s then s - 1 else n
				table.insert(parts, string.sub(src, j, stop))
				j = stop + 1
			end
		end
	end

	-- Body of an interpolated string from p (just after "`" or after the "}" that closes an expression).
	-- Returns the index after the closing "`", or after the "{" that opens an expression (pushing interp).
	local function interpBody(p: number): number
		local j = p
		while j <= n do
			local c = string.sub(src, j, j)
			if c == "`" then
				return j + 1
			elseif c == "{" then
				table.insert(interp, 0)
				return j + 1
			elseif c == "\\" then
				if string.sub(src, j + 1, j + 1) == "\n" then
					line += 1
				end
				j += 2
			else
				if c == "\n" then
					line += 1
				end
				j += 1
			end
		end
		table.insert(errors, string.format("line %d: unterminated interpolated string", line))
		return n + 1
	end

	while i <= n do
		local c = string.sub(src, i, i)
		if c == "\n" then
			line += 1
			i += 1
		elseif c == " " or c == "\t" or c == "\r" or c == "\v" or c == "\f" then
			i += 1
		elseif c == "-" and string.sub(src, i + 1, i + 1) == "-" then
			local startLine = line
			local level = longOpen(i + 2)
			if level then
				local body, after = longBody(i + 2, level)
				table.insert(comments, { line = startLine, endLine = line, text = body })
				i = after
			else
				local e = string.find(src, "\n", i + 2, true)
				local stop = if e then e - 1 else n
				table.insert(comments, { line = startLine, endLine = startLine, text = string.sub(src, i + 2, stop) })
				i = stop + 1
			end
		elseif string.find(c, "^[%a_]") then
			local word = string.match(src, "^[%w_]+", i) :: string
			push(if KEYWORDS[word] then "keyword" else "name", word, line)
			i += #word
		elseif string.find(c, "^%d") or (c == "." and string.find(string.sub(src, i + 1, i + 1), "^%d")) then
			local text: string
			local two = string.lower(string.sub(src, i, i + 1))
			if two == "0x" then
				text = string.match(src, "^0[xX][%x_]*", i) :: string
			elseif two == "0b" then
				text = string.match(src, "^0[bB][01_]*", i) :: string
			else
				text = string.match(src, "^[%d_]*%.?[%d_]*", i) :: string
				local exp = string.match(src, "^[eE][%+%-]?[%d_]+", i + #text)
				if exp then
					text ..= exp
				end
			end
			push("number", text, line)
			i += #text
		elseif c == '"' or c == "'" then
			local startLine = line
			local value, after = quoted(i, c)
			push("string", value, startLine)
			i = after
		elseif c == "[" and longOpen(i) then
			local startLine = line
			local body, after = longBody(i, longOpen(i) :: number)
			push("string", body, startLine)
			i = after
		elseif c == "`" then
			push("istring", "`", line)
			i = interpBody(i + 1)
		elseif c == "{" and #interp > 0 then
			interp[#interp] += 1
			push("op", "{", line)
			i += 1
		elseif c == "}" and #interp > 0 then
			if interp[#interp] == 0 then
				table.remove(interp)
				i = interpBody(i + 1)
			else
				interp[#interp] -= 1
				push("op", "}", line)
				i += 1
			end
		else
			local three = string.sub(src, i, i + 2)
			local two = string.sub(src, i, i + 1)
			if OPS3[three] then
				push("op", three, line)
				i += 3
			elseif OPS2[two] then
				push("op", two, line)
				i += 2
			else
				push("op", c, line)
				i += 1
			end
		end
	end
	if #interp > 0 then
		table.insert(errors, "unterminated interpolated string expression")
	end
	return { tokens = tokens, comments = comments, errors = errors }
end

-- Source lines without their line terminators (CRLF tolerant).
function Lex.lines(src: string): { string }
	local lines = string.split(src, "\n")
	for k, l in lines do
		if string.sub(l, -1) == "\r" then
			lines[k] = string.sub(l, 1, -2)
		end
	end
	return lines
end

return Lex
