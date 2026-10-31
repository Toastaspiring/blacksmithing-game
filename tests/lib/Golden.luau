--!strict
-- tests/lib/Golden.luau — golden files (SPEC §14.3, §14.9). A golden is Dump.canonical text in
-- <dir>/<name>.golden.txt; versioned goldens put the version in the name ("<name>.bv<N>"). `--bless` rewrites them:
-- review the diff before committing. Lune-only (@lune/fs): Studio reads digests, never this module.
-- The runner and the specs share this module instance (Lune caches modules per file), which carries --bless.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Dump = require("./Dump")

local Golden = {
	bless = false, -- set by the runner from --bless
	dir = "tests/golden", -- relative to the repo root (the runner's working directory)
}

local function pathOf(name: string): string
	if not string.match(name, "^[%w_%-%.]+$") or string.find(name, "..", 1, true) then
		error("Golden: name must match [A-Za-z0-9_.-]+ without '..': " .. name, 3)
	end
	return Golden.dir .. "/" .. name .. ".golden.txt"
end

-- Line endings are normalized, so a checkout with CRLF conversion still matches.
local function readText(path: string): string
	return (string.gsub(fs.readFile(path), "\r\n", "\n"))
end

-- The blessed value, or nil when the file is missing.
function Golden.read(name: string): any
	local path = pathOf(name)
	if not fs.isFile(path) then
		return nil
	end
	local text = readText(path)
	return luau.load("return " .. text, { debugName = path })()
end

-- Compares value with the blessed text; with bless = true it writes the file instead.
function Golden.check(name: string, value: any)
	local path = pathOf(name)
	local text = Dump.canonical(value) .. "\n"
	if Golden.bless then
		fs.writeFile(path, text)
		return
	end
	if not fs.isFile(path) then
		error("assert: golden file missing: " .. path .. " (run with -- --bless, then review the diff)", 2)
	end
	local expected = readText(path)
	if expected ~= text then
		local at = 1
		while at <= #text and string.byte(text, at) == string.byte(expected, at) do
			at += 1
		end
		local from = math.max(1, at - 40)
		error(string.format("assert: golden mismatch for %s at byte %d (if intended: bump BALANCE_VERSION when "
			.. "balance data changed, then -- --bless)\n  expected ...%s\n  actual   ...%s", path, at,
			string.sub(expected, from, at + 80), string.sub(text, from, at + 80)), 2)
	end
end

return Golden
