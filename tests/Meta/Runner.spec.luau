--!strict
-- T-META-05 (SPEC §14.3, §14.4): runner self-test. The roots under tools/runner-selftest/ make the runner exit
-- 0 (pass), 1 (fail) and 2 (broken: a spec that does not parse, one that returns no suite, a duplicate suite; nospec:
-- specs only under <root>/lib and <root>/studio, which discovery skips); each harness fault of §14.3 also exits 2.
-- --seed and --bless reach the specs' Prop and Golden instances: a probe case checks both flags in every run, and
-- child runners on the bless root bless, then compare, a golden of their own. The volume root holds a t.volume case
-- (§14.1 L3V): a plain run skips and lists it, --volume runs it, --quick --volume is a harness error, and
-- scripts/verify passes --quick or --volume through. The test library's own contracts follow (Dump, TestRng, Prop,
-- Golden, Assert, Test), since every later suite relies on them.
-- The self-test never starts the suite that holds it (M4: with the --quick --volume check broken, a child given no
-- root once ran the whole suite, this spec included, over and over). Every runner spawned here takes a --root under
-- tools/runner-selftest/, the cases that expect a harness error included, so a check that stopped refusing runs a
-- small root and exits 0; and every process spawned here carries Test.SELFTEST_CHILD, under which this spec spawns
-- nothing, tests/run refuses a root that holds this spec (the holder root stands in for tests/) and scripts/verify,
-- which takes no root, runs no stage (spawned from tools/, where a verify that lost its guard stops at its repo-root
-- check). The last three cases of the first part check each of the three.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Golden = require("../lib/Golden")
local Prop = require("../lib/Prop")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local Lex = require("./Lex")

local CHILD = Test.SELFTEST_CHILD

-- Runs Lune in a child process (the aftman shim resolves Lune from aftman.toml) with CHILD and env set; refused in
-- a process that carries CHILD itself. The variables are set in this process around the spawn, and the child
-- inherits them: Lune 0.8.9's spawn option `env` costs about 85 ms more per child (33 → 119 ms measured for M4).
local function spawnLune(args: { string }, cwd: string?, env: { [string]: string }?): (number, string)
	if process.env[CHILD] ~= nil then
		A.fail("this spec runs inside a process it spawned (" .. CHILD .. " is set), so it spawns nothing: the "
			.. "self-test cannot recurse")
	end
	local vars: { [string]: string } = { [CHILD] = "1" }
	if env then
		for k, v in env do
			vars[k] = v
		end
	end
	local saved: { [string]: string? } = {}
	for k, v in vars do
		saved[k] = process.env[k]
		process.env[k] = v
	end
	local ok, result = pcall(process.spawn, "lune", args, { cwd = cwd })
	for k in vars do
		process.env[k] = saved[k]
	end
	if not ok then
		error(result, 0)
	end
	return result.code, result.stdout .. result.stderr
end

-- Runs the runner (or another script) in a child Lune process.
local function runner(args: { string }, cwd: string?, script: string?): (number, string)
	local full = { "run", script or "tests/run" }
	if #args > 0 then
		table.insert(full, "--")
		for _, a in args do
			table.insert(full, a)
		end
	end
	return spawnLune(full, cwd)
end

local function expectRun(args: { string }, code: number, needles: { string }, cwd: string?, script: string?)
	local got, out = runner(args, cwd, script)
	local what = "lune run " .. (script or "tests/run") .. " -- " .. table.concat(args, " ")
	if got ~= code then
		A.fail(string.format("%s exited %d, expected %d; output:\n%s", what, got, code, out))
	end
	for _, needle in needles do
		if not string.find(out, needle, 1, true) then
			A.fail(string.format("%s: output lacks %q:\n%s", what, needle, out))
		end
	end
end

local SELFTEST = "tools/runner-selftest/"

