--!strict
-- tests/Meta/GlobalTypes.luau — is tools/luau-lsp/globalTypes.None.d.luau usable (SPEC §14.4)? scripts/verify runs
-- the check before luau-lsp, because luau-lsp 1.70.1 loads an empty definitions file silently (Roblox globals are
-- then unknown, which only shows if some file uses them) and reports a broken one as stray output in pass A.
-- tests/Meta/Tools.spec.luau plants broken files. The check, in order:
--   size      at least MIN_BYTES (the pinned 1.70.1 file is 677,555 bytes, tools/README.md)
--   ending    the text ends with a newline (a cut download rarely does)
--   tokens    Lex tokenizes it (no unterminated string, comment or long bracket)
--   brackets  ( [ { close in order and none is left open
--   blocks    every `declare extern type … with` opens a block that one `end` closes; blocks do not nest; at least
--             MIN_BLOCKS of them
--   globals   `declare <name>:` for each REQUIRED global the project's Roblox-bound code and luau-lsp pass A need
-- Pure: text in, (reason or nil, stats) out. Lune-only folder, not a Rojo root.

local Lex = require("./Lex")

export type Stats = { bytes: number, blocks: number, tokens: number }

local GlobalTypes = {}

GlobalTypes.MIN_BYTES = 100000
GlobalTypes.MIN_BLOCKS = 500 -- the pinned file has 2,238
GlobalTypes.REQUIRED = table.freeze({
	"game", "workspace", "script", "Enum", "Instance", "Vector3", "CFrame", "Color3", "task",
})
-- what luau-lsp 1.70.1 prints on stderr when it cannot parse a definitions file (checked by tests/Meta/Tools)
GlobalTypes.LUAU_LSP_REJECTS = "Failed to read definitions file"

local CLOSER: { [string]: string } = { [")"] = "(", ["]"] = "[", ["}"] = "{" }

-- nil when text is a usable definitions file, else the first reason it is not.
function GlobalTypes.check(text: string): (string?, Stats)
	local stats: Stats = { bytes = #text, blocks = 0, tokens = 0 }
	if #text < GlobalTypes.MIN_BYTES then
		return string.format("only %d bytes (an empty or cut file; at least %d expected)", #text, GlobalTypes.MIN_BYTES),
			stats
	end
	if string.sub(text, -1) ~= "\n" then
		return "does not end with a newline (a cut download?)", stats
	end
	local lexed = Lex.lex(text)
	stats.tokens = #lexed.tokens
	if #lexed.errors > 0 then
		return "does not tokenize: " .. lexed.errors[1], stats
	end
	local open: { { text: string, line: number } } = {}
	local blockLine: number? = nil
	local declared: { [string]: boolean } = {}
	local tokens = lexed.tokens
	for i, tok in tokens do
		if tok.kind == "op" then
			local op: string = tok.text
			if op == "(" or op == "[" or op == "{" then
				table.insert(open, { text = tok.text :: string, line = tok.line })
			elseif CLOSER[tok.text] then
				local top = table.remove(open)
				if top == nil or top.text ~= CLOSER[tok.text] then
					return string.format("unbalanced '%s' on line %d", tok.text, tok.line), stats
				end
			end
		elseif tok.kind == "name" and tok.text == "with" then
			if blockLine then
				return string.format("a declaration opened on line %d has no 'end' before line %d", blockLine, tok.line),
					stats
			end
			blockLine = tok.line
			stats.blocks += 1
		elseif tok.kind == "keyword" and tok.text == "end" then
			if blockLine == nil then
				return string.format("an 'end' without a declaration on line %d", tok.line), stats
			end
			blockLine = nil
		elseif tok.kind == "name" and tok.text == "declare" then
			local name, colon = tokens[i + 1], tokens[i + 2]
			if name and name.kind == "name" and colon and colon.kind == "op" and colon.text == ":" then
				declared[name.text] = true
			end
		end
	end
	if blockLine then
		return string.format("the declaration opened on line %d is never closed (a cut file?)", blockLine), stats
	end
	if #open > 0 then
		local top = open[#open]
		return string.format("'%s' on line %d is never closed (a cut file?)", top.text, top.line), stats
	end
	if stats.blocks < GlobalTypes.MIN_BLOCKS then
		return string.format("only %d declaration blocks (at least %d expected)", stats.blocks, GlobalTypes.MIN_BLOCKS),
			stats
	end
	for _, name in GlobalTypes.REQUIRED do
		if not declared[name] then
			return "lacks the global " .. name .. " ('declare " .. name .. ":')", stats
		end
	end
	return nil, stats
end

return table.freeze(GlobalTypes)
