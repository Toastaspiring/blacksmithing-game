--!nocheck
local V = require("./v1")
local fmt = string.format
local Fx = V.Fx
for _, list in ipairs({ Fx.calibration(), Fx.golden(), Fx.perf() }) do
	for _, b in ipairs(list) do
		local parts = V.copyParts(b.parts)
		local real = V.reads(parts)
		local R = V.emu(parts)
		print(fmt("%-34s cleaned %2d  %s", string.sub(b.name, 1, 34), #real.cleaned, V.dline(R)))
	end
end
