--!strict
-- tests/lib/Golden.luau — golden files (SPEC §14.2, §14.3, §14.9). A golden is Dump.canonical text in
-- <dir>/<name>.golden.txt; versioned goldens put the version in the name ("<name>.bv<N>"). A digest is a golden that
-- Studio reads too, <dir>/<name>.digest.txt, at most DIGEST_MAX_BYTES (§14.2; Rojo makes it a StringValue named
-- "<name>.digest"). `--bless` rewrites both: review the diff before committing. Lune-only (@lune/fs): Studio reads
-- digests, never this module.
-- The runner and the specs share this module instance (Lune caches modules per file), which carries --bless.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Dump = require("./Dump")

local Golden = {
	bless = false, -- set by the runner from --bless
	dir = "tests/golden", -- relative to the repo root (the runner's working directory)
	DIGEST_MAX_BYTES = 1024, -- §14.2: what a Studio snippet reads stays small
}

local function pathOf(name: string, suffix: string): string
	if not string.match(name, "^[%w_%-%.]+$") or string.find(name, "..", 1, true) then
		error("Golden: name must match [A-Za-z0-9_.-]+ without '..': " .. name, 3)
	end
	return Golden.dir .. "/" .. name .. suffix
end

-- Line endings are normalized, so a checkout with CRLF conversion still matches.
local function readText(path: string): string
	return (string.gsub(fs.readFile(path), "\r\n", "\n"))
end

local function readValue(path: string): any
	if not fs.isFile(path) then
		return nil
	end
	return luau.load("return " .. readText(path), { debugName = path })()
end

-- Compares text with the file at path, or writes it with bless; errors at the spec's line (level 3 from here).
local function compare(path: string, text: string)
	if Golden.bless then
		fs.writeFile(path, text)
		return
	end
	if not fs.isFile(path) then
		error("assert: golden file missing: " .. path .. " (run with -- --bless, then review the diff)", 3)
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
			string.sub(expected, from, at + 80), string.sub(text, from, at + 80)), 3)
	end
end

-- The blessed value, or nil when the file is missing.
function Golden.read(name: string): any
	return readValue(pathOf(name, ".golden.txt"))
end

-- The blessed digest, or nil when the file is missing.
function Golden.readDigest(name: string): any
	return readValue(pathOf(name, ".digest.txt"))
end

-- Compares value with the blessed text; with bless = true it writes the file instead.
function Golden.check(name: string, value: any)
	compare(pathOf(name, ".golden.txt"), Dump.canonical(value) .. "\n")
end

-- As check, for a digest Studio reads (<name>.digest.txt); its text, newline included, must fit DIGEST_MAX_BYTES.
function Golden.digest(name: string, value: any)
	local path = pathOf(name, ".digest.txt")
	local text = Dump.canonical(value) .. "\n"
	if #text > Golden.DIGEST_MAX_BYTES then
		error(string.format("assert: digest %s is %d bytes, more than %d (§14.2)", path, #text, Golden.DIGEST_MAX_BYTES),
			2)
	end
	compare(path, text)
end

return Golden
