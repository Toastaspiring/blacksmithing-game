--!strict
-- scripts/verify.luau — the local quality gate. Run from the repo root:
--   lune run scripts/verify            (all stages)
--   lune run scripts/verify -- --quick (skip slow statistical cases)
-- Stages: 1 sourcemap (rojo) · 2 static analysis (luau-lsp) · 3 unit tests (lune).
-- Exit: 0 green · 1 tests failed · 2 harness error · 3 type errors · 4 tool missing.
-- PROTOTYPE (S8).
local process = require("@lune/process")

local quick = table.find(process.args, "--quick") ~= nil

local function run(label: string, program: string, args: { string }): (boolean, number, string)
	local ok, result = pcall(process.spawn, program, args, { shell = true })
	if not ok then
		return false, -1, tostring(result)
	end
	local out = result.stdout .. result.stderr
	print(string.format("[%s] exit=%d", label, result.code))
	return result.ok, result.code, out
end

local function lastLines(text: string, n: number): string
	local lines = string.split(text, "\n")
	local from = math.max(1, #lines - n)
	return table.concat(lines, "\n", from)
end

-- 1. sourcemap
local ok1, code1, out1 = run("sourcemap", "rojo", { "sourcemap", "default.project.json", "--output", "sourcemap.json" })
if code1 == -1 or (not ok1 and string.find(out1, "not recognized", 1, true)) then
	print("rojo not found (aftman install)"); process.exit(4)
end
if not ok1 then print(out1); process.exit(2) end

-- 2. static analysis (luau-lsp pinned in aftman.toml; flags per SPEC §14.4)
local ok2, code2, out2 = run("analyze", "luau-lsp", {
	"analyze", "--platform=roblox", "--sourcemap=sourcemap.json",
	"--definitions=tools/luau-lsp/globalTypes.None.d.luau", "--ignore=vendor/**", "--formatter=plain", "src",
})
if code2 == -1 or string.find(out2, "not recognized", 1, true) or string.find(out2, "command not found", 1, true) then
	print("luau-lsp not found: aftman add JohnnyMorganz/luau-lsp@<pinned> (see SPEC §14.4)")
	process.exit(4)
end
if not ok2 then print(lastLines(out2, 40)); process.exit(3) end

-- 3. unit tests
local args = { "run", "tests/run" }
if quick then table.insert(args, "--"); table.insert(args, "--quick") end
local ok3, code3, out3 = run("tests", "lune", args)
print(lastLines(out3, 30))
if not ok3 then process.exit(if code3 == 1 then 1 else 2) end
print("VERIFY GREEN")
process.exit(0)
