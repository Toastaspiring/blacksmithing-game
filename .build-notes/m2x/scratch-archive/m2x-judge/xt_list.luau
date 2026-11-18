--!nocheck
local process = require("@lune/process")
local L = require("./jlib")
local T = require("./tangles")
local fmt = string.format
local seed = tonumber(process.args[1] or "7")
local count = tonumber(process.args[2] or "200")
local designs = T.corpus(seed, count, 3, 14)
for k, d in ipairs(designs) do
	local P = L.prep(d.parts)
	local flags = { L.flags(P) }
	local A = L.readA(P, nil, flags)
	local B = L.readB(P, 32, 4, false, flags)
	local Jb = L.JBrute.readAll(P, flags, L.cands, nil, 3000)
	for i = 1, #P do
		if A[i] then
			local a, b = A[i].shown / A[i].area, B[i].shown / B[i].area
			local j = if Jb[i].skipped then nil else Jb[i].shown / Jb[i].area
			if math.abs(a - b) > 1e-9 or (j and (math.abs(a - j) > 1e-9 or math.abs(b - j) > 1e-9)) then
				print(fmt("%s part %d %s: A %.12f B %.12f J %s  |A-J| %.3g |B-J| %.3g", d.name, i, P[i].shape, a, b, if j then fmt("%.12f", j) else "skip",
					if j then math.abs(a - j) else -1, if j then math.abs(b - j) else -1))
			end
		end
	end
end