-- The runner's flags as this process received them: a spec runs inside the runner's own Lune process, so
-- process.args are the runner's arguments (parsed here like tests/run.luau does).
local function runnerFlags(): { bless: boolean, seed: number? }
	local bless, seed = false, nil
	local args = process.args
	local i = 1
	while i <= #args do
		local a = args[i]
		if a == "--bless" then
			bless = true
		elseif a == "--seed" then
			seed = tonumber(args[i + 1])
			i += 1
		elseif a == "--filter" or a == "--root" then
			i += 1
		end
		i += 1
	end
	return { bless = bless, seed = seed }
end

-- The probe case: on every run it checks that this spec's Golden and Prop carry the runner's --bless and --seed.
local PROBE = "--bless and --seed reach this spec's Golden and Prop instances"
-- read by the bless root's spec (tools/runner-selftest/bless/Bless.spec.luau)
local BLESS_PROBE_DIR = "BLACKSMITH_BLESS_PROBE_DIR"
local BLESS_PROBE_TOKEN = "BLACKSMITH_BLESS_PROBE_TOKEN"

local function tempDir(prefix: string): string
	local temp = process.env.TEMP or process.env.TMPDIR or "/tmp"
	local dir = string.format("%s/%s-%d-%d", temp, prefix, os.time(), math.floor(os.clock() * 1e6) % 1000000)
	fs.writeDir(dir)
	return dir
end

