-- Extra checks cited in the spec: A16/A17 bit-identity, sensitivity of the arming sword, comb chains.
local Analyze = require("./analyze")
local Fx = require("./fixtures")
local fmt = string.format
local function line(R)
	local t = {}
	for _, s in ipairs(R.steps) do table.insert(t, fmt("%s %.4f %s", string.sub(s.step, 1, 2), s.d, string.sub(s.tier, 1, 1))) end
	return table.concat(t, " | ")
end
local function same(A, B)
	for i, s in ipairs(A.steps) do
		if s.d ~= B.steps[i].d or s.g ~= B.steps[i].g then return false end
		for k, f in ipairs(s.factors) do if f.raw ~= B.steps[i].factors[k].raw then return false end end
	end
	return true
end
local g = Fx.golden()
local F1, F2 = g[1], g[2]
-- A16: F1 + parts inside blade and guard
local t = Fx.copy(F1)
table.insert(t, Fx.P("InBlade", "Block", "Blade", "Steel", { 0, 2.6, 0 }, Fx.I, { 0.08, 1.0, 0.03 }))
table.insert(t, Fx.P("InGuard", "Block", "Guard", "Iron", { 0.2, 1.29, 0 }, Fx.I, { 0.3, 0.1, 0.1 }))
local A16 = Analyze.run(Fx.bp("A16", t))
local B1 = Analyze.run(F1)
local c = {}
for _, x in ipairs(A16.cleaned) do table.insert(c, x.reason .. "#" .. x.partId) end
print(fmt("A16 F1 + parts inside blade and guard: cleaned[%s] bit-identical D/factors: %s | mass %.5f vs %.5f", table.concat(c, ","), tostring(same(A16, B1)), A16.physics.mass, B1.physics.mass))
-- A17: F2 + 3 exact blade copies
local t2 = Fx.copy(F2)
for k = 1, 3 do table.insert(t2, Fx.P("Copy" .. k, "Block", "Blade", "Iron", { 0, 2.75, 0 }, Fx.I, { 0.20, 2.40, 0.08 })) end
local A17 = Analyze.run(Fx.bp("A17", t2))
local B2 = Analyze.run(F2)
c = {}
for _, x in ipairs(A17.cleaned) do table.insert(c, x.reason .. "#" .. x.partId) end
print(fmt("A17 F2 + 3 exact blade copies: cleaned[%s] bit-identical: %s | mass %.5f vs %.5f", table.concat(c, ","), tostring(same(A17, B2)), A17.physics.mass, B2.physics.mass))
-- sensitivity: arming blade longer by dL (tips moved up), F5 blade thinner
local a = Fx.arming("Iron")
for _, dL in ipairs({ 0.15, 0.20, 0.22, 0.25, 0.30 }) do
	local u = Fx.copy(a)
	for _, p in ipairs(u) do
		if p.label == "Blade" then p.size[2] += dL; p.pos[2] += dL / 2 end
		if p.label == "TipR" or p.label == "TipL" then p.pos[2] += dL end
	end
	print(fmt("arming blade +%.2f: %s", dL, line(Analyze.run(Fx.bp("x", u)))))
end
for _, th in ipairs({ 0.055, 0.05, 0.047, 0.045, 0.043 }) do
	local u = Fx.copy(g[5])
	for _, p in ipairs(u) do
		if p.label == "Blade" then p.size[3] = th end
	end
	print(fmt("F5 blade %.3f thick: %s", th, line(Analyze.run(Fx.bp("x", u)))))
end
-- comb blade chains
local P5 = Fx.perf()[5]
local R5 = Analyze.run(P5)
local lens = {}
for _, ch in ipairs(R5.edge.chains) do table.insert(lens, fmt("%.3f", ch.length)) end
print(fmt("P5 comb: valid=%s chains %d [%s] EdgeLength %.3f (all chains %.3f) | %s", tostring(R5.valid), #R5.edge.chains, table.concat(lens, ","), R5.edge.length, R5.edge.allChainsLength, line(R5)))
-- chain orientation of F5's main chain (first/last points)
local ch = Analyze.run(g[5]).edge.chains[1]
print(fmt("F5 main chain: %d points, first (%.3f,%.3f) last (%.3f,%.3f)", #ch.points, ch.points[1][1], ch.points[1][2], ch.points[#ch.points][1], ch.points[#ch.points][2]))
