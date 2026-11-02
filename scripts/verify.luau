--!strict
-- scripts/verify.luau — the local gate (SPEC §14.1–§14.4), run from the repo root before every commit to main:
--   lune run scripts/verify [-- --quick]          (Lune 0.8.9: script arguments follow "--")
-- Stages, each completing before the next:
--   1 sourcemaps   rojo sourcemap of default.project.json and test.project.json (--include-non-scripts)
--   2 T-META-07    every string require in a Rojo root resolves to the same module on disk and in both sourcemaps
--   3 luau-lsp     pass A (roblox platform, test sourcemap, Roblox definitions) over src and tests/studio;
--                  pass B (standard platform, Lune typedefs through tests/.luaurc) over tests
--   4 tests        lune run tests/run [-- --quick]
-- Exit: 0 green · 1 tests failed · 2 harness, sourcemap or T-META-07 · 3 luau-lsp · 4 missing tool. The body runs in
-- xpcall: an uncaught Lune error would exit 1, the tests' code, so any crash of this script exits 2 instead.
--
-- luau-lsp's --formatter=plain is its luacheck format, which always exits 0 (AnalyzeCli.cpp, also in 1.56.0 and
-- 1.67.0), so the diagnostics are parsed here: any TypeError or SyntaxError fails, and so do the lints
-- UnknownGlobal, DeprecatedApi and ImplicitReturn (§14.4); other lints are listed without failing.
-- The Roblox definitions file must be usable before pass A runs (tests/Meta/GlobalTypes: size, ending, tokens,
-- brackets, declaration blocks, the globals the project needs), since luau-lsp loads an empty one silently; a file
-- luau-lsp itself refuses to read also exits 4.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local DEFINITIONS = "tools/luau-lsp/globalTypes.None.d.luau"
local LUNE_TYPEDEFS_VERSION = "0.8.9"
local FAILING_LINTS = { UnknownGlobal = true, DeprecatedApi = true, ImplicitReturn = true }
local BENIGN_STDERR = { "[INFO]", "[WARN]", "WARNING:", "warning:" }

local started = os.clock()

-- process.exit yields the running thread, so it ends the script from anywhere in main (pcall and xpcall bodies
-- included), but not from inside an xpcall message handler: only call finish from ordinary code.
local function finish(code: number, message: string): never
	print(string.format("%s (%.1f s)", message, os.clock() - started))
	process.exit(code)
	error(message) -- not reached
end

type Run = { ok: boolean, code: number, out: string, err: string }

-- Spawns a tool directly (no shell, so globs reach the tool unexpanded). nil when it cannot be started.
local function spawn(program: string, args: { string }): Run?
	local ok, result = pcall(process.spawn, program, args)
	if not ok then
		return nil
	end
	return { ok = result.ok, code = result.code, out = result.stdout, err = result.stderr }
end

