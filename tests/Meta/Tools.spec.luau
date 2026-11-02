--!strict
-- The Roblox definitions check scripts/verify runs before luau-lsp (tests/Meta/GlobalTypes, SPEC §14.4): the pinned
-- file passes; empty, cut, foreign and broken files are refused; verify calls the check before its luau-lsp stage and
-- stops on luau-lsp's own refusal; and luau-lsp 1.70.1 behaves as the check assumes (an empty file loads silently, a
-- file it cannot parse prints GlobalTypes.LUAU_LSP_REJECTS).

local fs = require("@lune/fs")
local process = require("@lune/process")
local Test = require("../lib/Test")
local A = require("../lib/Assert")
local GlobalTypes = require("./GlobalTypes")
local Lex = require("./Lex")

local DEFINITIONS = "tools/luau-lsp/globalTypes.None.d.luau"

local function refused(text: string, needle: string, what: string)
	local why = GlobalTypes.check(text)
	if why == nil then
		A.fail("planted definitions file accepted: " .. what)
	end
	A.contains(why :: string, needle, what)
end

-- text with the first plain occurrence of `from` at or after byte `init` replaced by `to`.
local function replaceFirst(text: string, from: string, to: string, init: number?): string
	local s, e = string.find(text, from, init or 1, true)
	assert(s and e, "replaceFirst: " .. from .. " not found")
	return string.sub(text, 1, s - 1) .. to .. string.sub(text, e + 1)
end

local function tempDir(): string
	local base = process.env.TEMP or process.env.TMPDIR or "/tmp"
	local dir = string.format("%s/blacksmith-defs-%d-%d", base, os.time(), math.floor(os.clock() * 1e6) % 1000000)
	fs.writeDir(dir)
	return dir
end

-- The line of the first token sequence equal to `texts` in src, or nil.
local function lineOf(src: string, texts: { string }): number?
	local tokens = Lex.lex(src).tokens
	for i = 1, #tokens - #texts + 1 do
		local all = true
		for k, text in texts do
			if tokens[i + k - 1].text ~= text then
				all = false
				break
			end
		end
		if all then
			return tokens[i].line
		end
	end
	return nil
end

return Test.suite("Meta/Tools", function(t)
	t.it("the pinned Roblox definitions file passes the check", function()
		local why, stats = GlobalTypes.check(fs.readFile(DEFINITIONS))
		A.eq(why, nil, DEFINITIONS)
		A.truthy(stats.bytes >= GlobalTypes.MIN_BYTES and stats.blocks >= GlobalTypes.MIN_BLOCKS, "size and blocks")
	end)

	t.it("empty, cut and foreign files are refused", function()
		local real = fs.readFile(DEFINITIONS)
		refused("", "only 0 bytes", "an empty file")
		refused(string.sub(real, 1, 50000), "bytes", "the first 50 KB")
		for _, fraction in { 0.25, 0.5, 0.75, 0.9, 0.99 } do
			local cut = string.sub(real, 1, math.floor(#real * fraction))
			A.truthy(GlobalTypes.check(cut) ~= nil, string.format("a file cut at %d%%", fraction * 100))
		end
		refused((string.gsub(real, "\n+$", "")), "newline", "the final line breaks cut")
		-- cut on a line break right after a complete block: only the missing globals give it away
		local at = string.find(real, "\nend\n", 400000, true) :: number
		refused(string.sub(real, 1, at + 4), "lacks the global", "a file cut after a complete block")
		refused(string.rep("-- not a definitions file\n", 6000), "declaration blocks", "a large foreign file")
	end)

	t.it("broken syntax is refused: brackets, a lost end, an open string, a renamed global", function()
		local real = fs.readFile(DEFINITIONS)
		refused(replaceFirst(real, "{", "", 100000), "unbalanced '}'", "a lost {")
		refused(replaceFirst(real, ")", "", 100000), "is never closed", "a lost )")
		refused(replaceFirst(real, "\nend\n", "\n\n", 100000), "has no 'end'", "a lost end")
		refused(replaceFirst(real, "\ndeclare ", '\n"declare ', 100000), "does not tokenize", "an unterminated string")
		refused(replaceFirst(real, "\ndeclare game:", "\ndeclare gam:"), "lacks the global game", "game renamed")
		refused(replaceFirst(real, "\ndeclare Vector3:", "\ndeclare Vectr3:"), "lacks the global Vector3",
			"Vector3 renamed")
	end)

	t.it("scripts/verify runs the check before its luau-lsp stage and stops on luau-lsp's refusal", function()
		local src = fs.readFile("scripts/verify.luau")
		local check = lineOf(src, { "GlobalTypes", ".", "check", "(" })
		local passes = lineOf(src, { "local", "PASSES", "=" })
		local refusal = lineOf(src, { "GlobalTypes", ".", "LUAU_LSP_REJECTS" })
		A.truthy(check ~= nil and passes ~= nil and refusal ~= nil, "verify calls GlobalTypes.check and watches "
			.. "GlobalTypes.LUAU_LSP_REJECTS")
		A.truthy((check :: number) < (passes :: number), "the check comes before the luau-lsp passes")
		A.truthy((refusal :: number) > (passes :: number), "the refusal is watched in the luau-lsp stage")
	end)

	t.slow("luau-lsp loads an empty definitions file silently and names one it cannot parse", function()
		local dir = tempDir()
		local ok, err = pcall(function()
			local probe = dir .. "/probe.luau"
			fs.writeFile(probe, "--!strict\nlocal v = Vector3.new(1, 2, 3)\nreturn v\n")
			fs.writeFile(dir .. "/empty.d.luau", "")
			fs.writeFile(dir .. "/cut.d.luau", string.sub(fs.readFile(DEFINITIONS), 1, 300000))
			local function analyze(defs: string): process.SpawnResult
				return process.spawn("luau-lsp", {
					"analyze", "--platform=roblox", "--definitions:@roblox=" .. dir .. "/" .. defs, "--formatter=plain", probe,
				})
			end
			local empty = analyze("empty.d.luau")
			A.falsy(string.find(empty.stderr, GlobalTypes.LUAU_LSP_REJECTS, 1, true), "an empty file loads silently")
			A.contains(empty.stdout, "Unknown global 'Vector3'", "only a use of a Roblox global shows it")
			local cut = analyze("cut.d.luau")
			A.contains(cut.stderr, GlobalTypes.LUAU_LSP_REJECTS, "a cut file is refused by name")
		end)
		fs.removeDir(dir)
		if not ok then
			error(err, 0)
		end
	end)
end)
