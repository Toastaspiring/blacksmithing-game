--!nocheck
-- fix-4: the circle's worst place: a Block a (across) × len (along d) × t laid with a face in a plane at height h over a
-- Ball's centre (the plane z = h, its 32-gon from Y: corners at 5.625° + k·11.25°), poking p out of the sphere along d,
-- d at a corner of the 32-gon (its over there up to 0.0048 ρ) or at a side's middle (none). Its end face's plane misses
-- the sphere and shows whole; the strips of its faces in planes near the centre, out of the sphere by less than the
-- 32-gon's over, are buried. Per tree, cleaned that truly show 2 % or more, kept truly under 2 %, the largest true share
-- cleaned; the truth by VisibleOracle on the last tree.
--   lune run pokeplane -- <r> <tree> [<tree> ...]
local process = require("@lune/process")
local V = require("./vlab")
local fmt = string.format
local R = tonumber(process.args[1])
local names = {}
for i = 2, #process.args do
	table.insert(names, process.args[i])
end
local T = {}
for i, n in ipairs(names) do
	T[i] = V.tree(n)
end
local N = T[#T]
local C = { 0, 1, 0 }
local stat = {}
for i = 1, #T do
	stat[i] = { wrong = 0, worst = 0, what = "", keptLow = 0 }
end
local count = 0
for _, where in ipairs({ "corner", "middle" }) do
	local th = if where == "corner" then math.rad(5.625) else 0
	local d = { -math.sin(th), math.cos(th), 0 }
	local rot = N.H.axisAngle(0, 0, 1, math.deg(th))
	for _, h in ipairs({ 0, 0.1 * R, 0.3 * R }) do
		for _, a in ipairs({ 0.02, 0.03, 0.04, 0.06 }) do
			for _, t in ipairs({ 0.02, 0.03 }) do
				for _, len in ipairs({ 0.1, 0.2, 0.3, 0.4 }) do
					if a * t * len >= 0.0002 and len < 2 * R then
						for _, f in ipairs({ 0.0005, 0.001, 0.002, 0.003, 0.004, 0.0048 }) do
							local p = f * R
							local k = R + p - len / 2
							local parts = N.copy({
								N.part("Pommel", "Ball", C, nil, { 2 * R, 2 * R, 2 * R }),
								N.part("Blade", "Block", { C[1] + k * d[1], C[2] + k * d[2], C[3] + h - t / 2 }, rot, { a, len, t }),
							})
							count += 1
							local P = N.prep(parts)
							local _, _, hider = N.Oracle.flags(P)
							local truth = N.Oracle.share(P, 2, hider)
							for i, L in ipairs(T) do
								local read = L.H.reads(L.prep(parts), 2)
								local st = stat[i]
								if read < 0.02 and truth >= 0.02 then
									st.wrong += 1
									if truth > st.worst then
										st.worst, st.what = truth, fmt("%s, h %.2f r, Block %.2f × %.2f × %.2f, %.5f out (%.4f r): reads %.3f%%, truth %.3f%%", where, h / R, a, len, t, p, f, 100 * read, 100 * truth)
									end
								elseif read >= 0.02 and truth < 0.02 then
									st.keptLow += 1
								end
							end
						end
					end
				end
			end
		end
	end
end
for i, n in ipairs(names) do
	local st = stat[i]
	print(fmt("%s, Ball r %.2f: %d Blocks; %d cleaned that truly show 2 %% or more, %d kept truly under 2 %%", n, R, count, st.wrong, st.keptLow))
	if st.wrong > 0 then
		print("  the largest true share cleaned: " .. st.what)
	end
end
