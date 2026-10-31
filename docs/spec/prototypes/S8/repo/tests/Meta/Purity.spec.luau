--!strict
-- Static rules enforced as tests (no external linter needed):
--  1. every .luau under src/ and tests/ starts with --!strict
--  2. src/shared (except Net/) uses no Roblox globals, services, clocks or math.random
--  3. authoritative folders avoid transcendental math unless the line carries an allow pragma
local fs = require("@lune/fs")
local Test = require("../lib/Test")
local A = require("../lib/Assert")

local function walk(dir: string, out: { string })
	if not fs.isDir(dir) then
		return
	end
	local entries = fs.readDir(dir)
	table.sort(entries)
	for _, name in entries do
		local p = dir .. "/" .. name
		if fs.isDir(p) then
			walk(p, out)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(out, p)
		end
	end
end

-- plain-text tokens, matched on code with trailing comments stripped
local FORBIDDEN_PURE = {
	"game:", "game.", "workspace", "Instance.new", "Vector3", "CFrame", "Color3", "Random.new",
	"math.random", "os.time", "os.clock", "tick(", "DateTime", "task.", "wait(", "script.", "require(script",
}
local TRANSCENDENTAL = { "math.sin", "math.cos", "math.tan", "math.exp", "math.log", "math.pow", "math.atan", "math.asin", "math.acos", "^" }
local AUTHORITATIVE = { "src/shared/Physics", "src/shared/Minigames", "src/shared/Crafting" }
-- usage: local a = math.atan2(y, x) -- allow-transcendental: editor display only
local ALLOW = "allow-transcendental"

-- strip string literals first (so "2^32" in a message is not code), then trailing comments
local function codeOf(line: string): string
	local s = string.gsub(line, '"[^"]*"', '""')
	s = string.gsub(s, "'[^']*'", "''")
	s = string.gsub(s, "%-%-.*$", "")
	return s
end

return Test.suite("Meta/Purity", function(t)
	t.it("every source and test file starts with --!strict", function()
		local files = {}
		walk("src", files)
		walk("tests", files)
		A.truthy(#files > 0, "no files found")
		for _, f in files do
			local first = string.match(fs.readFile(f), "^[^\r\n]*") or ""
			A.eq(first, "--!strict", f)
		end
	end)

	t.it("src/shared is pure Luau (Net/ excepted)", function()
		local files = {}
		walk("src/shared", files)
		for _, f in files do
			if string.find(f, "src/shared/Net/", 1, true) then
				continue
			end
			for n, line in string.split(fs.readFile(f), "\n") do
				local code = codeOf(line)
				for _, tok in FORBIDDEN_PURE do
					if string.find(code, tok, 1, true) then
						A.fail(string.format("%s:%d uses '%s' in pure code", f, n, tok))
					end
				end
			end
		end
	end)

	t.it("authoritative modules avoid transcendental math without an allow pragma", function()
		for _, dir in AUTHORITATIVE do
			local files = {}
			walk(dir, files)
			for _, f in files do
				if string.find(f, "Proto", 1, true) then
					continue -- prototypes exempt
				end
				for n, line in string.split(fs.readFile(f), "\n") do
					if string.find(line, ALLOW, 1, true) then
						continue
					end
					local code = codeOf(line)
					for _, tok in TRANSCENDENTAL do
						if string.find(code, tok, 1, true) then
							A.fail(string.format("%s:%d uses '%s' (IEEE-exact ops only, or add -- %s: <reason>)", f, n, tok, ALLOW))
						end
					end
				end
			end
		end
	end)
end)
