--!nocheck
-- Re-time designs alone on a quiet machine: the verdict (SamplingV) and the whole exposure, median of RUNS, interleaved run by
-- run; units; canonical; Analyze.run's validity (with the cap the build sets, so a design over it reads TooComplex).
-- args: runs file1.json [file2.json ...]
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local L = require("./lib")
local fmt = string.format
local RUNS = tonumber(process.args[1]) or 15
local Analyze = L.Analyze -- no cap here (snap): the validity of V1–V5

print(fmt("%-40s %9s %9s %9s %7s %6s %s", "design", "units", "verdict", "exposure", "ns/u", "canon", "Analyze.run"))
for a = 2, #process.args do
	local list = serde.decode("json", fs.readFile(process.args[a]))
	for n, d in ipairs(list) do
		local P = L.prep(d.parts)
		local e = L.SamplingV.exposure(P, nil)
		local tv, te = {}, {}
		for r = 1, RUNS do
			local t0 = os.clock()
			L.SamplingV.exposure(P, nil)
			local t1 = os.clock()
			L.Sampling.exposure(P, nil)
			local t2 = os.clock()
			tv[r], te[r] = (t1 - t0) * 1000, (t2 - t1) * 1000
		end
		local core = { schema = 1, name = "x", type = "Sword", parts = d.parts }
		local canon = L.Canonical.isCanonical(core)
		local run = Analyze.run(core)
		local codes = {}
		for _, er in ipairs(run.validation.errors) do table.insert(codes, er.code .. (if er.reason then "/" .. er.reason else "")) end
		local mv = L.median(tv)
		print(fmt("%-40s %9.0f %9.3f %9.3f %7.1f %6s %s", string.sub(fs.metadata(process.args[a]).kind and (string.match(process.args[a], "[^/\\]+$") .. " #" .. n) or "?", 1, 40),
			e.verdictWork, mv, L.median(te), mv * 1e6 / e.verdictWork, tostring(canon), if run.validation.ok then "valid" else table.concat(codes, ",")))
	end
end
