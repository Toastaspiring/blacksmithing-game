--!strict
-- S4 prototype v2: choose gamma (SPEC §8.3) from out/gamma_data.luau (gamma_sweep.luau).
-- Per (family, material, profile, tier): least-squares line m(a) = m0 + s*a of the mean EFFECTIVE score
-- (phi on fails) against a = D - dMin; beta = -s/m0. A step's expected contribution (1 + gamma*a) * m(a) is
-- non-decreasing on [0, aMax] iff gamma >= beta / (1 - 2*beta*aMax). Then, for candidate gammas, the ratio
-- E[contribution at the top of the tier] / E[contribution at dMin] per profile, from the measured points.
-- usage: lune run gamma_fit.luau [gamma...]
local data = require("./out/gamma_data")
local process = require("@lune/process")

local DMIN = { Normal = 0.0, Hard = 0.2 }
local AMAX = { Normal = 0.1999, Hard = 0.8 }
local cells: { [string]: { any } } = {}
local order: { string } = {}
for _, r in data do
	local k = r.family .. " " .. r.material .. " " .. r.profile .. " " .. r.tier
	if not cells[k] then
		cells[k] = {}
		table.insert(order, k)
	end
	table.insert(cells[k], { a = r.x - DMIN[r.tier], m = r.eff, raw = r.mean, pass = r.pass, tier = r.tier })
end

local gammas = {}
for _, a in process.args do
	table.insert(gammas, tonumber(a) :: number)
end
if #gammas == 0 then
	gammas = { 0.10, 0.15, 0.20 }
end

local need: { [string]: number } = {}
print("| cell | beta (rel. drop per +1 D) | gamma needed | " .. table.concat((function()
	local t = {}
	for _, g in gammas do
		table.insert(t, string.format("top/bottom at gamma %.2f", g))
	end
	return t
end)(), " | ") .. " |")
for _, k in order do
	local pts = cells[k]
	local n = #pts
	local sa, sm, saa, sam = 0, 0, 0, 0
	for _, p in pts do
		sa += p.a
		sm += p.m
		saa += p.a * p.a
		sam += p.a * p.m
	end
	local slope = (n * sam - sa * sm) / (n * saa - sa * sa)
	local m0 = (sm - slope * sa) / n
	local beta = -slope / m0
	local tier = pts[1].tier
	local aMax = AMAX[tier]
	local g = if beta > 0 then beta / (1 - 2 * beta * aMax) else 0
	local prof = string.match(k, "^%S+ %S+ (%S+)") :: string
	local key = prof .. " " .. tier
	need[key] = math.max(need[key] or 0, g)
	local ratios = {}
	for _, gm in gammas do
		local top = pts[n]
		local bot = pts[1]
		table.insert(ratios, string.format("%.3f", ((1 + gm * top.a) * top.m) / ((1 + gm * bot.a) * bot.m)))
	end
	print(string.format("| %s | %.4f | %.3f | %s |", k, beta, g, table.concat(ratios, " | ")))
end
print("# gamma needed (max over families and materials)")
for _, prof in { "Elite", "Good", "Average", "Poor" } do
	print(string.format("%-8s Normal %.3f  Hard %.3f", prof, need[prof .. " Normal"] or 0, need[prof .. " Hard"] or 0))
end