local function main(): never
	local GlobalTypes = require("../tests/Meta/GlobalTypes")
	local Requires = require("../tests/Meta/Requires")
	local Tree = require("../tests/Meta/Tree")

	-- ── arguments and preconditions ───────────────────────────────────────────────────────────────────────────

	local quick = false
	for _, a in process.args do
		if a == "--quick" and not quick then
			quick = true
		else
			finish(2, "HARNESS ERROR: unknown or repeated argument " .. a .. "\nusage: lune run scripts/verify [-- --quick]")
		end
	end
	for _, f in { "aftman.toml", "default.project.json", "test.project.json", "tests/run.luau" } do
		if not fs.isFile(f) then
			finish(2, "HARNESS ERROR: run from the repo root (" .. f .. " not found from " .. process.cwd .. ")")
		end
	end

	for _, tool in { "rojo", "luau-lsp", "lune" } do
		local run = spawn(tool, { "--version" })
		if run == nil or not run.ok then
			local detail = if run then (run.out .. run.err) else "not on PATH"
			finish(4, "MISSING TOOL: " .. tool .. " (run `aftman install` from the repo root): " .. detail)
		end
		print(string.format("[tools] %s %s", tool, (string.gsub((run :: Run).out, "%s+$", ""))))
	end
	if not fs.isFile(DEFINITIONS) then
		finish(4, "MISSING TOOL: " .. DEFINITIONS .. " (see tools/README.md)")
	end
	do
		local okRead, text = pcall(fs.readFile, DEFINITIONS)
		local why, stats = GlobalTypes.check(if okRead then text else "")
		if not okRead then
			why = "cannot be read (" .. (string.match(tostring(text), "^[^\n]*") or "") .. ")"
		end
		if why then
			finish(4, "MISSING TOOL: " .. DEFINITIONS .. " is unusable: " .. why .. "; download it again (tools/README.md)")
		end
		print(string.format("[tools] %s: %d bytes, %d declaration blocks", DEFINITIONS, stats.bytes, stats.blocks))
	end
	local home = process.env.USERPROFILE or process.env.HOME or ""
	local typedefs = home .. "/.lune/.typedefs/" .. LUNE_TYPEDEFS_VERSION .. "/process.luau"
	if not fs.isFile(typedefs) then
		finish(4, "MISSING TOOL: Lune " .. LUNE_TYPEDEFS_VERSION .. " typedefs for luau-lsp pass B; run `lune setup` once")
	end

	-- ── 1 sourcemaps ──────────────────────────────────────────────────────────────────────────────────────────

	local SOURCEMAPS = {
		{ project = "default.project.json", output = "sourcemap.json" },
		{ project = "test.project.json", output = "test.sourcemap.json" },
	}
	for _, sm in SOURCEMAPS do
		local run = spawn("rojo", { "sourcemap", sm.project, "--include-non-scripts", "--output", sm.output }) :: Run
		if not run.ok then
			print(run.out .. run.err)
			finish(2, "SOURCEMAP FAILED: rojo sourcemap " .. sm.project)
		end
	end
	print("[sourcemaps] sourcemap.json, test.sourcemap.json")

	-- ── 2 T-META-07 ───────────────────────────────────────────────────────────────────────────────────────────

	do
		local function cannotRun(why: string): never
			return finish(2, "HARNESS ERROR: T-META-07 could not run: " .. why)
		end
		local function firstLine(e: any): string
			return string.match(tostring(e), "^[^\n]*") or ""
		end
		-- Plain JSON only: rojo also reads comments in project files, @lune/serde does not.
		local function decode(path: string): any
			local okRead, text = pcall(fs.readFile, path)
			if not okRead then
				cannotRun("cannot read " .. path .. " (" .. firstLine(text) .. ")")
			end
			local okJson, value = pcall(serde.decode, "json" :: "json", text)
			if not okJson then
				cannotRun(path .. " is not plain JSON (" .. firstLine(value) .. ")")
			end
			return value
		end
		local input = {
			projects = {
				{ file = "default.project.json", json = decode("default.project.json") },
				{ file = "test.project.json", json = decode("test.project.json") },
			},
			sourcemaps = {
				{ name = "sourcemap.json", project = "default.project.json", json = decode("sourcemap.json") },
				{ name = "test.sourcemap.json", project = "test.project.json", json = decode("test.sourcemap.json") },
			},
			scan = { "src", "tests" },
			luneOnly = { "tests/lib" },
		}
		local okCheck, result = pcall(Requires.check, Tree.disk(), input)
		if not okCheck then
			cannotRun(tostring(result))
		end
		local report = result :: Requires.Report
		if #report.problems > 0 then
			for _, p in report.problems do
				print(string.format("  %s:%s: %s", p.path, tostring(p.line or "-"), p.message))
			end
			finish(2, string.format("T-META-07 FAILED: %d require problem(s)", #report.problems))
		end
		-- a sourcemap no require was compared against means the check passed vacuously (e.g. its roots went wrong)
		for _, sm in input.sourcemaps do
			if (report.checked[sm.name] or 0) == 0 then
				finish(2, "T-META-07 FAILED: no string require was compared against " .. sm.name)
			end
		end
		print(string.format("[T-META-07] ok: %d files, %d requires; compared against sourcemap.json %d, "
			.. "test.sourcemap.json %d", report.files, report.requires, report.checked["sourcemap.json"],
			report.checked["test.sourcemap.json"]))
	end

	-- ── 3 luau-lsp ────────────────────────────────────────────────────────────────────────────────────────────

	local PASSES = {
		{
			name = "A",
			args = {
				"analyze", "--platform=roblox", "--sourcemap=test.sourcemap.json",
				"--definitions:@roblox=" .. DEFINITIONS, "--ignore=vendor/**", "--formatter=plain", "src", "tests/studio",
			},
		},
		{
			name = "B",
			args = { "analyze", "--platform=standard", "--ignore=tests/studio/**", "--formatter=plain", "tests" },
		},
	}
	local errors, warnings = 0, 0
	for _, pass in PASSES do
		local run = spawn("luau-lsp", pass.args)
		if run == nil then
			finish(4, "MISSING TOOL: luau-lsp")
		end
		local r = run :: Run
		local passErrors = 0
		local inDiagnostic = false
		for _, line in string.split(r.out, "\n") do
			line = string.gsub(line, "\r$", "")
			if line ~= "" then
				-- a diagnostic is "<file>:<line>:<col>-<col>: (W0) <Kind>: <message>"; messages may continue on more lines
				local kind = string.match(line, "^.-:%d+:%d+%-%d+: %(W%d+%) (%w+): ")
				if kind == "TypeError" or kind == "SyntaxError" or (kind and FAILING_LINTS[kind]) then
					passErrors += 1
					inDiagnostic = true
					print("  error   " .. line)
				elseif kind then
					warnings += 1
					inDiagnostic = true
					print("  lint    " .. line)
				elseif inDiagnostic then
					print("          " .. line)
				else
					passErrors += 1
					print("  unknown " .. line)
				end
			end
		end
		local definitionsRefused = false
		for _, line in string.split(r.err, "\n") do
			line = string.gsub(line, "\r$", "")
			local benign = line == ""
			for _, prefix in BENIGN_STDERR do
				if string.sub(line, 1, #prefix) == prefix then
					benign = true
				end
			end
			if string.find(line, GlobalTypes.LUAU_LSP_REJECTS, 1, true) then
				definitionsRefused = true
			end
			if not benign then
				passErrors += 1
				print("  stderr  " .. line)
			end
		end
		if definitionsRefused then
			finish(4, "MISSING TOOL: luau-lsp could not read " .. DEFINITIONS .. " (pass " .. pass.name .. "); download it "
				.. "again (tools/README.md)")
		end
		if not r.ok then
			passErrors += 1
			print(string.format("  luau-lsp pass %s exited %d", pass.name, r.code))
		end
		errors += passErrors
		print(string.format("[luau-lsp] pass %s: %d error(s)", pass.name, passErrors))
	end
	if errors > 0 then
		finish(3, string.format("LUAU-LSP FAILED: %d error(s), %d other lint(s)", errors, warnings))
	end
	if warnings > 0 then
		print(string.format("[luau-lsp] %d lint warning(s) listed above (not failing)", warnings))
	end

	-- ── 4 tests ───────────────────────────────────────────────────────────────────────────────────────────────

	do
		local args = { "run", "tests/run" }
		if quick then
			table.insert(args, "--")
			table.insert(args, "--quick")
		end
		local run = spawn("lune", args)
		if run == nil then
			finish(4, "MISSING TOOL: lune")
		end
		local r = run :: Run
		local out = string.gsub(r.out .. r.err, "%s+$", "")
		print(out)
		-- the exit code and the summary must agree, so a runner that stops reporting failures cannot pass
		local failedCases = tonumber(string.match(out, "\nRESULT pass=%d+ fail=(%d+)") or string.match(out, "^RESULT pass=%d+ fail=(%d+)"))
		if r.code == 1 or (r.code == 0 and failedCases ~= nil and failedCases > 0) then
			finish(1, "TESTS FAILED")
		elseif r.code ~= 0 then
			finish(2, string.format("TEST HARNESS ERROR (tests/run exited %d)", r.code))
		elseif failedCases == nil then
			finish(2, "TEST HARNESS ERROR (tests/run printed no RESULT line)")
		end
	end

	return finish(0, "VERIFY GREEN" .. (if quick then " (--quick)" else ""))
end

local ok, err = xpcall(main, function(e: any): string
	return debug.traceback(tostring(e), 2)
end)
if not ok then
	finish(2, "HARNESS ERROR: scripts/verify crashed:\n" .. tostring(err))
end
