--!nocheck
-- build/precision.luau on the build (LAB_ROOT): the verdict against VisibleOracle, the fine lattice wherever a verdict
-- could be wrong at the bands. args: set shard nshards out
local process = require("@lune/process")
local fs = require("@lune/fs")
local L = require("./lab")
local Sampling, Shapes, Oracle = L.Sampling, L.Shapes, L.Oracle
local fmt = string.format
local which, shard, nshards, OUT = process.args[1], tonumber(process.args[2]), tonumber(process.args[3]), process.args[4]
local list
if which == "plausible" then
	list = ((require :: any)(L.ROOT .. "/tests/Physics/PlausibleDesigns")).all()
elseif which == "attacks" then
	list = L.Attacks
end
local FE_BANDS, FK_BANDS = { 0.025, 0.03, 0.04, 0.05 }, { 0.02, 0.015, 0.01, 0.005 }
local st = { designs = 0, parts = 0, fe = { 0, 0, 0, 0 }, fk = { 0, 0, 0, 0 }, maxFE = 0, maxFEname = "", minKept = 1, minKeptName = "" }
local rows = {}
for k, d in ipairs(list) do
	if (k - 1) % nshards == shard then
		st.designs += 1
		local P = table.create(#d.parts)
		for i, p in ipairs(d.parts) do P[i] = Shapes.prepare(p, i) end
		local e = Sampling.exposure(P)
		if not e.capped then
			local isCopy, isDust, hider = Oracle.flags(P)
			for i = 1, #P do
				if hider[i] then
					st.parts += 1
					local rough = Oracle.measure(P, i, hider, Oracle.COARSE_POINTS)
					local truth
					if (e.kept[i] and rough < 0.06) or (not e.kept[i] and rough > 0.01) then
						truth = Oracle.share(P, i, hider)
					end
					if truth then
						if not e.kept[i] then
							for b, band in ipairs(FE_BANDS) do
								if truth >= band then st.fe[b] += 1 end
							end
							if truth > st.maxFE then st.maxFE, st.maxFEname = truth, fmt("%s part %d (%s)", d.name, i, P[i].shape) end
							if truth >= 0.025 then table.insert(rows, fmt("FE %.5f %s part %d %s", truth, d.name, i, P[i].shape)) end
						else
							for b, band in ipairs(FK_BANDS) do
								if truth < band then st.fk[b] += 1 end
							end
							if truth < st.minKept then st.minKept, st.minKeptName = truth, fmt("%s part %d (%s)", d.name, i, P[i].shape) end
							if truth < 0.02 then table.insert(rows, fmt("FK %.5f %s part %d %s", truth, d.name, i, P[i].shape)) end
						end
					end
				end
			end
		end
	end
end
local text = fmt("%s shard %d/%d: %d designs, %d parts; false Enclosed at >= 2.5/3/4/5 %%: %d/%d/%d/%d, highest %.4f %% (%s); false kept under 2/1.5/1/0.5 %%: %d/%d/%d/%d, lowest kept %.4f %% (%s)",
	which, shard, nshards, st.designs, st.parts, st.fe[1], st.fe[2], st.fe[3], st.fe[4], 100 * st.maxFE, st.maxFEname, st.fk[1], st.fk[2], st.fk[3], st.fk[4],
	100 * st.minKept, st.minKeptName)
print(text)
fs.writeFile(OUT, text .. "\n" .. table.concat(rows, "\n") .. "\n")
