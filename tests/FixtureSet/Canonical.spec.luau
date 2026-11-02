--!strict
-- The structural expectations of the fixture set, checked against Blueprint/Canonical (SPEC §3.5, §3.6; the M1 part
-- of §14.7's "expected codes"): every fixture is a fixed point, every adversarial draft gets its expected code and
-- path or its expected canonical value, bit for bit, and nothing throws. Canonical's own suites (T-BP) own its
-- properties; this suite owns the fixture data's claims about it.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Adversarial = require("../fixtures/Adversarial")
local Blueprints = require("../fixtures/Blueprints")
local Shape = require("./Shape")
local Canonical = require("../../src/shared/Blueprint/Canonical")

local function draftOf(raw: any): any
	local ok, result = pcall(Canonical.draft, raw)
	if not ok then
		A.fail("Canonical.draft threw: " .. tostring(result))
	end
	return result
end

local function describe(result: any): string
	if type(result) ~= "table" then
		return tostring(result)
	end
	return if result.ok then "ok" else string.format("{code = %s, path = %q}", tostring(result.code), tostring(result.path))
end

return Test.suite("FixtureSet/Canonical", function(t)
	t.it("F1–F5 are fixed points of the canonical form", function()
		for _, f in Blueprints.list do
			local r = draftOf(f.core)
			A.truthy(r.ok, f.id .. " accepted, got " .. describe(r))
			A.eq(Shape.bitDifference(r.value, f.core), nil, f.id .. " canonical value = the fixture, bit for bit")
			A.truthy(Canonical.isCanonical(f.core :: any), f.id .. " isCanonical")
			A.truthy(Canonical.isCanonical(f.core :: any, { bounds = false }), f.id .. " isCanonical without bounds")
		end
	end)

	t.it("every adversarial draft gets its expected Canonical result", function()
		for _, v in Adversarial.variants do
			local c = v.canon
			local r = draftOf(v.draft())
			if not c.ok then
				A.truthy(r.ok == false, v.key .. ": expected " .. tostring(c.code) .. ", got " .. describe(r))
				A.eq(r.code, c.code, v.key .. " code")
				A.eq(r.path, c.path, v.key .. " path")
				continue
			end
			A.truthy(r.ok == true, v.key .. ": expected ok, got " .. describe(r))
			if c.equals then
				local want = if c.equals == "draft" then v.draft() else Blueprints.get(c.equals :: string).core
				A.eq(Shape.bitDifference(r.value, want), nil, v.key .. " canonical value = " .. (c.equals :: string))
			else
				local renorm = c.renormalized :: { part: number, rot: { number } }
				local want = v.draft()
				local got = r.value.parts[renorm.part].rot
				local n2 = got[1] * got[1] + got[2] * got[2] + got[3] * got[3] + got[4] * got[4]
				A.near(n2, 1, 1e-15, v.key .. " ‖q‖² after C3")
				for k = 1, 4 do
					A.near(got[k], renorm.rot[k], 1e-12, v.key .. " rot[" .. k .. "]")
				end
				want.parts[renorm.part].rot = got
				A.eq(Shape.bitDifference(r.value, want), nil, v.key .. " nothing else changed")
			end
		end
	end)

	t.it("accepted drafts canonicalize idempotently and leave their input untouched", function()
		for _, v in Adversarial.variants do
			if not v.canon.ok then
				continue
			end
			local raw = v.draft()
			local before = v.draft()
			local r = draftOf(raw)
			A.eq(Shape.bitDifference(raw, before), nil, v.key .. " input unchanged (P-NOMUT)")
			local again = draftOf(r.value)
			A.truthy(again.ok, v.key .. " second pass accepted")
			A.eq(Shape.bitDifference(again.value, r.value), nil, v.key .. " Canonical(Canonical(x)) = Canonical(x)")
			A.truthy(Canonical.isCanonical(r.value), v.key .. " the value isCanonical")
		end
	end)
end)
