--!nocheck
-- m2r5: the variants measured. Each row overrides Sampling.CFG's defaults (the candidate). A variant's verdict depends only on the part itself.
local V = {}

V.defs = {
	-- the task's list
	A = { samples = 64, subWork = 6000, ballRule = "estimate" },
	A3 = { samples = 64, subWork = 3000, ballRule = "estimate" },
	A12 = { samples = 64, subWork = 12000, ballRule = "estimate" },
	D3 = { samples = 128, subWork = 3000, ballRule = "estimate" },
	D12 = { samples = 128, subWork = 12000, ballRule = "estimate" },
	B = { samples = 64, subWork = 6000, ballRule = "real" },
	C = { samples = 96, subWork = 6000, ballRule = "estimate" },
	Cr = { samples = 96, subWork = 6000, ballRule = "real" },
	D = { samples = 128, subWork = 6000, ballRule = "estimate" },
	Dr = { samples = 128, subWork = 6000, ballRule = "real" },
	-- a Ball with its own count, whatever its radius (small balls never reach nf = 3 on the ladder)
	N3 = { samples = 64, subWork = 6000, ballRule = "nf", ballNf = 3 },
	N3C = { samples = 96, subWork = 6000, ballRule = "nf", ballNf = 3 },
	N3D = { samples = 128, subWork = 6000, ballRule = "nf", ballNf = 3 },
	N4C = { samples = 96, subWork = 6000, ballRule = "nf", ballNf = 4 },
	N5C = { samples = 96, subWork = 6000, ballRule = "nf", ballNf = 5 },
	N5D = { samples = 128, subWork = 6000, ballRule = "nf", ballNf = 5 },
	-- the curve: what more samples buy
	S192 = { samples = 192, subWork = 6000, ballRule = "real" },
	S256 = { samples = 256, subWork = 6000, ballRule = "real" },
	S512 = { samples = 512, subWork = 12000, ballRule = "real" },
	-- the refined verdict: 64 samples, a Ball with nf = 4, triangles at least 2 cells per edge, the strip credit, one part hiding a whole patch, sub-grids on a
	-- Cylinder's side, no sub-grid budget. P6 is the same with the candidate's budget; PX and the like knock one rule out.
	P = { samples = 64, subWork = math.huge, ballRule = "nf", ballNf = 4, triMin = 2, rimCredit = 1 / 16, centreCredit = 1 / 4, single = true, curved = true, earlyOut = true, cornerAt = 0.98, mtf = true },
	Pnomtf = { samples = 64, subWork = math.huge, ballRule = "nf", ballNf = 4, triMin = 2, rimCredit = 1 / 16, centreCredit = 1 / 4, single = true, curved = true, earlyOut = true, cornerAt = 0.98 },
	P6 = { samples = 64, subWork = 6000, ballRule = "nf", ballNf = 4, triMin = 2, rimCredit = 1 / 16, centreCredit = 1 / 4, single = true, curved = true, earlyOut = true, cornerAt = 0.98, mtf = true },
	Pn3 = { samples = 64, subWork = math.huge, ballRule = "nf", ballNf = 3, triMin = 2, rimCredit = 1 / 16, centreCredit = 1 / 4, single = true, curved = true, earlyOut = true, cornerAt = 0.98, mtf = true },
	Pn5 = { samples = 64, subWork = math.huge, ballRule = "nf", ballNf = 5, triMin = 2, rimCredit = 1 / 16, centreCredit = 1 / 4, single = true, curved = true, earlyOut = true, cornerAt = 0.98, mtf = true },
	Pnorc = { samples = 64, subWork = math.huge, ballRule = "nf", ballNf = 4, triMin = 2, rimCredit = 0, centreCredit = 0, single = true, curved = true, earlyOut = true, cornerAt = 0.98, mtf = true },
	Pnosh = { samples = 64, subWork = math.huge, ballRule = "nf", ballNf = 4, triMin = 2, rimCredit = 1 / 16, centreCredit = 1 / 4, single = false, curved = true, earlyOut = true, cornerAt = 0.98, mtf = true },
	Pnocs = { samples = 64, subWork = math.huge, ballRule = "nf", ballNf = 4, triMin = 2, rimCredit = 1 / 16, centreCredit = 1 / 4, single = true, curved = false, earlyOut = true, cornerAt = 0.98, mtf = true },
	Pnotri = { samples = 64, subWork = math.huge, ballRule = "nf", ballNf = 4, triMin = 1, rimCredit = 1 / 16, centreCredit = 1 / 4, single = true, curved = true, earlyOut = true, cornerAt = 0.98, mtf = true },
	Pball = { samples = 64, subWork = math.huge, ballRule = "estimate", triMin = 2, rimCredit = 1 / 16, centreCredit = 1 / 4, single = true, curved = true, earlyOut = true, cornerAt = 0.98, mtf = true },
	Pmin = { samples = 64, subWork = math.huge, ballRule = "nf", ballNf = 4, triMin = 2, rimCredit = 1 / 16, centreCredit = 1 / 4, single = false, curved = false, earlyOut = true, cornerAt = 0.98, mtf = true },
	P96 = { samples = 96, subWork = math.huge, ballRule = "nf", ballNf = 4, triMin = 2, rimCredit = 1 / 16, centreCredit = 1 / 4, single = true, curved = true, earlyOut = true, cornerAt = 0.98, mtf = true },
	P128 = { samples = 128, subWork = math.huge, ballRule = "nf", ballNf = 4, triMin = 2, rimCredit = 1 / 16, centreCredit = 1 / 4, single = true, curved = true, earlyOut = true, cornerAt = 0.98, mtf = true },
	P48 = { samples = 48, subWork = math.huge, ballRule = "nf", ballNf = 4, triMin = 2, rimCredit = 1 / 16, centreCredit = 1 / 4, single = true, curved = true, earlyOut = true, cornerAt = 0.98, mtf = true },
}

