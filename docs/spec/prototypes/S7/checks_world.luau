--!strict
-- Throwaway S7 prototype: world-layout checks. Run: lune run checks_world.luau
local V = require("./vecmath")
local L = require("./layout")

local function obbOf(p: L.PartSpec): V.Obb
	return { c = p.xf.p, r = p.xf.r, h = V.scale(p.size, 0.5) }
end

print("==================== 1. ring layout ====================")
-- 2D polygon (XZ) of a plot square in world space
local function plotPoly(i: number, R: number): { { number } }
	local xf = L.plotXform(i, R)
	local h = L.PLOT_SIZE / 2
	local out = {}
	for _, c in { { -h, -h }, { h, -h }, { h, h }, { -h, h } } do
		local w = V.point(xf, V.v(c[1], 0, c[2]))
		table.insert(out, { w[1], w[3] })
	end
	return out
end
local function segPointDist(a: { number }, b: { number }, p: { number }): number
	local dx, dz = b[1] - a[1], b[2] - a[2]
	local t = ((p[1] - a[1]) * dx + (p[2] - a[2]) * dz) / (dx * dx + dz * dz)
	t = math.clamp(t, 0, 1)
	local qx, qz = a[1] + t * dx, a[2] + t * dz
	return math.sqrt((p[1] - qx) ^ 2 + (p[2] - qz) ^ 2)
