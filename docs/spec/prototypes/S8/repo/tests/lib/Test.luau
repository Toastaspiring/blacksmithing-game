--!strict
-- tests/lib/Test.luau — suite builder. A spec file returns exactly one Suite.
-- PROTOTYPE (S8). Pure Luau, no Lune APIs, so specs stay portable.

export type CaseFn = () -> ()
export type Case = {
	name: string,
	fn: CaseFn,
	slow: boolean, -- statistical / fuzz cases; skipped by --quick
	skip: boolean,
	budgetMs: number, -- wall-clock budget; exceeding it fails the case
}
export type Suite = { name: string, cases: { Case } }
export type Api = {
	it: (name: string, fn: CaseFn) -> (),
	slow: (name: string, fn: CaseFn) -> (),
	skip: (name: string, fn: CaseFn) -> (),
}

local DEFAULT_BUDGET_MS = 2000 -- one unit case; anything slower is a perf bug or belongs in t.slow
local SLOW_BUDGET_MS = 20000 -- statistical cases (bots, 10k fuzz)

local Test = {}

function Test.suite(name: string, body: (t: Api) -> ()): Suite
	local cases: { Case } = {}
	local seen: { [string]: boolean } = {}
	local function add(caseName: string, fn: CaseFn, slow: boolean, skip: boolean)
		assert(not seen[caseName], "duplicate case name in suite " .. name .. ": " .. caseName)
		seen[caseName] = true
		table.insert(cases, {
			name = caseName,
			fn = fn,
			slow = slow,
			skip = skip,
			budgetMs = if slow then SLOW_BUDGET_MS else DEFAULT_BUDGET_MS,
		})
	end
	body({
		it = function(n: string, f: CaseFn) add(n, f, false, false) end,
		slow = function(n: string, f: CaseFn) add(n, f, true, false) end,
		skip = function(n: string, f: CaseFn) add(n, f, false, true) end,
	})
	return { name = name, cases = cases }
end

return Test
