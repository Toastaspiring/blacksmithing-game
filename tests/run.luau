--!strict
-- tests/run.luau — the Lune test runner (SPEC §14.3). Run from the repo root; Lune 0.8.9 passes script arguments
-- only after "--":
--   lune run tests/run [-- --quick | --volume | --filter <text> | --seed <n> | --bless | --list | --root <dir>]
--     --quick          skip t.slow cases (the L1 gate)
--     --volume         also run the t.volume cases (L3V), which a plain run skips and lists; never with --quick
--     --filter <text>  run the cases whose "Suite › case" name contains <text> (plain text)
--     --seed <n>       replay one Prop case seed (printed by a failing property), 0 <= n < 2^32; a seed that
--                      replays no case is a harness error
--     --bless          rewrite golden files instead of comparing (review the diff, SPEC §14.9)
--     --list           print the selected case names and run nothing
--     --root <dir>     discover specs under <dir> (repo-relative) instead of tests/ (runner self-test, T-META-05)
-- Discovery: <root>/**/*.spec.luau except <root>/lib and <root>/studio, in byte-wise path order; each spec returns
-- one uniquely named Test.suite; each case runs in xpcall and fails past its budget (Tol.CASE_BUDGET_MS, or
-- Tol.SLOW_CASE_BUDGET_MS for t.slow). A t.volume case is a slow case: --quick skips it with the others; a plain run
-- skips it too and prints a SKIP line for it, so the cases L3V adds are named in L3's output.
-- Exit: 0 all passed · 1 a FAIL (assertion) or an ERROR (crash) · 2 harness: not at the repo root, bad argument
-- (--quick with --volume included), no specs, a spec that fails to load or returns no suite, a duplicate suite, a
-- filter that matches no case, a --seed that replays no property case, a root that holds the runner self-test
-- (Test.SELFTEST_SPEC, so tests/ itself) asked of a runner that self-test spawned (Test.SELFTEST_CHILD set: the
-- self-test gives each runner a root under tools/runner-selftest/, so such a root means a broken check, and the
-- runner stops before loading a spec instead of starting the self-test's own suite again).

local fs = require("@lune/fs")
local process = require("@lune/process")
local Dump = require("./lib/Dump")
local Golden = require("./lib/Golden")
local Prop = require("./lib/Prop")
local Test = require("./lib/Test")

type Suite = Test.Suite

local function harness(message: string): never
	print("HARNESS ERROR: " .. message)
	process.exit(2)
	error(message) -- not reached: process.exit ends the process
end

-- ── arguments ─────────────────────────────────────────────────────────────────────────────────────────────────

type Options = {
	quick: boolean,
	volume: boolean,
	filter: string?,
	seed: number?,
	bless: boolean,
	list: boolean,
	root: string,
}
local opts: Options =
	{ quick = false, volume = false, filter = nil, seed = nil, bless = false, list = false, root = "tests" }

local function normalizeRoot(dir: string): string
	local d = string.gsub(dir, "\\", "/")
	d = string.gsub(d, "^%./", "")
	d = string.gsub(d, "/+$", "")
	if d == "" or string.sub(d, 1, 1) == "/" or string.match(d, "^%a:") then
		harness("--root needs a repo-relative directory, got " .. dir)
	end
	for _, part in string.split(d, "/") do
		if part == ".." or part == "." or part == "" then
			harness("--root must stay inside the repo and name a directory plainly, got " .. dir)
		end
	end
	return d
end

do
	local args = process.args
	local seen: { [string]: boolean } = {}
	local i = 1
	while i <= #args do
		local a = args[i]
		if seen[a] then
			harness("argument given twice: " .. a)
		end
		if a == "--quick" then
			opts.quick = true
		elseif a == "--volume" then
			opts.volume = true
		elseif a == "--bless" then
			opts.bless = true
		elseif a == "--list" then
			opts.list = true
		elseif a == "--filter" or a == "--seed" or a == "--root" then
			local v = args[i + 1]
			if v == nil then
				harness(a .. " needs a value")
			end
			i += 1
			if a == "--filter" then
				if v == "" then
					harness("--filter needs a non-empty text")
				end
				opts.filter = v
			elseif a == "--seed" then
				local s = tonumber(v)
				if s == nil or s ~= s or s % 1 ~= 0 or s < 0 or s > 0xFFFFFFFF then
					harness("--seed needs an integer in [0, 2^32), got " .. v)
				end
				opts.seed = s
			else
				opts.root = normalizeRoot(v)
			end
		else
			harness("unknown argument " .. a .. "\nusage: lune run tests/run [-- --quick | --volume | --filter <text> | "
				.. "--seed <n> | --bless | --list | --root <dir>]")
		end
		seen[a] = true
		i += 1
	end
	if opts.quick and opts.volume then
		harness("--quick and --volume exclude each other: --quick skips every t.slow case, and t.volume cases are slow")
	end
end

if not (fs.isFile("tests/run.luau") and fs.isFile("default.project.json")) then
	harness("run from the repo root (tests/run.luau not found from " .. process.cwd .. ")")
end
if not fs.isDir(opts.root) then
	harness("test root not found: " .. opts.root)
end
Prop.only = opts.seed
Golden.bless = opts.bless

-- ── discovery ─────────────────────────────────────────────────────────────────────────────────────────────────

local specs: { string } = {}
local function walk(dir: string, top: boolean)
	local names = fs.readDir(dir)
	table.sort(names, Dump.byteLess)
	for _, name in names do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			if not (top and (name == "lib" or name == "studio")) then
				walk(path, false)
			end
		elseif string.sub(name, -10) == ".spec.luau" then
			table.insert(specs, path)
		end
	end
end
walk(opts.root, true)
table.sort(specs, Dump.byteLess)
if #specs == 0 then
	harness("no *.spec.luau files under " .. opts.root)
end
if process.env[Test.SELFTEST_CHILD] then
	local held = "/" .. Test.SELFTEST_SPEC
	for _, path in specs do
		if string.sub(path, -#held) == held then
			harness(Test.SELFTEST_CHILD .. " is set, so the runner self-test spawned this runner, and " .. opts.root
				.. " holds that self-test (" .. path .. "): a self-test runner never starts its own suite again")
		end
	end
end

-- ── load ──────────────────────────────────────────────────────────────────────────────────────────────────────

local suites: { { file: string, suite: Suite } } = {}
local fileOfSuite: { [string]: string } = {}
for _, path in specs do
	local modPath = "../" .. string.sub(path, 1, -6) -- relative to this file; without ".luau"
	local ok, result = pcall(function(): any
		return (require :: any)(modPath)
	end)
	if not ok then
		harness("failed to load " .. path .. ":\n" .. tostring(result))
	end
	if type(result) ~= "table" or type(result.name) ~= "string" or type(result.cases) ~= "table" then
		harness(path .. " must return Test.suite(...), got " .. Dump.short(result))
	end
	local suite = result :: Suite
	if fileOfSuite[suite.name] then
		harness("duplicate suite name '" .. suite.name .. "' in " .. path .. " and " .. fileOfSuite[suite.name])
	end
	fileOfSuite[suite.name] = path
	table.insert(suites, { file = path, suite = suite })
end

-- ── run ───────────────────────────────────────────────────────────────────────────────────────────────────────

-- err = message lines, then Luau traceback lines ('[string "chunk"]:line ...', '[C] ...').
local function report(kind: string, full: string, ms: number, err: string, file: string)
	local message: { string } = {}
	local trace: { string } = {}
	for n, l in string.split(err, "\n") do
		local isTrace = n > 1 and (#trace > 0 or string.match(l, '^%[string "') ~= nil or string.match(l, "^%[C%]") ~= nil
			or l == "stack traceback:")
		if isTrace then
			if l ~= "" and l ~= "stack traceback:" then
				table.insert(trace, l)
			end
		else
			table.insert(message, l)
		end
	end
	if kind ~= "ERROR" and message[1] then
		message[1] = string.gsub(message[1], "^.-assert: ", "")
	end
	-- the deepest frame inside the spec file (Lune names chunks by path, with the OS separator)
	local where = file
	for _, l in trace do
		local chunk, ln = string.match(l, '^%[string "(.-)"%]:(%d+)')
		if chunk and ln and (string.gsub(chunk, "\\", "/")) == file then
			where = file .. ":" .. ln
			break
		end
	end
	local lines = { string.format("  %s %s (%.1f ms)", kind, full, ms) }
	for _, l in message do
		table.insert(lines, "        " .. l)
	end
	if kind == "ERROR" then
		for k = 1, math.min(#trace, 6) do
			table.insert(lines, "        | " .. trace[k])
		end
	end
	table.insert(lines, "        at " .. where)
	print(table.concat(lines, "\n"))
end

local passed, failed, skipped, matched = 0, 0, 0, 0
local t0 = os.clock()
for _, entry in suites do
	local suite = entry.suite
	for _, case in suite.cases do
		local full = suite.name .. " › " .. case.name
		if opts.filter and not string.find(full, opts.filter :: string, 1, true) then
			continue
		end
		matched += 1
		if opts.list then
			local tag = if case.volume then "  [volume]" elseif case.slow then "  [slow]" elseif case.skip then "  [skip]" else ""
			print(full .. tag)
			continue
		end
		if case.skip or (opts.quick and case.slow) then
			skipped += 1
			continue
		end
		if case.volume and not opts.volume then
			skipped += 1
			print("  SKIP  " .. full .. " (t.volume: run with -- --volume)")
			continue
		end
		local c0 = os.clock()
		local ok, err = xpcall(case.fn :: any, function(e: any): string
			return debug.traceback(tostring(e), 2)
		end)
		local ms = (os.clock() - c0) * 1000
		if ok and ms > case.budgetMs then
			ok, err = false, string.format("assert: over budget: %.0f ms > %d ms", ms, case.budgetMs)
		end
		if ok then
			passed += 1
		else
			failed += 1
			local text = tostring(err)
			report(if string.find(text, "assert: ", 1, true) then "FAIL " else "ERROR", full, ms, text, entry.file)
		end
	end
end

if opts.filter and matched == 0 then
	harness("--filter " .. string.format("%q", opts.filter :: string) .. " matched no case")
end
if opts.seed ~= nil and not opts.list and Prop.replayed == 0 then
	harness("--seed " .. tostring(opts.seed) .. " matched no property case (a mistyped seed, or a --filter, a "
		.. "--quick or a missing --volume that leaves its case out)")
end
if opts.list then
	print(string.format("LIST cases=%d files=%d", matched, #specs))
	process.exit(0)
end
print(string.format("RESULT pass=%d fail=%d skip=%d files=%d time=%.2fs%s", passed, failed, skipped, #specs,
	os.clock() - t0, if opts.bless then " (golden files blessed)" else ""))
process.exit(if failed > 0 then 1 else 0)