end
local function polyDist(A: { { number } }, B: { { number } }): number
	local best = math.huge
	for _ = 1, 2 do
		for i = 1, #A do
			local a, b = A[i], A[i % #A + 1]
			for _, p in B do
				best = math.min(best, segPointDist(a, b, p))
			end
		end
		A, B = B, A
	end
	return best
end
for _, R in { 70, 76, 80, 84, 86, 88, 92 } do
	local gap = polyDist(plotPoly(1, R), plotPoly(2, R))
	local frontEdge = R - L.PLOT_SIZE / 2
	local backCorner = math.sqrt((R + L.PLOT_SIZE / 2) ^ 2 + (L.PLOT_SIZE / 2) ^ 2)
	print(string.format("R=%5.1f  adjacent-plot gap=%6.2f  plaza radius (front-edge midpoint)=%5.1f  back-corner radius=%6.2f", R, gap, frontEdge, backCorner))
end

local R = 86
print(("chosen PLOT_RING_RADIUS = %d"):format(R))
local backCorner = math.sqrt((R + 20) ^ 2 + 20 ^ 2)
print(("back-corner radius %.2f -> boundary wall radius = ceil(+8) = %d, ground disc diameter = %d"):format(backCorner, math.ceil(backCorner + 8), 2 * (math.ceil(backCorner + 8) + 4)))
for i = 1, 8 do
	local xf = L.plotXform(i, R)
	local lv = V.look(xf)
	print(string.format("  plot %d centre %s yaw %5.1f  look %s", i, V.fmt(xf.p), (i - 1) * 45, V.fmt(lv)))
end
-- walking distances
local frontMid = R - 20
local chordFront = 2 * frontMid * math.sin(math.rad(22.5))
print(string.format("front-edge-midpoint to neighbour front-edge-midpoint: %.1f studs (%.1f s at WalkSpeed 16)", chordFront, chordFront / 16))
print(string.format("plaza centre to plot front edge: %.1f studs (%.1f s)", frontMid, frontMid / 16))

print("==================== 2. part budget ====================")
local plot = L.buildPlot()
local byComp: { [string]: number } = {}
local order: { string } = {}
local collide, query, decor = 0, 0, 0
for _, p in plot do
	local comp = p.comp:match("^Station:") and p.comp or p.comp
	if byComp[comp] == nil then
		byComp[comp] = 0
		table.insert(order, comp)
	end
	byComp[comp] += 1
	if p.collide then
		collide += 1
	end
	if p.query then
		query += 1
	end
	if not p.collide then
		decor += 1
	end
end
for _, c in order do
	print(string.format("  %-22s %3d", c, byComp[c]))
end
print(string.format("  plot static total: %d parts (CanCollide %d, CanQuery %d, decor/no-collide %d)", #plot, collide, query, decor))

print("==================== 3. bounds ====================")
local minx, maxx, miny, maxy, minz, maxz = math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
for _, p in plot do
	local o = obbOf(p)
	for sx = -1, 1, 2 do
		for sy = -1, 1, 2 do
			for sz = -1, 1, 2 do
				local w = V.point(V.xf(o.c, o.r), V.v(sx * o.h[1], sy * o.h[2], sz * o.h[3]))
				minx, maxx = math.min(minx, w[1]), math.max(maxx, w[1])
				miny, maxy = math.min(miny, w[2]), math.max(maxy, w[2])
				minz, maxz = math.min(minz, w[3]), math.max(maxz, w[3])
			end
		end
	end
end
print(string.format("  plot-local extents x[%.2f, %.2f] y[%.2f, %.2f] z[%.2f, %.2f]", minx, maxx, miny, maxy, minz, maxz))

print("==================== 4. unintended overlaps between collidable parts ====================")
local expected = {
	["Chimney|RoofBack"] = true,
	["ChimneyCap|RoofBack"] = true,
	["Chimney|Furnace.Hood"] = true,
}
local count = 0
for i = 1, #plot do
	for j = i + 1, #plot do
		local a, b = plot[i], plot[j]
		if a.collide and b.collide and a.comp ~= b.comp then
			if V.obbOverlap(obbOf(a), obbOf(b), 0.02) then
				local key = a.name .. "|" .. b.name
				local key2 = b.name .. "|" .. a.name
				if not (expected[key] or expected[key2]) then
					count += 1
					print("  overlap: " .. a.name .. " <-> " .. b.name)
				end
			end
		end
	end
end
print("  unexpected overlaps (cross-component, 0.02 tolerance): " .. count)

print("==================== 5. stand points (character clearance 2 x 5.2 x 1.4) ====================")
local function standXf(st: L.StationDef): V.Xform
	-- feet at stand point, facing +Z of the station (towards it)
	local local_ = V.xf(V.v(st.stand[1], st.stand[2], st.stand[3]), V.I)
	return V.compose(st.root, local_)
end
for _, st in L.STATIONS do
	local s = standXf(st)
	local box: V.Obb = { c = V.point(s, V.v(0, 2.65, 0)), r = s.r, h = { 1.0, 2.6, 0.7 } }
	local hits = {}
	for _, p in plot do
		if p.collide and V.obbOverlap(box, obbOf(p), 0.0) then
			table.insert(hits, p.name)
		end
	end
	print(string.format("  %-14s stand %s  blocked by: %s", st.id, V.fmt(s.p), #hits == 0 and "none" or table.concat(hits, ", ")))
end
-- spawn point (revision: the per-plot HomeSpawn pad at the home pose; its top must be flush with the floor)
do
	local sp = V.v(L.HOME_POS[1], L.FLOOR_TOP, L.HOME_POS[3])
	for _, p in plot do
		if p.name == "HomeSpawn" then
			local top = p.xf.p[2] + p.size[2] / 2
			print(string.format("  HomeSpawn pad centre %s size %s top y %.3f (floor top %.3f) collide %s query %s",
				V.fmt(p.xf.p), V.fmt(p.size), top, L.FLOOR_TOP, tostring(p.collide), tostring(p.query)))
		end
	end
	local box: V.Obb = { c = V.add(sp, V.v(0, 2.65, 0)), r = V.I, h = { 1.0, 2.6, 0.7 } }
	local hits = {}
	for _, p in plot do
		if p.collide and V.obbOverlap(box, obbOf(p), 0.0) then
			table.insert(hits, p.name)
		end
	end
	print(string.format("  %-14s spawn %s blocked by: %s", "Spawn", V.fmt(sp), #hits == 0 and "none" or table.concat(hits, ", ")))
end

print("==================== 6. station camera framings ====================")
local ASPECT = 16 / 9
for _, st in L.STATIONS do
	local eye = V.point(st.root, V.v(st.cam.eye[1], st.cam.eye[2], st.cam.eye[3]))
	local tgt = V.point(st.root, V.v(st.cam.at[1], st.cam.at[2], st.cam.at[3]))
	local fwd = V.norm(V.sub(tgt, eye))
	-- eye clearance
	local minClear = math.huge
	local nearest = ""
	for _, p in plot do
		if p.collide or p.query then
			local d = V.pointObbDist(eye, obbOf(p))
			if d < minClear then
				minClear = d
				nearest = p.name
			end
		end
	end
	-- obstruction eye -> target excluding own station parts
	local blocked = {}
	for _, p in plot do
		if (p.collide or p.query) and p.comp ~= "Station:" .. st.id then
			local t = V.segObb(eye, tgt, obbOf(p))
			if t then
				table.insert(blocked, p.name)
			end
		end
	end
	-- angular placement of the smith's head and of the work point
	local s = standXf(st)
	local head = V.point(s, V.v(0, 4.6, 0))
	local chest = V.point(s, V.v(0, 3.0, 0))
	local work = V.point(st.root, V.v(st.work[1], st.work[2], st.work[3]))
	local right = V.norm(V.cross(fwd, V.v(0, 1, 0)))
	local up = V.cross(right, fwd)
	local function screen(p: V.Vec3): (number, number)
		local d = V.sub(p, eye)
		local z = V.dot(d, fwd)
		local tv = math.tan(math.rad(st.cam.fov / 2))
		local th = tv * ASPECT
		return V.dot(d, right) / z / th, V.dot(d, up) / z / tv -- NDC in [-1,1] when on screen
	end
	local hx, hy = screen(head)
	local cx, cy = screen(chest)
	local wx, wy = screen(work)
	-- does the smith (box) occlude the work point?
	local smithBox: V.Obb = { c = V.point(s, V.v(0, 2.65, 0)), r = s.r, h = { 1.0, 2.6, 0.6 } }
	local occl = V.segObb(eye, work, smithBox) ~= nil
	print(string.format("  %-14s eye %s -> at %s fov %d | eye clearance %.2f (%s) | blocked by: %s", st.id, V.fmt(eye), V.fmt(tgt), st.cam.fov, minClear, nearest, #blocked == 0 and "none" or table.concat(blocked, ",")))
	print(string.format("  %-14s NDC smith head (%.2f, %.2f) chest (%.2f, %.2f) work (%.2f, %.2f) | smith occludes work point: %s | eye-target dist %.2f", "", hx, hy, cx, cy, wx, wy, tostring(occl), V.len(V.sub(tgt, eye))))
end

print("==================== 7. prompts ====================")
local prompts: { { name: string, p: V.Vec3 } } = {}
for _, st in L.STATIONS do
	if st.prompt then
		table.insert(prompts, { name = st.id .. "(" .. (st.promptKind :: string) .. ")", p = V.point(st.root, V.v(st.prompt[1], st.prompt[2], st.prompt[3])) })
	end
end
for i = 1, L.SLOT_COUNT_MVP do
	table.insert(prompts, { name = "Stand" .. i, p = V.point(L.slotRoot(i), V.v(L.STAND.prompt[1], L.STAND.prompt[2], L.STAND.prompt[3])) })
end
local minPair, pairName = math.huge, ""
for i = 1, #prompts do
	for j = i + 1, #prompts do
		local d = V.len(V.sub(prompts[i].p, prompts[j].p))
		if d < minPair then
			minPair = d
			pairName = prompts[i].name .. " / " .. prompts[j].name
		end
	end
end
print(string.format("  min prompt-to-prompt distance %.2f (%s)", minPair, pairName))
for _, st in L.STATIONS do
	if st.prompt then
		local pp = V.point(st.root, V.v(st.prompt[1], st.prompt[2], st.prompt[3]))
		local s = V.point(st.root, V.v(st.stand[1], st.stand[2] + 2.5, st.stand[3]))
		print(string.format("  %s prompt %s, distance from stand (root height) %.2f", st.id, V.fmt(pp), V.len(V.sub(pp, s))))
	end
end
-- distance from a visitor standing outside the front posts (z=-13.5) to the stand prompts
for i = 1, L.SLOT_COUNT_MVP do
	local pp = V.point(L.slotRoot(i), V.v(L.STAND.prompt[1], L.STAND.prompt[2], L.STAND.prompt[3]))
	local visitor = V.v(L.SLOT_X[i], L.FLOOR_TOP + 2.5, -14)
	if i == 1 then
		print(string.format("  visitor at z=-14 (outside front posts) -> stand prompt distance %.2f", V.len(V.sub(pp, visitor))))
	end
end

print("==================== 8. stand spacing ====================")
do
	local buf = {}
	for i = 1, L.SLOT_COUNT_MVP - 1 do
		table.insert(buf, string.format("%.1f", L.SLOT_X[i + 1] - L.SLOT_X[i]))
	end
	print("  centre-to-centre pitch: " .. table.concat(buf, " ") .. " ; gap between caps = pitch - 2.3")
end
print(string.format("  central aisle width between stands 3 and 4: %.1f", (L.SLOT_X[4] - 1.15) - (L.SLOT_X[3] + 1.15)))
local cradleY = L.FLOOR_TOP + L.STAND.cradle[2]
print(string.format("  cradle height (plot y) = %.2f; item top for a 6-stud sword = %.2f (front beam underside 12.5, sign bottom 9.5 at x in [-5,5])", cradleY, cradleY + 6))

print("==================== 9. step transitions (camera path + walk path) ====================")
do
	local order = { "Furnace", "Anvil", "Grindstone" }
	local byId: { [string]: L.StationDef } = {}
	for _, st in L.STATIONS do
		byId[st.id] = st
	end
	for i = 1, #order - 1 do
		local a, b = byId[order[i]], byId[order[i + 1]]
		local ea = V.point(a.root, V.v(a.cam.eye[1], a.cam.eye[2], a.cam.eye[3]))
		local eb = V.point(b.root, V.v(b.cam.eye[1], b.cam.eye[2], b.cam.eye[3]))
		local camHits = {}
		for _, p in plot do
			if (p.collide or p.query) and V.segObb(ea, eb, obbOf(p)) then
				table.insert(camHits, p.name)
			end
		end
		-- walk path: sweep the character box (2 x 5.2 x 1.4) in 20 steps between stand points
		local sa = V.point(a.root, V.v(a.stand[1], a.stand[2], a.stand[3]))
		local sb = V.point(b.root, V.v(b.stand[1], b.stand[2], b.stand[3]))
		local walkHits: { [string]: boolean } = {}
		local dir = V.norm(V.sub(sb, sa))
		local yaw = math.deg(math.atan2(-dir[1], -dir[3]))
		for k = 1, 19 do -- endpoints are validated by check 5 (character faces the station there)
			local c = V.add(V.add(sa, V.scale(V.sub(sb, sa), k / 20)), V.v(0, 2.65, 0))
			local box: V.Obb = { c = c, r = V.rotY(yaw), h = { 1.0, 2.6, 0.7 } }
			for _, p in plot do
				if p.collide and V.obbOverlap(box, obbOf(p), 0.0) then
					walkHits[p.name] = true
				end
			end
		end
		local wl = {}
		for n in walkHits do
			table.insert(wl, n)
		end
		print(string.format("  %s -> %s : camera path %.1f studs, blocked by %s | walk %.1f studs (%.2f s at 16 st/s), blocked by %s",
			a.id, b.id, V.len(V.sub(eb, ea)), #camHits == 0 and "none" or table.concat(camHits, ","), V.len(V.sub(sb, sa)), V.len(V.sub(sb, sa)) / 16, #wl == 0 and "none" or table.concat(wl, ",")))
	end
end

print("==================== 10. plaza budget ====================")
do
	local lamps, perLamp = 8, 4
	local trees, perTree = 8, 3
	local wallSegs = 36
	local chord = 2 * 116 * math.sin(math.rad(360 / wallSegs / 2))
	-- revision: no plaza spawn (one HomeSpawn per plot, counted in the plot); render cap = Limits.MAX_PARTS
	local plaza = 1 + 1 + lamps * perLamp + trees * perTree + wallSegs * 2
	print(string.format("  ground disc 1 + plaza disc 1 + lamps %d + trees %d + boundary %d (36 x visible+collider, chord %.2f) = %d parts", lamps * perLamp, trees * perTree, wallSegs * 2, chord, plaza))
	local static = #plot * L.PLOT_COUNT + plaza
	print(string.format("  world static total = %d x %d + %d = %d parts", #plot, L.PLOT_COUNT, plaza, static))
	local items = L.PLOT_COUNT * L.SLOT_COUNT_MVP * (L.MAX_PARTS + 1)
	local wp = L.PLOT_COUNT * L.MAX_PARTS
	print(string.format("  + displayed items worst case %d (incl. %d hitboxes) + workpieces worst case %d = %d parts", items, L.PLOT_COUNT * L.SLOT_COUNT_MVP, wp, static + items + wp))
end