function V.apply(Sampling, name)
	local cfg = Sampling.CFG
	local def = V.defs[name]
	if def == nil then
		-- a composed name: BASE+sub=3000+dirs=16+early
		local base, rest = string.match(name, "^([^+]+)(.*)$")
		def = table.clone(V.defs[base] or error("no variant " .. tostring(name)))
		for key, value in string.gmatch(rest, "%+(%a+)=?([%w%.]*)") do
			if key == "sub" then
				def.subWork = if value == "inf" then math.huge else tonumber(value)
			elseif key == "dirs" then
				def.cylDirs = tonumber(value)
			elseif key == "early" then
				def.earlyOut = true
			elseif key == "cylreal" then
				def.cylRule = "real"
			elseif key == "n" then
				def.samples = tonumber(value)
			elseif key == "nf" then
				def.ballRule, def.ballNf = "nf", tonumber(value)
			elseif key == "rc" then
				def.rimCredit = if value == "" then 1 / 16 else 1 / tonumber(value)
			elseif key == "rcone" then
				def.rimCredit1 = 1 / tonumber(value)
			elseif key == "sh" then
				def.single = true
			elseif key == "cs" then
				def.curved = true
			elseif key == "tri" then
				def.triMin = tonumber(value)
			elseif key == "cc" then
				def.centreCredit = 1 / tonumber(value)
			elseif key == "mtf" then
				def.mtf = true
			elseif key == "inset" then
				def.cornerAt = tonumber(value)
			else
				error("no knob " .. key)
			end
		end
	end
	cfg.samples = def.samples or 64
	cfg.subWork = def.subWork or 6000
	cfg.ballRule = def.ballRule or "estimate"
	cfg.ballNf = def.ballNf or 3
	cfg.cylRule = def.cylRule or "estimate"
	cfg.cylDirs = def.cylDirs or 0
	cfg.earlyOut = def.earlyOut or false
	cfg.rimCredit = def.rimCredit or 0
	cfg.rimCredit1 = def.rimCredit1 or 0
	cfg.single = def.single or false
	cfg.curved = def.curved or false
	cfg.triMin = def.triMin or 1
	cfg.centreCredit = def.centreCredit or 0
	cfg.mtf = def.mtf or false
	cfg.cornerAt = def.cornerAt or 1
	cfg.verdictOnly = false
	cfg.fullReading = false
	cfg.forceKept = nil
	cfg.stats = nil
end

return V
