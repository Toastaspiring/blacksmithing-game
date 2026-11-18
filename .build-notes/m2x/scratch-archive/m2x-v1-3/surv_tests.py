# surv_tests.py <tree>: two Cover.spec cases for mutation survivors: (1) a reading entered past the budget does nothing and
# reports nothing; (2) a facet against many Ball hiders that cover none of it reports in short stretches
import sys
p = sys.argv[1] + "/tests/Physics/Cover.spec.luau"
s = open(p, encoding="utf-8", newline="").read()
anchor = '\tt.it("(f) the verdict reports its units in short stretches: C09, the slowest valid designs, 4 past the cap, a cap under a Ball", function()'
assert s.count(anchor) == 1
test = '''	-- A part's look can pass the cap before its reading starts: the reading then reads and reports nothing (Sampling makes the
	-- design TooComplex at that report, §4.4).
	t.it("(f) a reading entered past the budget does nothing and reports nothing", function()
		local parts = prepared(H.ornate().parts)
		local m = models(parts)
		for i = 1, #parts do
			if m[i] then
				local _, higher, hm = H.hidersOf(parts, i, m)
				local calls = 0
				local shown, used, over = Cover.shown(m[i], hm, higher, 0, -0.125, function(_: number)
					calls += 1
				end)
				A.eq(over, true, "part " .. i .. ": over")
				A.eq(used, 0, "part " .. i .. ": no work")
				A.eq(calls, 0, "part " .. i .. ": no report")
				A.eq(shown, if #hm == 0 then m[i].total else 0, "part " .. i .. ": no area")
			end
		end
	end)

	-- A plate ringed by 20 Balls at its height: each face's box meets the Balls' and each Ball's 128 half-spaces are projected
	-- (320 units a Ball), its pieces mostly empty. No test here ends early, so a report is SPEND_EVERY and one step at most
	-- (§4.9; 267 units at most): the projection and the pieces report as they go.
	t.it("(f) a plate ringed by 20 Balls reports in stretches of SPEND_EVERY and one step", function()
		local list = { H.part(1, "Blade", "Block", "Iron", { 0, 2, 0 }, H.I, { 0.6, 0.02, 0.6 }) }
		for _, t in ipairs({ -0.24, -0.12, 0, 0.12, 0.24 }) do
			for _, at in ipairs({ { 0.36, t }, { -0.36, t }, { t, 0.36 }, { t, -0.36 } }) do
				table.insert(list, H.part(#list + 1, "Guard", "Ball", "Iron", { at[1], 2, at[2] }, H.I, { 0.1, 0.1, 0.1 }))
			end
		end
		local parts = prepared(list)
		local m = models(parts)
		local _, higher, hm = H.hidersOf(parts, 1, m)
		A.truthy(#hm >= 20, "the Balls are its hiders: " .. #hm)
		local most, total = 0, 0
		local _, used = Cover.shown(m[1], hm, higher, math.huge, math.huge, function(n: number)
			most = math.max(most, n)
			total += n
		end)
		A.eq(total, used, "every unit reported")
		A.truthy(most <= 512, "the largest single report: " .. most)
	end)

'''
test += """	-- The stop at the budget, at every kind of step: C09's parts, the plate ringed by Balls and a Cylinder's cap under a
	-- Ball, each read with budgets swept over its whole reading. The reading stops at the first report past the budget, reports
	-- nothing after it and says so; under its total it reads to the end.
	t.it("(f) a reading stops at the first report past its budget, whatever step passes it", function()
		local lists: { { Prepared } } = { prepared(H.ornate().parts) }
		local ring = { H.part(1, "Blade", "Block", "Iron", { 0, 2, 0 }, H.I, { 0.6, 0.02, 0.6 }) }
		for _, t in ipairs({ -0.24, -0.12, 0, 0.12, 0.24 }) do
			for _, at in ipairs({ { 0.36, t }, { -0.36, t }, { t, 0.36 }, { t, -0.36 } }) do
				table.insert(ring, H.part(#ring + 1, "Guard", "Ball", "Iron", { at[1], 2.005, at[2] }, H.I, { 0.1, 0.1, 0.1 }))
			end
		end
		table.insert(lists, prepared(ring))
		table.insert(lists, prepared({
			H.part(1, "Blade", "Block", "Iron", { 0, 1, 0 }, H.I, { 0.7, 0.6, 0.65 }),
			H.part(2, "Blade", "Cylinder", "Iron", { 0, 1.006, 0 }, H.Z90, { 0.6, 0.4, 0.4 }),
			H.part(3, "Guard", "Ball", "Iron", { 0, 1.306, 0 }, H.I, { 0.08, 0.08, 0.08 }),
		}))
		for _, parts in ipairs(lists) do
			local m = models(parts)
			for i = 1, #parts do
				if m[i] then
					local _, higher, hm = H.hidersOf(parts, i, m)
					local _, total = Cover.shown(m[i], hm, higher, math.huge, math.huge)
					local step = math.max(1, math.floor(total / 23))
					for budget = 0, total + step, step do
						local reported, after = 0, 0
						local _, used, over = Cover.shown(m[i], hm, higher, math.huge, budget, function(n: number)
							if reported > budget then
								after += 1
							end
							reported += n
						end)
						A.eq(after, 0, "part " .. i .. ", budget " .. budget .. ": nothing reported after the report past it")
						A.eq(reported, used, "part " .. i .. ", budget " .. budget .. ": every unit reported")
						A.eq(over, used > budget, "part " .. i .. ", budget " .. budget .. ": over")
						if budget >= total then
							A.eq(used, total, "part " .. i .. ", budget " .. budget .. ": read to the end")
						end
					end
				end
			end
		end
	end)

"""
s = s.replace(anchor, test + anchor)
open(p, "w", encoding="utf-8", newline="").write(s)
print("ok", p)
