--!strict
-- tests/lib/Test.luau — suite builder (SPEC §14.3). A spec file returns exactly one Suite:
--   return Test.suite("Folder/Module", function(t) t.it("does X", function() ... end) end)
-- t.slow marks statistical or fuzz cases (skipped by --quick); t.skip keeps a case listed but not run.
-- t.volume marks a slow case whose outcome only the BALANCE data, the bots and its pinned config name decide (§14.1
-- L3V): a slow case that plain runs skip and list, and only --volume runs.
-- Pure Luau, so specs stay portable.

local Tol = require("./Tol")

export type CaseFn = () -> ()
export type Case = {
	name: string,
	fn: CaseFn,
	slow: boolean,
	skip: boolean,
	volume: boolean, -- implies slow
	budgetMs: number, -- wall-clock budget: a case over it fails
}
export type Suite = { name: string, cases: { Case } }
export type Api = {
	it: (name: string, fn: CaseFn) -> (),
	slow: (name: string, fn: CaseFn) -> (),
	skip: (name: string, fn: CaseFn) -> (),
	volume: (name: string, fn: CaseFn) -> (),
}

local Test = {
	-- The runner self-test's recursion guard. The self-test (SELFTEST_SPEC under a root) sets SELFTEST_CHILD on every
	-- process it spawns, each a runner on a root under tools/runner-selftest/ or a scripts/verify. Under it the
	-- self-test spawns nothing, tests/run refuses a root that holds the self-test (tests/ itself included) and
	-- scripts/verify runs no stage, so a check broken so that a child reaches the suite holding the self-test stops
	-- there instead of starting that suite again.
	SELFTEST_CHILD = "BLACKSMITH_SELFTEST_CHILD",
	SELFTEST_SPEC = "Meta/Runner.spec.luau",
}

function Test.suite(name: string, body: (t: Api) -> ()): Suite
	assert(type(name) == "string" and name ~= "", "Test.suite: name must be a non-empty string")
	local cases: { Case } = {}
	local seen: { [string]: boolean } = {}
	local function add(caseName: string, fn: CaseFn, slow: boolean, skip: boolean, volume: boolean)
		assert(type(caseName) == "string" and caseName ~= "", "Test.suite " .. name .. ": case name must be a non-empty string")
		assert(type(fn) == "function", "Test.suite " .. name .. ": case " .. caseName .. " needs a function")
		assert(not seen[caseName], "Test.suite " .. name .. ": duplicate case name " .. caseName)
		seen[caseName] = true
		table.insert(cases, {
			name = caseName,
			fn = fn,
			slow = slow,
			skip = skip,
			volume = volume,
			budgetMs = if slow then Tol.SLOW_CASE_BUDGET_MS else Tol.CASE_BUDGET_MS,
		})
	end
	body({
		it = function(n: string, f: CaseFn)
			add(n, f, false, false, false)
		end,
		slow = function(n: string, f: CaseFn)
			add(n, f, true, false, false)
		end,
		skip = function(n: string, f: CaseFn)
			add(n, f, false, true, false)
		end,
		volume = function(n: string, f: CaseFn)
			add(n, f, true, false, true)
		end,
	})
	return { name = name, cases = cases }
end

return Test
