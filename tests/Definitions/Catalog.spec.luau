--!strict
-- tests/Definitions/Catalog.spec.luau — Definitions/Catalog (SPEC §2.3, §14.5): build, get, isEnabled, deepFreeze.

local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Prop = require("../lib/Prop")
local Test = require("../lib/Test")
local TestRng = require("../lib/TestRng")
local Tol = require("../lib/Tol")
local H = require("./DefsHelpers")
local Catalog = require("../../src/shared/Definitions/Catalog")

type Row = { id: string, order: number, enabled: boolean, payload: { number }? }

local function rows3(): { Row }
	return {
		{ id = "Gamma", order = 30, enabled = true, payload = { 3 } },
		{ id = "Alpha", order = 10, enabled = false, payload = { 1 } },
		{ id = "Beta", order = 20, enabled = true, payload = { 2 } },
	}
end

return Test.suite("Definitions/Catalog", function(t)
	t.it("build sorts rows by order, lists the enabled ones and indexes ids", function()
		local c = Catalog.build(rows3())
		A.deepEq(H.ids(c.ordered), { "Alpha", "Beta", "Gamma" })
		A.deepEq(H.ids(c.enabled), { "Beta", "Gamma" })
		A.eq(c.get("Beta"), c.ordered[2])
		A.eq(c.byId.Gamma, c.ordered[3])
		A.eq(c.get("Delta"), nil)
		A.truthy(c.isEnabled("Beta"))
		A.falsy(c.isEnabled("Alpha"), "a disabled row")
		A.falsy(c.isEnabled("Delta"), "an unknown id")
	end)

	t.it("build of an empty list gives an empty catalog", function()
		local c = Catalog.build({} :: { Row })
		A.eq(#c.ordered, 0)
		A.eq(#c.enabled, 0)
		A.eq(c.get("Alpha"), nil)
	end)

	t.it("build errors on a duplicate id or order and on malformed rows", function()
		A.throws(function()
			Catalog.build({ { id = "A", order = 1, enabled = true }, { id = "A", order = 2, enabled = true } })
		end, "duplicate id A")
		A.throws(function()
			Catalog.build({ { id = "A", order = 1, enabled = true }, { id = "B", order = 1, enabled = true } })
		end, "duplicate order 1")
		local bad: { any } = {
			{ { order = 1, enabled = true } }, -- no id
			{ { id = "", order = 1, enabled = true } },
			{ { id = 7, order = 1, enabled = true } },
			{ { id = "A", enabled = true } }, -- no order
			{ { id = "A", order = 0 / 0, enabled = true } },
			{ { id = "A", order = math.huge, enabled = true } },
			{ { id = "A", order = "1", enabled = true } },
			{ { id = "A", order = 1 } }, -- no enabled
			{ { id = "A", order = 1, enabled = 1 } },
			{ "A" },
		}
		for i, rows in bad do
			A.throws(function()
				Catalog.build(rows)
			end, "Catalog.build", "malformed case " .. i)
		end
		A.throws(function()
			Catalog.build((nil :: any))
		end, "rows must be an array")
		A.throws(function()
			Catalog.build(({ { id = "A", order = 1, enabled = true }, extra = 1 } :: any))
		end, "plain array")
		A.throws(function()
			local holes: any = { { id = "A", order = 1, enabled = true } }
			holes[3] = { id = "C", order = 3, enabled = true }
			Catalog.build(holes)
		end, "plain array")
	end)

	t.it("build freezes the catalog, its lists and every row deeply", function()
		local c = Catalog.build(rows3())
		local frozen, at = H.isDeepFrozen(c)
		A.truthy(frozen, "not frozen at " .. tostring(at))
		A.throws(function()
			(c.ordered[1] :: any).order = 99
		end, "readonly")
		A.throws(function()
			((c.ordered[1] :: any).payload :: any)[1] = 9
		end, "readonly")
	end)

	t.it("P-NOMUT build keeps the input array as written (it only freezes the rows)", function()
		local rows = rows3()
		local before = Dump.canonical(rows)
		Catalog.build(rows)
		A.eq(Dump.canonical(rows), before)
		A.eq(rows[1].id, "Gamma", "the input order is untouched")
	end)

	t.it("deepFreeze freezes nested tables once, keeps frozen ones, survives shared and cyclic tables", function()
		local shared: any = { 1, 2 }
		local already: any = table.freeze({ "x" })
		local v: any = { a = shared, b = { shared, already }, c = { d = { e = {} } } }
		v.c.d.e.back = v -- a cycle
		local out = Catalog.deepFreeze(v)
		A.eq(out, v, "returns its argument")
		local frozen, at = H.isDeepFrozen(v)
		A.truthy(frozen, "not frozen at " .. tostring(at))
		A.eq(Catalog.deepFreeze(5), 5)
		A.eq(Catalog.deepFreeze("s"), "s")
		local again = Catalog.deepFreeze(v) -- an already frozen tree is fine
		A.eq(again, v)
	end)

	t.it("P-TOTAL get and isEnabled never throw on garbage ids", function()
		local c = Catalog.build(rows3())
		local rng = TestRng.new(0xCA7A1061)
		for _ = 1, Tol.FUZZ_N_GARBAGE do
			local g = H.garbage(rng)
			local ok, got = pcall(c.get, g)
			A.truthy(ok, "get threw on " .. Dump.short(g))
			if type(g) ~= "string" then
				A.eq(got, nil, "a non-string id")
			end
			local ok2, enabled = pcall(c.isEnabled, g)
			A.truthy(ok2, "isEnabled threw on " .. Dump.short(g))
			A.eq(type(enabled), "boolean")
		end
		for _, id in { "ordered", "enabled", "byId", "get", "__index", "alpha", "ALPHA", " Alpha" } do
			A.eq(c.get(id), nil, id)
			A.falsy(c.isEnabled(id), id)
		end
	end)

	t.it("P-ORDER rows written in any order build the same catalog", function()
		local function text(c: Catalog.Catalog<Row>): string
			return Dump.canonical({ ordered = c.ordered, enabled = c.enabled, byId = c.byId })
		end
		local base = text(Catalog.build(rows3()))
		Prop.check(Tol.PROP_N, function(rng): { Row }
			return H.reshuffled(H.shuffle(rows3(), rng), rng)
		end, function(rows: { Row })
			A.eq(text(Catalog.build(rows)), base)
		end)
	end)

	t.it("P-DET two builds of equal rows are deep-equal", function()
		A.deepEq(Catalog.build(rows3()).ordered, Catalog.build(rows3()).ordered)
	end)
end)
