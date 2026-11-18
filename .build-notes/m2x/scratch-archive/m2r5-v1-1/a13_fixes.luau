--!nocheck
-- All of the prototype's fixtures, cleaned and D: run in the base folder and in an alt folder, then diff.
local V = require("./v1")
local fmt = string.format
local Fx = V.Fx
for _, list in ipairs({ Fx.calibration(), Fx.golden(), Fx.adversarial(), Fx.regression(), Fx.perf() }) do
	for _, b0 in ipairs(list) do
		local b = if b0.parts then b0 elseif b0.fixture then b0.fixture else nil
		if not b then
			for _, v in b0 do
				if type(v) == "table" and v.parts then b = v end
			end
		end
		local parts = V.copyParts(b.parts)
		local ok, R = pcall(V.emu, parts)
		if ok and R.steps then
			local ids = {}
			for _, c in ipairs(R.buildExposure.cleaned) do table.insert(ids, tostring(c.partId)) end
			print(fmt("%-34s %s | cleaned %s", string.sub(b.name, 1, 34), V.dline(R), table.concat(ids, " ")))
		else
			print(fmt("%-34s no steps", string.sub(b.name, 1, 34)))
		end
	end
end
