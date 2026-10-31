--!strict
-- tests/run.luau — Lune 0.8.9 test runner. Run from the repo root:
--   lune run tests/run [--quick] [--filter <text>] [--seed <u32>] [--bless] [--list] [--root <dir>] [--verbose]
-- Exit codes: 0 = all passed · 1 = at least one case failed · 2 = harness error
--             (bad args, no specs, spec failed to load / returned no Suite).
-- PROTOTYPE (S8).

local fs = require("@lune/fs")
local process = require("@lune/process")
local Prop = require("./lib/Prop")
local Golden = require("./lib/Golden")

type Case = { name: string, fn: () -> (), slow: boolean, skip: boolean, budgetMs: number }
type Suite = { name: string, cases: { Case } }

local function harnessError(msg: string): never
	print("HARNESS ERROR: " .. msg)
	process.exit(2)
	error("unreachable")
end

-- ── args ────────────────────────────────────────────────────────────────
local opts = { quick = false, filter = nil :: string?, seed = nil :: number?, bless = false, list = false, root = "tests", verbose = false }
do
	local args = process.args
	local i = 1
	while i <= #args do
		local a = args[i]
		if a == "--quick" then opts.quick = true
		elseif a == "--bless" then opts.bless = true
		elseif a == "--list" then opts.list = true
		elseif a == "--verbose" then opts.verbose = true
		elseif a == "--filter" then i += 1; opts.filter = args[i] or harnessError("--filter needs a value")
		elseif a == "--root" then i += 1; opts.root = args[i] or harnessError("--root needs a value")
		elseif a == "--seed" then
			i += 1
			local s = tonumber(args[i] or "")
			if s == nil or s % 1 ~= 0 or s < 0 or s > 0xFFFFFFFF then harnessError("--seed needs an integer in [0, 2^32)") end
			opts.seed = s
		else harnessError("unknown argument " .. a) end
		i += 1
	end
end
if not fs.isFile("tests/run.luau") then harnessError("run from the repo root (tests/run.luau not found in " .. process.cwd .. ")") end
if not fs.isDir(opts.root) then harnessError("test root not found: " .. opts.root) end
Prop.only = opts.seed
Golden.bless = opts.bless

-- ── discovery: <root>/**/*.spec.luau, sorted for a deterministic order ──
local specs: { string } = {}
local function walk(dir: string)
	local entries = fs.readDir(dir)
	table.sort(entries)
	for _, name in entries do
		local path = dir .. "/" .. name
		if fs.isDir(path) then walk(path)
		elseif string.sub(name, -10) == ".spec.luau" then table.insert(specs, path) end
	end
end
walk(opts.root)
table.sort(specs)
if #specs == 0 then harnessError("no *.spec.luau files under " .. opts.root) end

-- ── load ────────────────────────────────────────────────────────────────
local suites: { { file: string, suite: Suite } } = {}
local suiteNames: { [string]: string } = {}
for _, path in specs do
	local modPath = "../" .. string.sub(path, 1, -6) -- strip ".luau"; relative to tests/run.luau
	local ok, result = pcall(function() return (require :: any)(modPath) end)
	if not ok then harnessError("failed to load " .. path .. ":\n" .. tostring(result)) end
	if type(result) ~= "table" or type(result.name) ~= "string" or type(result.cases) ~= "table" then
		harnessError(path .. " must return Test.suite(...)")
	end
	if suiteNames[result.name] then harnessError("duplicate suite name '" .. result.name .. "' in " .. path .. " and " .. suiteNames[result.name]) end
	suiteNames[result.name] = path
	table.insert(suites, { file = path, suite = result :: Suite })
end

-- ── run ─────────────────────────────────────────────────────────────────
local pass, failed, skipped = 0, 0, 0
local failures: { string } = {}
local t0 = os.clock()
for _, entry in suites do
	local suite = entry.suite
	for _, case in suite.cases do
		local full = suite.name .. " › " .. case.name
		local selected = opts.filter == nil or string.find(full, opts.filter :: string, 1, true) ~= nil
		if not selected then continue end
		if opts.list then print(full .. (if case.slow then "  [slow]" else "")); continue end
		if case.skip or (opts.quick and case.slow) then skipped += 1; continue end
		local c0 = os.clock()
		local ok, err = xpcall(case.fn, function(e) return debug.traceback(tostring(e), 2) end)
		local ms = (os.clock() - c0) * 1000
		if ok and ms > case.budgetMs then
			ok, err = false, string.format("assert: over budget: %.0f ms > %d ms", ms, case.budgetMs)
		end
		if ok then
			pass += 1
			if opts.verbose then print(string.format("  ok    %s (%.1f ms)", full, ms)) end
		else
			failed += 1
			local msg = tostring(err)
			local kind = if string.find(msg, "assert: ", 1, true) then "FAIL " else "ERROR"
			local line = string.format("  %s %s (%.1f ms)\n        %s\n        at %s", kind, full, ms,
				(string.gsub(string.match(msg, "[^\n]*") or msg, "^.-assert: ", "")), entry.file)
			print(line)
			table.insert(failures, full)
		end
	end
end
if opts.list then process.exit(0) end

local total = (os.clock() - t0)
print(string.format("RESULT pass=%d fail=%d skip=%d files=%d time=%.2fs%s",
	pass, failed, skipped, #specs, total, if opts.bless then " (golden files blessed)" else ""))
if pass + failed == 0 then harnessError("filter matched no cases") end
process.exit(if failed > 0 then 1 else 0)