return Test.suite("Meta/Runner", function(t)
	-- ── T-META-05: exit codes of the runner ──────────────────────────────────────────────────────────────────

	t.it("T-META-05 pass root exits 0, and --seed reaches the specs' Prop instance", function()
		expectRun({ "--root", SELFTEST .. "pass" }, 0, { "RESULT pass=4 fail=0 skip=1 files=1" })
		-- 591835543: the first case seed drawn from PROP_BASE_SEED (checked in the TestRng case below)
		local seed = "591835543"
		expectRun({ "--root", SELFTEST .. "pass", "--seed", seed }, 0, { "RESULT pass=4 fail=0 skip=1 files=1" })
		expectRun({ "--root", SELFTEST .. "pass", "--seed", seed, "--quick" }, 0, { "RESULT pass=3 fail=0 skip=2" })
	end)

	t.it("T-META-05 fail root exits 1 and reports a FAIL and an ERROR", function()
		expectRun({ "--root", SELFTEST .. "fail" }, 1, {
			"FAIL  SelfTest/Fail › fails an assertion",
			"float compare: expected 0.29999999999999999",
			"at tools/runner-selftest/fail/Fail.spec.luau:12",
			"ERROR SelfTest/Fail › crashes",
			"attempt to index nil with 'field'",
			"RESULT pass=1 fail=2 skip=0",
		})
	end)

	t.it("T-META-05 broken roots exit 2", function()
		expectRun({ "--root", SELFTEST .. "broken" }, 2, { "HARNESS ERROR" })
		expectRun({ "--root", SELFTEST .. "broken/syntax" }, 2, { "HARNESS ERROR: failed to load", "Syntax.spec.luau" })
		expectRun({ "--root", SELFTEST .. "broken/nosuite" }, 2, { "must return Test.suite" })
		expectRun({ "--root", SELFTEST .. "broken/duplicate" }, 2, { "duplicate suite name 'SelfTest/Duplicate'" })
	end)

	t.it("T-META-05 harness faults exit 2: arguments", function()
		-- each on the pass root: a check that stopped refusing runs that small root and exits 0
		local function refused(args: { string }, needle: string)
			local full = { "--root", SELFTEST .. "pass" }
			for _, a in args do
				table.insert(full, a)
			end
			expectRun(full, 2, { needle })
		end
		refused({ "--frobnicate" }, "unknown argument --frobnicate")
		refused({ "--seed", "1.5" }, "--seed needs an integer")
		refused({ "--seed", "4294967296" }, "--seed needs an integer")
		refused({ "--filter" }, "--filter needs a value")
		refused({ "--quick", "--quick" }, "argument given twice")
		refused({ "--volume", "--quick" }, "--quick and --volume exclude each other")
	end)

	t.it("T-META-05 harness faults exit 2: roots, filters, seeds, working directory", function()
		expectRun({ "--root", SELFTEST .. "pass", "--filter", "no case is called this" }, 2, { "matched no case" })
		-- a mistyped replay seed: the property runs its 3 cases, none has seed 1, so nothing was replayed
		expectRun({ "--root", SELFTEST .. "pass", "--filter", "a property that holds", "--seed", "1" }, 2,
			{ "--seed 1 matched no property case" })
		-- its specs sit under <root>/lib and <root>/studio, which discovery skips (a read one fails its case)
		expectRun({ "--root", SELFTEST .. "nospec" }, 2, { "no *.spec.luau files under tools/runner-selftest/nospec" })
		expectRun({ "--root", SELFTEST .. "missing" }, 2, { "test root not found" })
		-- a root names its directory plainly, so none leaves the repo; a broken check would run the pass root
		expectRun({ "--root", SELFTEST .. "pass/../pass" }, 2, { "must stay inside the repo" })
		-- from tools/, the self-test root runner-selftest/pass is the one a broken check would run
		expectRun({ "--root", "runner-selftest/pass" }, 2, { "run from the repo root" }, "tools", "../tests/run")
	end)

	t.it(PROBE, function()
		local flags = runnerFlags()
		A.eq(Golden.bless, flags.bless, "this spec's Golden.bless carries the runner's --bless")
		A.eq(Prop.only, flags.seed, "this spec's Prop.only carries the runner's --seed")
	end)

	t.it("T-META-05 --bless reaches the specs' Golden instance: a child runner blesses, then compares, a golden", function()
		local dir = tempDir("blacksmith-bless")
		local ok, err = pcall(function()
			local file = dir .. "/bless_probe.golden.txt"
			local function child(bless: boolean, token: string): (number, string)
				local args = { "run", "tests/run", "--", "--root", SELFTEST .. "bless" }
				if bless then
					table.insert(args, "--bless")
				end
				return spawnLune(args, nil, { [BLESS_PROBE_DIR] = dir, [BLESS_PROBE_TOKEN] = token })
			end
			-- a plain run with no golden yet fails and writes nothing
			local code, out = child(false, "first")
			A.eq(code, 1, "a plain run without the golden exits 1:\n" .. out)
			A.contains(out, "golden file missing")
			A.falsy(fs.isFile(file), "a plain run writes no golden")
			-- --bless: the probe's Golden.check, in the spec's module instance, writes it
			code, out = child(true, "first")
			A.eq(code, 0, "the --bless run exits 0:\n" .. out)
			A.contains(out, "RESULT pass=1 fail=0 skip=0")
			A.contains(out, "(golden files blessed)")
			A.eq(fs.readFile(file), Dump.canonical({ token = "first" }) .. "\n", "--bless wrote the probe's golden")
			-- plain runs compare against it: the same value passes, a changed one fails
			code, out = child(false, "first")
			A.eq(code, 0, "a plain run against the blessed golden exits 0:\n" .. out)
			code, out = child(false, "second")
			A.eq(code, 1, "a changed value without --bless exits 1:\n" .. out)
			A.contains(out, "golden mismatch")
			A.eq(fs.readFile(file), Dump.canonical({ token = "first" }) .. "\n", "and leaves the golden alone")
		end)
		fs.removeDir(dir)
		if not ok then
			error(err, 0)
		end
	end)

	t.it("T-META-05 --list prints the selected cases and runs none", function()
		expectRun({ "--root", SELFTEST .. "pass", "--list", "--filter", "passes" }, 0,
			{ "SelfTest/Pass › passes", "LIST cases=1 files=1" })
		expectRun({ "--root", SELFTEST .. "volume", "--list" }, 0, {
			"SelfTest/Volume › a slow case  [slow]",
			"SelfTest/Volume › a volume case, run only by --volume  [volume]",
			"LIST cases=3 files=1",
		})
	end)

	-- ── L3V: t.volume and --volume (§14.1) ──────────────────────────────────────────────────────────────────

	t.it("T-META-05 a plain run skips the t.volume case and lists it; --volume runs every case", function()
		local SKIPPED = "  SKIP  SelfTest/Volume › a volume case, run only by --volume (t.volume: run with -- --volume)"
		expectRun({ "--root", SELFTEST .. "volume" }, 0, { SKIPPED, "RESULT pass=2 fail=0 skip=1 files=1" })
		-- the volume case asserts the runner's --volume, so a run of it without the flag would exit 1; --volume and
		-- --quick list no skipped volume case
		for _, run in
			{
				{ flag = "--volume", result = "RESULT pass=3 fail=0 skip=0 files=1" },
				{ flag = "--quick", result = "RESULT pass=1 fail=0 skip=2 files=1" },
			}
		do
			local code, out = runner({ "--root", SELFTEST .. "volume", run.flag })
			A.eq(code, 0, run.flag .. " exits 0:\n" .. out)
			A.contains(out, run.result, run.flag)
			A.falsy(string.find(out, "SKIP", 1, true), run.flag .. " lists no skipped volume case:\n" .. out)
		end
	end)

	-- ── the guard (Test.SELFTEST_CHILD): the self-test never starts its own suite ────────────────────────────

	t.it("T-META-05 the guard: a process that carries it spawns nothing", function()
		local saved = process.env[CHILD]
		process.env[CHILD] = "1"
		local ok, err = pcall(function()
			runner({ "--root", SELFTEST .. "pass" })
		end)
		process.env[CHILD] = saved
		A.falsy(ok, "nothing spawned under the guard")
		A.contains(tostring(err), "so it spawns nothing")
		-- and every process this spec spawns carries it: the bless root's spec asserts that in the --bless case's runs
	end)

	t.it("T-META-05 the guard: a runner the self-test spawned refuses a root that holds the self-test", function()
		-- tests/ holds this spec at Test.SELFTEST_SPEC, so such a runner refuses tests/ as it refuses the holder root,
		-- which stands in for it here: with the refusal broken, the child runs the holder's one case and exits 0
		A.truthy(fs.isFile("tests/" .. Test.SELFTEST_SPEC), "tests/ holds the runner self-test at Test.SELFTEST_SPEC")
		expectRun({ "--root", SELFTEST .. "holder" }, 2,
			{ CHILD .. " is set", "holds that self-test (tools/runner-selftest/holder/Meta/Runner.spec.luau)" })
	end)

	t.it("T-META-05 the guard: scripts/verify checks its arguments, then runs no stage and names its tests command", function()
		-- verify takes no --root, so it runs here from tools/: its guard, the first check after its arguments, stops
		-- it and prints the command its tests stage would run (so the --quick or --volume pass-through shows), and
		-- with the guard broken or its variable missing it stops at its repo-root check instead, before any stage
		expectRun({ "--quick", "--volume" }, 2, { "HARNESS ERROR: --quick and --volume exclude each other" }, "tools",
			"../scripts/verify")
		for _, run in
			{
				{ args = { "--quick" }, command = "lune run tests/run -- --quick" },
				{ args = { "--volume" }, command = "lune run tests/run -- --volume" },
			}
		do
			expectRun(run.args, 2, { "HARNESS ERROR: " .. CHILD .. " is set", 'the tests stage would run "' .. run.command
				.. '"' }, "tools", "../scripts/verify")
		end
		-- the tests stage spawns that same command
		local texts: { string } = {}
		for _, tok in Lex.lex(fs.readFile("scripts/verify.luau")).tokens do
			table.insert(texts, if tok.kind == "string" then '"' .. tok.text .. '"' else tok.text)
		end
		A.contains(" " .. table.concat(texts, " ") .. " ", ' local run = spawn ( "lune" , testArgs ) ',
			"verify's tests stage runs the command it names")
	end)

	-- ── the test library ─────────────────────────────────────────────────────────────────────────────────────

	t.it("Dump.canonical: sorted keys, %.17g, −0 → 0, one loadable line", function()
		local value = {
			b = 1, a = { 2, 3 }, [1] = "x", ["not id"] = -0, z = 0 / 0, w = math.huge, v = -math.huge,
			s = 'a\n"b"\0\t', f = 0.1, ["end"] = true,
		}
		local text = Dump.canonical(value)
		A.eq(text, '{[1]="x",a={[1]=2,[2]=3},b=1,["end"]=true,f=0.10000000000000001,["not id"]=0,'
			.. 's="a\\n\\"b\\"\\000\\t",v=-math.huge,w=math.huge,z=0/0}')
		A.falsy(string.find(text, "\n", 1, true), "single line")
		local back = luau.load("return " .. text)()
		A.deepEq(back, value, "round trip")
		A.eq(Dump.canonical({ [2] = 1, [10] = 2, [1] = 0 }), "{[1]=0,[2]=1,[10]=2}", "numeric keys ascend")
		A.eq(Dump.canonical({ B = 1, a = 2, ["é"] = 3 }), '{B=1,a=2,["é"]=3}', "byte-wise string order")
		A.throws(function()
			local cyc: any = {}
			cyc.self = cyc
			Dump.canonical(cyc)
		end, "cycle")
		A.throws(function()
			Dump.canonical({ f = print })
		end, "unsupported type function")
	end)

	t.it("Dump.fnv1a32 matches the FNV-1a reference vectors", function()
		A.eq(Dump.fnv1a32(""), 0x811C9DC5)
		A.eq(Dump.fnv1a32("a"), 0xE40C292C)
		A.eq(Dump.fnv1a32("foobar"), 0xBF9CF968)
		A.eq(Dump.fnv1a32("smithy é"), 0xDF058CCD)
	end)

	t.it("Dump.firstDifference names the first differing path", function()
		A.eq(Dump.firstDifference({ a = { 1, 2 } }, { a = { 1, 2 } }), nil)
		A.eq(Dump.firstDifference({ a = { 1, 2 } }, { a = { 1, 3 } }), "$.a[2]: 2 ~= 3")
		A.eq(Dump.firstDifference({ a = 1 }, { a = 1, b = 2 }), "$.b: missing on the actual side")
		A.eq(Dump.firstDifference(0, -0), nil, "−0 == 0")
		A.eq(Dump.firstDifference(0 / 0, 0 / 0), nil, "NaN == NaN")
		A.eq(Dump.firstDifference({ x = "1" }, { x = 1 }), "$.x: type string ~= number")
	end)

	t.it("TestRng is xorshift32 (13/17/5), seeded reproducibly", function()
		local rng = TestRng.new(1)
		A.eq(rng:u32(), 270369)
		A.eq(rng:u32(), 67634689)
		A.eq(rng:u32(), 2647435461)
		local base = TestRng.new(Tol.PROP_BASE_SEED)
		A.eq(base:u32(), 591835543, "PROP_BASE_SEED stream")
		A.eq(TestRng.new(0):u32(), 1085196063, "seed 0 is remapped")
		local r1, r2 = TestRng.new(7), TestRng.new(7)
		for _ = 1, 100 do
			local x = r1:float()
			A.eq(x, r2:float())
			A.within(x, 0, 0.99999999999)
			A.within(r1:int(3, 5), 3, 5)
			r2:int(3, 5)
		end
		local n = TestRng.new(9)
		local sum, count = 0, 2000
		for _ = 1, count do
			local v = n:normal(10, 2)
			A.within(v, -2, 22)
			sum += v
		end
		A.near(sum / count, 10, 0.2, "normal mean")
	end)

	t.it("Prop.check reports the case seed and --seed replays only that case", function()
		local savedOnly, savedReplayed = Prop.only, Prop.replayed
		Prop.only = nil
		local ok, err = pcall(function()
			local seen: { number } = {}
			Prop.check(5, function(rng)
				return rng:u32()
			end, function(v: number)
				table.insert(seen, v)
			end)
			A.eq(#seen, 5, "n cases")
			A.eq(Prop.replayed, savedReplayed, "a run without --seed replays nothing")
			local message = A.throws(function()
				Prop.check(50, function(rng)
					return rng:int(1, 10)
				end, function(v: number)
					A.truthy(v < 10, "below ten")
				end)
			end, "assert: property failed on case")
			local seed = tonumber(string.match(message, "%(seed (%d+)%)")) :: number
			A.truthy(seed ~= nil, "message names the seed: " .. message)
			A.contains(message, "input = 10")
			local function tenOrLess(rng: TestRng.TestRng): number
				return rng:int(1, 10)
			end
			Prop.only = seed
			local runs = 0
			local replayOk = pcall(Prop.check, 50, tenOrLess, function(v: number)
				runs += 1
				A.eq(v, 10)
			end)
			A.truthy(replayOk, "the replayed case reproduces the input")
			A.eq(runs, 1, "only the named seed runs")
			A.eq(Prop.replayed, savedReplayed + 1, "the replayed case is counted")
			Prop.only = 1 -- not among this run's 50 case seeds
			runs = 0
			Prop.check(50, tenOrLess, function(_v: number)
				runs += 1
			end)
			A.eq(runs, 0, "an unmatched seed runs no case")
			A.eq(Prop.replayed, savedReplayed + 1, "and counts none, so the runner can refuse it")
		end)
		Prop.only, Prop.replayed = savedOnly, savedReplayed
		if not ok then
			error(err, 0)
		end
	end)

	t.it("Golden: missing file fails, bless writes, check compares, CRLF is tolerated", function()
		local temp = process.env.TEMP or process.env.TMPDIR or "/tmp"
		local dir = string.format("%s/blacksmith-golden-%d-%d", temp, os.time(), math.floor(os.clock() * 1e6) % 1000000)
		fs.writeDir(dir)
		local savedDir, savedBless = Golden.dir, Golden.bless
		local ok, err = pcall((function()
			Golden.dir = dir
			Golden.bless = false
			A.eq(Golden.read("sample.bv1"), nil, "read of a missing golden")
			A.throws(function()
				Golden.check("sample.bv1", { q = 0.5 })
			end, "assert: golden file missing")
			Golden.bless = true
			Golden.check("sample.bv1", { q = 0.5, tier = "Hard" })
			Golden.bless = false
			Golden.check("sample.bv1", { tier = "Hard", q = 0.5 })
			A.deepEq(Golden.read("sample.bv1"), { q = 0.5, tier = "Hard" }, "read back")
			A.throws(function()
				Golden.check("sample.bv1", { q = 0.5000000000000001, tier = "Hard" })
			end, "assert: golden mismatch")
			fs.writeFile(dir .. "/sample.bv1.golden.txt", (string.gsub(Dump.canonical({ q = 0.5, tier = "Hard" }) .. "\n", "\n", "\r\n")))
			Golden.check("sample.bv1", { q = 0.5, tier = "Hard" })
			A.throws(function()
				Golden.check("../escape", 1)
			end, "Golden: name must match")
		end) :: any)
		Golden.dir, Golden.bless = savedDir, savedBless
		fs.removeDir(dir)
		if not ok then
			error(err, 0)
		end
	end)

	t.it("Golden.digest: its own .digest.txt, compared like a golden, at most DIGEST_MAX_BYTES", function()
		local temp = process.env.TEMP or process.env.TMPDIR or "/tmp"
		local dir = string.format("%s/blacksmith-digest-%d-%d", temp, os.time(), math.floor(os.clock() * 1e6) % 1000000)
		fs.writeDir(dir)
		local savedDir, savedBless = Golden.dir, Golden.bless
		local ok, err = pcall((function()
			Golden.dir = dir
			Golden.bless = false
			A.eq(Golden.readDigest("sample.bv1"), nil, "read of a missing digest")
			A.throws(function()
				Golden.digest("sample.bv1", { h = 1 })
			end, "assert: golden file missing")
			Golden.bless = true
			Golden.digest("sample.bv1", { h = 1, n = 2 })
			Golden.bless = false
			A.truthy(fs.isFile(dir .. "/sample.bv1.digest.txt"), "written as <name>.digest.txt")
			A.falsy(fs.isFile(dir .. "/sample.bv1.golden.txt"), "not as a golden")
			Golden.digest("sample.bv1", { n = 2, h = 1 })
			A.deepEq(Golden.readDigest("sample.bv1"), { h = 1, n = 2 }, "read back")
			A.eq(Golden.read("sample.bv1"), nil, "a digest is no golden")
			A.throws(function()
				Golden.digest("sample.bv1", { h = 2, n = 2 })
			end, "assert: golden mismatch")
			local big = string.rep("x", Golden.DIGEST_MAX_BYTES)
			Golden.bless = true
			A.throws(function()
				Golden.digest("big.bv1", { s = big })
			end, "more than 1024")
			Golden.bless = false
			A.falsy(fs.isFile(dir .. "/big.bv1.digest.txt"), "an oversized digest is never written")
		end) :: any)
		Golden.dir, Golden.bless = savedDir, savedBless
		fs.removeDir(dir)
		if not ok then
			error(err, 0)
		end
	end)

	t.it("Assert: every failure raises 'assert:', passes stay silent", function()
		local failing: { () -> () } = {
			function() A.fail("x") end,
			function() A.truthy(false) end,
			function() A.falsy(1) end,
			function() A.eq(1, 2) end,
			function() A.finite(0 / 0) end,
			function() A.near(1, 2, 0.5) end,
			function() A.rel(1, 2, 0.1) end,
			function() A.within(3, 0, 1) end,
			function() A.deepEq({ 1 }, { 2 }) end,
			function() A.contains("abc", "d") end,
			function() A.throws(function() end) end,
			function() A.errCode({ ok = true }, "E_X") end,
			function() A.errCode({ ok = false, code = "E_Y" }, "E_X") end,
		}
		for k, fn in failing do
			local ok, err = pcall(fn :: any)
			A.falsy(ok, "case " .. k .. " must fail")
			A.contains(tostring(err), "assert: ", "case " .. k)
		end
		A.truthy(1)
		A.falsy(nil)
		A.eq("a", "a")
		A.finite(1e308)
		A.near(1, 1.1, 0.2)
		A.rel(100, 101, 0.02)
		A.within(0.5, 0, 1)
		A.deepEq({ a = { 1 } }, { a = { 1 } })
		A.contains("abc", "b")
		A.errCode({ ok = false, code = "E_X" }, "E_X")
	end)

	t.it("Test.suite: budgets from Tol, duplicate case names refused", function()
		local suite = Test.suite("X", function(s)
			s.it("fast", function() end)
			s.slow("slow", function() end)
			s.skip("skipped", function() end)
		end)
		A.eq(#suite.cases, 3)
		A.eq(suite.cases[1].budgetMs, Tol.CASE_BUDGET_MS)
		A.eq(suite.cases[2].budgetMs, Tol.SLOW_CASE_BUDGET_MS)
		A.truthy(suite.cases[2].slow and suite.cases[3].skip)
		A.throws(function()
			Test.suite("Y", function(s)
				s.it("same", function() end)
				s.it("same", function() end)
			end)
		end, "duplicate case name")
	end)

	t.it("Test.suite: t.volume is a slow case with the slow budget; no other kind sets volume", function()
		local suite = Test.suite("X", function(s)
			s.it("fast", function() end)
			s.slow("slow", function() end)
			s.skip("skipped", function() end)
			s.volume("volume", function() end)
		end)
		A.eq(#suite.cases, 4)
		local volume = suite.cases[4]
		A.truthy(volume.volume and volume.slow and not volume.skip, "t.volume implies t.slow")
		A.eq(volume.budgetMs, Tol.SLOW_CASE_BUDGET_MS)
		for k = 1, 3 do
			A.falsy(suite.cases[k].volume, suite.cases[k].name .. " is no volume case")
		end
		A.throws(function()
			Test.suite("Y", function(s)
				s.slow("same", function() end)
				s.volume("same", function() end)
			end)
		end, "duplicate case name")
	end)
end)
