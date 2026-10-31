--!strict
-- tests/lib/Golden.luau — golden-file regression. Values are stored in canonical form
-- under tests/golden/<name>.golden.txt. `--bless` rewrites them (review the git diff!).
-- Lune-only (uses @lune/fs). PROTOTYPE (S8).

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Dump = require("./Dump")

local Golden = { bless = false }

-- Reads a blessed value back (canonical form is a valid Luau expression). nil if missing.
function Golden.read(name: string): any
	local path = "tests/golden/" .. name .. ".golden.txt"
	if not fs.isFile(path) then return nil end
	return luau.load("return " .. fs.readFile(path))()
end

function Golden.check(name: string, value: any)
	assert(string.match(name, "^[%w_%-%.]+$"), "golden name must be [A-Za-z0-9_.-]+")
	local path = "tests/golden/" .. name .. ".golden.txt"
	local text = Dump.canonical(value) .. "\n"
	if Golden.bless then
		fs.writeFile(path, text)
		return
	end
	if not fs.isFile(path) then
		error("assert: golden file missing: " .. path .. " (run with --bless, then review the diff)")
	end
	local expected = fs.readFile(path)
	if expected ~= text then
		error("assert: golden mismatch for " .. name .. " (if intended: bump BALANCE_VERSION when balance data changed, then --bless)\n  expected " ..
			string.sub(expected, 1, 160) .. "\n  actual   " .. string.sub(text, 1, 160))
	end
end

return Golden
