--!nocheck
-- m2x-fix-5: rule A's decisions, the build (bounds, then the search where they leave a cap open) against the always-exact
-- rule (both caps searched) and the tree before (the caps' centres' distance + r), on every ordered pair of round parts of
-- every design (not only the hiders Sampling hands over), both ranks. Counts the pairs, the Cylinder-in-Cylinder ones, the
-- caps the bounds leave open (searched), every decision that differs, with the design.
--   lune run dec -- <set> <k> <n> [out]        (every n-th design from the k-th; set as sets.luau)
local process = require("@lune/process")
local fs = require("@lune/fs")
local Sets = require("./sets")
local W = "C:/Users/louis/AppData/Local/Temp/claude/C--Users-louis-Documents-RANDOM-ROBLOX/93ae48b4-72b9-4dc1-aa5d-451af1abf9a0/scratchpad/m2x-fix-5"
local function req(p)
	return (require :: any)(p)
end
local Shapes = req(W .. "/hook/src/shared/Physics/Shapes")
local Build = req(W .. "/hook/src/shared/Physics/Cover")
local Exact = req(W .. "/exact/src/shared/Physics/Cover")
local EPS = req(W .. "/hook/src/shared/Definitions/Balance").Geometry.EPS_GEOM
local fmt = string.format
local sqrt, abs, max = math.sqrt, math.abs, math.max
local args = process.args
local set, k, n, out = args[1], tonumber(args[2]) or 0, tonumber(args[3]) or 1, args[4]

-- the tree before's rule A for a Cylinder in a Cylinder (its `farthest`)
local function before(P, Q, higher)
	local ux, uy, uz = Q.ux, Q.uy, Q.uz
	local dx, dy, dz = P.cx - Q.cx, P.cy - Q.cy, P.cz - Q.cz
	local sx, sy, sz = P.uy * uz - P.uz * uy, P.uz * ux - P.ux * uz, P.ux * uy - P.uy * ux
	local along = abs(dx * ux + dy * uy + dz * uz) + P.hx * abs(P.ux * ux + P.uy * uy + P.uz * uz)
		+ P.r * sqrt(sx * sx + sy * sy + sz * sz) - Q.hx
	local across = 0
	for s = -1, 1, 2 do
		local mx, my, mz = dx + s * P.hx * P.ux, dy + s * P.hx * P.uy, dz + s * P.hx * P.uz
		local t = mx * ux + my * uy + mz * uz
		mx, my, mz = mx - t * ux, my - t * uy, mz - t * uz
		across = max(across, sqrt(mx * mx + my * my + mz * mz))
	end
	local v = max(along, across + P.r - Q.r)
	return if higher then v <= EPS else v < -EPS
end

local designs = Sets.load(set)
local c = { designs = 0, pairs = 0, cc = 0, searched = 0, caps = 0, differ = 0, inside = 0, beforeMoves = 0, beforeDesigns = 0 }
local lines = {}
for idx, d in ipairs(designs) do
	if (idx - 1) % n == k then
		c.designs += 1
		local P = {}
		for i, p in ipairs(d.parts) do
			P[i] = Shapes.prepare(p, i)
		end
		local moved = false
		for i = 1, #P do
			local Pi = P[i]
			if Pi.code == Shapes.CYLINDER or Pi.code == Shapes.BALL then
				for j = 1, #P do
					local Qj = P[j]
					if j ~= i and (Qj.code == Shapes.CYLINDER or Qj.code == Shapes.BALL) then
						for _, higher in ipairs({ true, false }) do
							c.pairs += 1
							local a, ua = Build._lies(Pi, Qj, higher)
							local b = Exact._lies(Pi, Qj, higher)
							if a then
								c.inside += 1
							end
							if Pi.code == Shapes.CYLINDER and Qj.code == Shapes.CYLINDER then
								c.cc += 1
								if ua > 0.5 then
									c.searched += 1
									c.caps += (ua - 0.5) / 28
								end
								if before(Pi, Qj, higher) ~= b then
									c.beforeMoves += 1
									moved = true
									table.insert(lines, fmt("before %s: %s part %d in %d (%s): %s -> %s", set, d.name, i, j,
										tostring(higher), tostring(before(Pi, Qj, higher)), tostring(b)))
								end
							end
							if a ~= b then
								c.differ += 1
								table.insert(lines, fmt("DIFFER %s: %s part %d in %d (%s): build %s, exact %s", set, d.name, i, j,
									tostring(higher), tostring(a), tostring(b)))
							end
						end
					end
				end
			end
		end
		if moved then
			c.beforeDesigns += 1
		end
	end
end
local head = fmt("%s %d/%d: %d designs, %d round pairs × rank (%d Cylinder in Cylinder), %d inside; the build's bounds left %d tests open (%d caps searched); %d decisions differ from the always-exact rule; the tree before's bound differs from it on %d (%d designs)",
	set, k, n, c.designs, c.pairs, c.cc, c.inside, c.searched, c.caps, c.differ, c.beforeMoves, c.beforeDesigns)
print(head)
for i = 1, math.min(#lines, 40) do
	print("  " .. lines[i])
end
if out then
	fs.writeFile(out, head .. "\n" .. table.concat(lines, "\n") .. "\n")
end
