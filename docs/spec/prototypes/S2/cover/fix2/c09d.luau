--!nocheck
local M = require("../mlib")
local W = M.W
local function req(p) return (require :: any)(p) end
local Shapes = req(W .. "/fin/src/shared/Physics/Shapes")
local Sampling = req(W .. "/fin/src/shared/Physics/Sampling")
local T = M.tree("V")
for _, n in ipairs({ "C09", "C02", "C10", "C11" }) do
	local parts = M.fixture(n)
	local P = {}
	for i, p in ipairs(parts) do P[i] = Shapes.prepare(p, i) end
	print(n, M.dline(M.emu(T, parts, Sampling.exposure(P).kept)))
end
