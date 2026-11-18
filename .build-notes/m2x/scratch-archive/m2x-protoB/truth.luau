--!nocheck
-- The truth for the attack harnesses (v1.luau, lib.luau): tests/Physics/VisibleOracle.luau on the true shapes, the task's
-- truth. T.all(parts): per part its share, or false for Dust and exact copies (they have no verdict to compare).
local Shapes = require("./repo/src/shared/Physics/Shapes")
local Oracle = require("./repo/tests/Physics/VisibleOracle")

local T = {}

function T.all(parts, _cell)
	local P = table.create(#parts)
	for i, p in ipairs(parts) do
		P[i] = Shapes.prepare(p, i)
	end
	local _, _, hider = Oracle.flags(P)
	local out = {}
	for i = 1, #P do
		out[i] = if hider[i] then Oracle.share(P, i, hider) else false
	end
	return out, P
end

-- the older harness's names (a30_more): solids, hidersOf, share
function T.solids(parts)
	local P = table.create(#parts)
	for i, p in ipairs(parts) do
		P[i] = Shapes.prepare(p, i)
	end
	return P
end

function T.hidersOf(S)
	local _, _, hider = Oracle.flags(S)
	return hider
end

function T.share(S, i, hider, _cell)
	return Oracle.share(S, i, hider)
end

return T
