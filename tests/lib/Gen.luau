--!strict
-- tests/lib/Gen.luau — generators for property and fuzz tests (SPEC §14.2, §14.5, E-S8.5):
--   validSword(rng, ctx)               a random sword that is valid by construction: canonical, every slot within
--                                      its rule, inside the hitbox, parts stacked flush along +Y (pommel, grip,
--                                      guard, blade), no Dust, nothing enclosed (T-VAL-04, T-DIF-10, S-PAR-02)
--   garbage(rng, ctx)                  an untrusted value for P-TOTAL: scalars, buffers, junk tables, and valid
--                                      swords with one to three faults planted at any depth
--   withFiller(rng, ctx, core, kind?)  core + filler within the slot maxima: Dust specks flush on a part, Enclosed
--                                      parts buried in one, exact Duplicates (T-DIF-04)
--   segmented(rng, ctx, core)          core with Blade blocks re-cut flush along their length (T-DIF-07)
--   translated(rng, ctx, core)         core moved in Y and Z inside the hitbox; X never moves (T-DIF-07)
-- Requires nothing in src/ (SPEC §1.3 L1): a spec builds the Context from Definitions with Gen.context and passes it
-- in. Pure Luau with exact arithmetic (+ − × ÷, sqrt; no trigonometry) and TestRng only, so a seed builds the same
-- bits in Lune and in Studio, where S-PAR-02 digests 200 validSword designs. The geometry helpers (exact AABBs,
-- volumes, centroids, vertices: SPEC §3.2, §3.4, §4.2) are exported for the specs, an implementation independent of
-- Physics/Shapes.

local TestRng = require("./TestRng")

type Rng = TestRng.TestRng

export type Vec = { number }
export type Part = { id: number, slot: string, shape: string, material: string, pos: Vec, rot: Vec, size: Vec }
export type Core = { schema: number, name: string, type: string, parts: { Part } }
export type SlotRule = { id: string, min: number, max: number }
export type Context = {
	schema: number, -- Versions.BLUEPRINT_SCHEMA
	typeId: string, -- the equipment type (validSword needs the Sword's four slots)
	hitboxMin: Vec,
	hitboxMax: Vec,
	slots: { SlotRule },
	materials: { string }, -- enabled material ids
	minDim: number,
	maxDim: number,
	posAbsMax: number,
	maxParts: number,
	maxPartId: number,
	dustVolume: number, -- Balance.Geometry.MIN_PART_VOLUME: below it a part is Dust
}
export type FillerKind = "Dust" | "Enclosed" | "Duplicate"

local Gen = {}

-- Definitions/Types' ShapeId values; shapes have no catalog (Blueprint/Canonical keeps the same list).
Gen.SHAPES = table.freeze({ "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" })
Gen.PI = 3.141592653589793 -- SPEC §4.1's literal
Gen.MARGIN = 0.03 -- validSword keeps every part this far inside the hitbox walls

local R = 0.70710678118654757 -- √½
local IDENTITY: Vec = { 0, 0, 0, 1 }
local Z90: Vec = { 0, 0, R, R } -- a cylinder's axis (local X) along +Y
local Y90: Vec = { 0, R, 0, R } -- local X → −Z, local Z → +X
local Z45: Vec = { 0, 0, 0.38268343236508978, 0.92387953251128674 }

-- ── context ───────────────────────────────────────────────────────────────────────────────────────────────────

local function need(t: any, key: string, kind: string): any
	local v = if type(t) == "table" then t[key] else nil
	if type(v) ~= kind then
		error(string.format("Gen.context: expected %s %s, got %s", kind, key, type(v)), 3)
	end
	return v
end

-- From Definitions: Limits, the EquipmentTypes row, the enabled Materials rows (or ids), the blueprint schema and
-- Balance.Geometry (for the Dust floor).
function Gen.context(limits: any, typeDef: any, materials: { any }, schema: number, geometry: any): Context
	local geo = need(typeDef, "geometry", "table")
	local slots: { SlotRule } = {}
	for _, s in need(typeDef, "slots", "table") :: { any } do
		table.insert(slots, { id = need(s, "id", "string"), min = need(s, "min", "number"), max = need(s, "max", "number") })
	end
	local ids: { string } = {}
	for _, m in materials do
		table.insert(ids, if type(m) == "string" then m else need(m, "id", "string"))
	end
	assert(#ids > 0, "Gen.context: no enabled material")
	local lo, hi = need(geo, "hitboxMin", "table"), need(geo, "hitboxMax", "table")
	return table.freeze({
		schema = schema,
		typeId = need(typeDef, "id", "string"),
		hitboxMin = table.freeze({ lo[1], lo[2], lo[3] }),
		hitboxMax = table.freeze({ hi[1], hi[2], hi[3] }),
		slots = table.freeze(slots),
		materials = table.freeze(ids),
		minDim = need(limits, "MIN_DIM", "number"),
		maxDim = need(limits, "MAX_DIM", "number"),
		posAbsMax = need(limits, "POS_ABS_MAX", "number"),
		maxParts = need(limits, "MAX_PARTS", "number"),
		maxPartId = need(limits, "MAX_PART_ID", "number"),
		dustVolume = need(geometry, "MIN_PART_VOLUME", "number"),
	}) :: Context
end

local function slotMax(ctx: Context, id: string): number
	for _, s in ctx.slots do
		if s.id == id then
			return s.max
		end
	end
	return 0
end

-- ── geometry (exact) ──────────────────────────────────────────────────────────────────────────────────────────

-- SPEC §3.4: rows R00..R22 of R(q), exact for any non-zero q, no square root; columns = local X, Y, Z.
function Gen.matrix(q: Vec): { number }
	local x, y, z, w = q[1], q[2], q[3], q[4]
	local s = 2 / (x * x + y * y + z * z + w * w)
	return {
		1 - s * (y * y + z * z), s * (x * y - z * w), s * (x * z + y * w),
		s * (x * y + z * w), 1 - s * (x * x + z * z), s * (y * z - x * w),
		s * (x * z - y * w), s * (y * z + x * w), 1 - s * (x * x + y * y),
	}
end

local function apply(m: { number }, v: Vec): Vec
	return {
		m[1] * v[1] + m[2] * v[2] + m[3] * v[3],
		m[4] * v[1] + m[5] * v[2] + m[6] * v[3],
		m[7] * v[1] + m[8] * v[2] + m[9] * v[3],
	}
end

-- Hamilton product a ⊗ b: rotate by b, then by a.
function Gen.mul(a: Vec, b: Vec): Vec
	local ax, ay, az, aw = a[1], a[2], a[3], a[4]
	local bx, by, bz, bw = b[1], b[2], b[3], b[4]
	return {
		aw * bx + ax * bw + ay * bz - az * by,
		aw * by - ax * bz + ay * bw + az * bx,
		aw * bz + ax * by - ay * bx + az * bw,
		aw * bw - ax * bx - ay * by - az * bz,
	}
end

-- SPEC §3.5 C4 + C5: the canonical sign of q, then −0 → +0.
function Gen.hemisphere(q: Vec): Vec
	local x, y, z, w = q[1], q[2], q[3], q[4]
	local flip: boolean
	if w ~= 0 then
		flip = w < 0
	elseif x ~= 0 then
		flip = x < 0
	elseif y ~= 0 then
		flip = y < 0
	else
		flip = z < 0
	end
	if flip then
		x, y, z, w = -x, -y, -z, -w
	end
	return { x + 0, y + 0, z + 0, w + 0 }
end

-- Local vertices of a polyhedron (SPEC §3.2), nil for Cylinder and Ball.
function Gen.localVertices(shape: string, size: Vec): { Vec }?
	local hx, hy, hz = size[1] / 2, size[2] / 2, size[3] / 2
	if shape == "Block" then
		local out: { Vec } = {}
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					table.insert(out, { sx * hx, sy * hy, sz * hz })
				end
			end
		end
		return out
	elseif shape == "Wedge" then -- c ≥ b: the full −Y and +Z faces
		return { { -hx, -hy, -hz }, { hx, -hy, -hz }, { -hx, -hy, hz }, { hx, -hy, hz }, { -hx, hy, hz }, { hx, hy, hz } }
	elseif shape == "CornerWedge" then -- b ≤ a, b ≤ −c: the apex over (+hx, −hz)
		return { { -hx, -hy, -hz }, { hx, -hy, -hz }, { -hx, -hy, hz }, { hx, -hy, hz }, { hx, hy, -hz } }
	end
	return nil
end

-- World vertices of a polyhedron part, nil for Cylinder and Ball.
function Gen.vertices(p: Part): { Vec }?
	local local_ = Gen.localVertices(p.shape, p.size)
	if local_ == nil then
		return nil
	end
	local m = Gen.matrix(p.rot)
	local out: { Vec } = {}
	for _, v in local_ do
		local w = apply(m, v)
		table.insert(out, { p.pos[1] + w[1], p.pos[2] + w[2], p.pos[3] + w[3] })
	end
	return out
end

-- The exact world AABB (SPEC §4.2): polyhedra by their vertices; a cylinder with axis u extends
-- hx·|u_k| + r·sqrt(max(0, 1 − u_k²)) per axis; a ball c ± r.
function Gen.aabb(p: Part): (Vec, Vec)
	local lo: Vec = { math.huge, math.huge, math.huge }
	local hi: Vec = { -math.huge, -math.huge, -math.huge }
	local verts = Gen.vertices(p)
	if verts then
		for _, v in verts do
			for k = 1, 3 do
				lo[k] = math.min(lo[k], v[k])
				hi[k] = math.max(hi[k], v[k])
			end
		end
	elseif p.shape == "Ball" then
		local r = math.min(p.size[1], p.size[2], p.size[3]) / 2
		for k = 1, 3 do
			lo[k], hi[k] = p.pos[k] - r, p.pos[k] + r
		end
	else -- Cylinder: axis = local X = column 1 of R
		local m = Gen.matrix(p.rot)
		local hx, r = p.size[1] / 2, math.min(p.size[2], p.size[3]) / 2
		for k = 1, 3 do
			local u = m[(k - 1) * 3 + 1]
			local e = hx * math.abs(u) + r * math.sqrt(math.max(0, 1 - u * u))
			lo[k], hi[k] = p.pos[k] - e, p.pos[k] + e
		end
	end
	return lo, hi
end

-- The AABB of all parts ({huge…}, {−huge…} for no parts).
function Gen.bounds(parts: { Part }): (Vec, Vec)
	local lo: Vec = { math.huge, math.huge, math.huge }
	local hi: Vec = { -math.huge, -math.huge, -math.huge }
	for _, p in parts do
		local a, b = Gen.aabb(p)
		for k = 1, 3 do
			lo[k] = math.min(lo[k], a[k])
			hi[k] = math.max(hi[k], b[k])
		end
	end
	return lo, hi
end

-- Analytic volume (SPEC §3.2).
function Gen.volume(p: Part): number
	local hx, hy, hz = p.size[1] / 2, p.size[2] / 2, p.size[3] / 2
	if p.shape == "Block" then
		return 8 * hx * hy * hz
	elseif p.shape == "Wedge" then
		return 4 * hx * hy * hz
	elseif p.shape == "CornerWedge" then
		return 8 * hx * hy * hz / 3
	elseif p.shape == "Cylinder" then
		local r = math.min(hy, hz)
		return 2 * Gen.PI * r * r * hx
	end
	local r = math.min(hx, hy, hz)
	return 4 * Gen.PI * r * r * r / 3
end

-- World centroid (SPEC §3.2's local centroids, rotated).
function Gen.centroid(p: Part): Vec
	local hx, hy, hz = p.size[1] / 2, p.size[2] / 2, p.size[3] / 2
	local c: Vec = { 0, 0, 0 }
	if p.shape == "Wedge" then
		c = { 0, -hy / 3, hz / 3 }
	elseif p.shape == "CornerWedge" then
		c = { hx / 4, -hy / 2, -hz / 4 }
	end
	local w = apply(Gen.matrix(p.rot), c)
	return { p.pos[1] + w[1], p.pos[2] + w[2], p.pos[3] + w[3] }
end

-- Smallest distance from any part's AABB to the hitbox walls (negative when a part is out).
function Gen.margin(ctx: Context, parts: { Part }): number
	local m = math.huge
	for _, p in parts do
		local lo, hi = Gen.aabb(p)
		for k = 1, 3 do
			m = math.min(m, lo[k] - ctx.hitboxMin[k], ctx.hitboxMax[k] - hi[k])
		end
	end
	return m
end

-- ── copies ────────────────────────────────────────────────────────────────────────────────────────────────────

function Gen.copyPart(p: Part): Part
	return {
		id = p.id,
		slot = p.slot,
		shape = p.shape,
		material = p.material,
		pos = { p.pos[1], p.pos[2], p.pos[3] },
		rot = { p.rot[1], p.rot[2], p.rot[3], p.rot[4] },
		size = { p.size[1], p.size[2], p.size[3] },
	}
end

-- A fresh core: the known fields only, every table new.
function Gen.copy(core: Core): Core
	local parts: { Part } = {}
	for _, p in core.parts do
		table.insert(parts, Gen.copyPart(p))
	end
	return { schema = core.schema, name = core.name, type = core.type, parts = parts }
end

local function sortById(parts: { Part })
	table.sort(parts, function(a: Part, b: Part): boolean
		return a.id < b.id
	end)
end

local function maxId(parts: { Part }): number
	local m = 0
	for _, p in parts do
		m = math.max(m, p.id)
	end
	return m
end

local function countSlot(parts: { Part }, slot: string): number
	local n = 0
	for _, p in parts do
		if p.slot == slot then
			n += 1
		end
	end
	return n
end

-- ── validSword ────────────────────────────────────────────────────────────────────────────────────────────────

-- A unit quaternion for a rotation about +Y by a random angle (exact: a normalized random direction, no trig).
local function aboutY(rng: Rng): Vec
	while true do
		local a, b = rng:range(-1, 1), rng:range(-1, 1)
		local n = math.sqrt(a * a + b * b)
		if n > 0.25 and n <= 1 then
			return Gen.hemisphere({ 0, a / n, 0, b / n })
		end
	end
end

local NAME_WORDS = { "Blade", "Sword", "Edge", "Fang", "Oath", "Ember", "Épée", "Lame", "Ash", "Iron", "Dawn", "Øre" }
local NAME_MARKS = { "", "", "", " II", "-7", " (mk 2)", "'s", " #3", ": the", " & co", "!" }

local function swordName(rng: Rng): string
	local words: { string } = {}
	for _ = 1, rng:int(1, 3) do
		table.insert(words, rng:pick(NAME_WORDS))
	end
	return table.concat(words, " ") .. rng:pick(NAME_MARKS) .. (if rng:float() < 0.3 then " " .. tostring(rng:int(1, 99)) else "")
end

-- Places a part with its bottom on y = base (AABB-exact), centred on x = cx, z = 0. Returns the part and its top y.
-- The part gets its own copies of rot and size: parts never share a table.
local function stack(slot: string, shape: string, material: string, base: number, cx: number, rot: Vec, size: Vec): (Part, number)
	local p: Part = { id = 0, slot = slot, shape = shape, material = material, pos = { cx, 0, 0 },
		rot = { rot[1], rot[2], rot[3], rot[4] }, size = { size[1], size[2], size[3] } }
	local lo, hi = Gen.aabb(p)
	p.pos[2] = base - lo[2]
	return p, base + (hi[2] - lo[2])
end

-- One attempt; nil when the random sizes do not fit (the caller retries on a forked stream).
local function trySword(rng: Rng, ctx: Context): Core?
	local m = Gen.MARGIN
	local halfW = math.min(-ctx.hitboxMin[1], ctx.hitboxMax[1]) - m
	local halfT = math.min(-ctx.hitboxMin[3], ctx.hitboxMax[3]) - m
	local top = ctx.hitboxMax[2] - m
	local thin = math.max(ctx.minDim, 0.03)
	local minVolume = 2 * ctx.dustVolume -- every part at least twice the Dust floor
	local function mat(): string
		return rng:pick(ctx.materials)
	end
	local parts: { Part } = {}
	local y = ctx.hitboxMin[2] + m + rng:range(0, 0.05)

	-- pommel: 0..2 parts, Ball, Block or a Cylinder lying along X or Z
	for _ = 1, rng:int(0, math.min(2, slotMax(ctx, "Pommel"))) do
		local kind = rng:int(1, 4)
		local p: Part
		if kind == 1 then
			local d = rng:range(0.16, 0.34)
			p, y = stack("Pommel", "Ball", mat(), y, 0, IDENTITY, { d, d, d })
		elseif kind == 2 then
			p, y = stack("Pommel", "Block", mat(), y, 0, if rng:float() < 0.5 then IDENTITY else aboutY(rng),
				{ rng:range(0.14, 0.32), rng:range(0.10, 0.30), rng:range(0.14, 0.32) })
		else
			local d = rng:range(0.14, 0.30)
			p, y = stack("Pommel", "Cylinder", mat(), y, 0, if kind == 3 then IDENTITY else Y90,
				{ rng:range(0.10, 0.36), d, d })
		end
		table.insert(parts, p)
	end

	-- grip: 1..2 parts stacked, long along Y (a Block at least 1.5× taller than wide, or a Cylinder along +Y)
	local gripTop = y
	for _ = 1, rng:int(1, math.min(2, slotMax(ctx, "Grip"))) do
		local w = rng:range(0.12, 0.22)
		local h = rng:range(0.36, 0.60)
		local p: Part
		if rng:float() < 0.5 then
			p, y = stack("Grip", "Block", mat(), y, 0, if rng:float() < 0.5 then IDENTITY else aboutY(rng),
				{ w, h, rng:range(0.12, 0.22) })
		else
			p, y = stack("Grip", "Cylinder", mat(), y, 0, Z90, { h, w, w })
		end
		table.insert(parts, p)
		gripTop = y
	end

	-- guard: 0..3 parts: a cross bar, then a pair of end pieces (quillon balls centred on its ends, or CornerWedge
	-- finials standing on its top face, the −X one turned 180° about Y), or a second, narrower bar on top
	local supportHalf = 0.06 -- half the width the blade may rest on
	local nGuard = rng:int(0, math.min(3, slotMax(ctx, "Guard")))
	if nGuard > 0 then
		local width = rng:range(0.40, 2 * halfW - 0.2)
		local height = rng:range(0.08, 0.20)
		local depth = rng:range(0.10, math.min(0.28, 2 * halfT))
		local bar, barTop = stack("Guard", "Block", mat(), y, 0, IDENTITY, { width, height, depth })
		table.insert(parts, bar)
		supportHalf = width / 2
		local extra = nGuard - 1
		if extra >= 2 and rng:float() < 0.4 then
			local d = math.min(rng:range(0.10, 0.16), 2 * (halfW - width / 2))
			if Gen.PI * d * d * d / 6 >= minVolume then
				for _, sx in { -1, 1 } do
					table.insert(parts, { id = 0, slot = "Guard", shape = "Ball", material = mat(),
						pos = { sx * width / 2, bar.pos[2], 0 }, rot = table.clone(IDENTITY), size = { d, d, d } })
				end
				extra -= 2
			end
		elseif extra >= 2 and rng:float() < 0.6 then
			local size = { rng:range(0.12, 0.20), rng:range(0.12, 0.20), rng:range(0.10, depth) }
			for _, sx in { -1, 1 } do
				local fin = (stack("Guard", "CornerWedge", mat(), barTop, sx * (width - size[1]) / 2,
					if sx > 0 then IDENTITY else { 0, 1, 0, 0 }, size))
				table.insert(parts, fin)
			end
			extra -= 2
		end
		y = barTop
		if extra >= 1 then
			local w2 = rng:range(0.2, 1) * width
			local p
			p, y = stack("Guard", "Block", mat(), y, 0, IDENTITY, { math.max(w2, 0.1), rng:range(0.05, 0.10), depth })
			table.insert(parts, p)
			supportHalf = math.max(w2, 0.1) / 2
		end
	else
		supportHalf = 0.06
	end

	-- blade: a main block on the support, then up to 2 narrower stacked segments, then a tip
	local nBlade = rng:int(1, math.min(4, slotMax(ctx, "Blade")))
	local width = rng:range(0.06, math.min(0.40, 2 * halfW))
	local thick = rng:range(thin, math.min(0.12, 2 * halfT))
	local reserve = (nBlade - 1) * 0.45 -- room for the segments and the tip, each at most 0.45 tall
	local length = rng:range(1.0, math.max(1.0, math.min(3.2, top - y - reserve)))
	local offset = 0
	if rng:float() < 0.3 then
		local room = math.min(supportHalf, halfW - width / 2)
		offset = rng:range(-room, room) * 0.5
	end
	local main, mainTop = stack("Blade", "Block", mat(), y, offset, if rng:float() < 0.2 then aboutY(rng) else IDENTITY,
		{ width, length, thick })
	table.insert(parts, main)
	y = mainTop
	local left = nBlade - 1
	while left > 1 do
		local w2 = math.max(width * rng:range(0.6, 0.95), thin)
		local h2 = rng:range(0.15, 0.45)
		if w2 * h2 * thick < minVolume then
			break -- a narrower segment would be Dust
		end
		local seg
		seg, y = stack("Blade", "Block", main.material, y, offset, IDENTITY, { w2, h2, thick })
		table.insert(parts, seg)
		width = w2
		left -= 1
	end
	if left >= 1 then
		local tip: Part
		if rng:float() < 0.5 then -- single-edged wedge (F3, F4): full −Y face on the blade, local Z = world +X
			tip = (stack("Blade", "Wedge", main.material, y, offset, Y90, { thick, rng:range(0.15, 0.45), width }))
		else -- a square turned 45° about Z, its centre on the blade's top (F1)
			local s = math.max(math.min(width, rng:range(0.06, 0.2)) * 0.75, thin)
			tip = { id = 0, slot = "Blade", shape = "Block", material = main.material, pos = { offset, y, 0 },
				rot = table.clone(Z45), size = { s, s, math.max(thick * 0.9, thin) } }
		end
		if Gen.volume(tip) >= minVolume then
			table.insert(parts, tip)
		end
	end
	if gripTop >= y then
		return nil
	end

	-- every part: inside with the margin, sizes in range, well above the Dust floor
	for _, p in parts do
		local lo, hi = Gen.aabb(p)
		for k = 1, 3 do
			if lo[k] < ctx.hitboxMin[k] + m - 1e-9 or hi[k] > ctx.hitboxMax[k] - m + 1e-9 then
				return nil
			end
			if p.size[k] < ctx.minDim or p.size[k] > ctx.maxDim then
				return nil
			end
		end
		if Gen.volume(p) < minVolume then
			return nil
		end
	end
	if #parts > ctx.maxParts then
		return nil
	end

	-- ids: a random order with gaps, then canonical (ascending) order; −0 → +0 everywhere
	for i = #parts, 2, -1 do
		local j = rng:int(1, i)
		parts[i], parts[j] = parts[j], parts[i]
	end
	local id = rng:int(1, 40)
	for _, p in parts do
		p.id = id
		id += rng:int(1, 3)
		p.pos = { p.pos[1] + 0, p.pos[2] + 0, p.pos[3] + 0 }
		p.rot = Gen.hemisphere(p.rot)
	end
	if maxId(parts) > ctx.maxPartId then
		return nil
	end
	sortById(parts)
	return { schema = ctx.schema, name = swordName(rng), type = ctx.typeId, parts = parts }
end

function Gen.validSword(rng: Rng, ctx: Context): Core
	assert(ctx.typeId == "Sword", "Gen.validSword: builds the Sword's slots, got type " .. tostring(ctx.typeId))
	for attempt = 1, 64 do
		local core = trySword(rng:fork(attempt), ctx)
		if core then
			return core
		end
	end
	error("Gen.validSword: no fit in 64 attempts (a Gen bug, or a hitbox far smaller than the Sword's)")
end

-- ── garbage ───────────────────────────────────────────────────────────────────────────────────────────────────

local SPECIAL_NUMBERS = {
	0, -0, 1, -1, 0.5, -0.5, 2, 1.5, 16, -16, 16.000001, 0.02, 0.019999, 6, 6.000001, 65535, 65536, 1e308, -1e308,
	1e-300, 5e-324, 9007199254740992, 1e20, -1e20, 0 / 0, math.huge, -math.huge,
}
local SPECIAL_STRINGS = {
	"", " ", "Sword", "Blade", "Grip", "Guard", "Pommel", "Iron", "Steel", "Bronze", "Block", "Ball", "Cylinder",
	"Sphere", "Hilt", "Axe", "1", "nil", "NaN", "\0", "a\nb", "\t", "<b>x</b>", "\255\254", "\192\128", "é", "×",
	string.rep("W", 300),
}

local function scalar(rng: Rng): any
	local r = rng:int(1, 9)
	if r == 1 then
		return nil
	elseif r == 2 then
		return rng:float() < 0.5
	elseif r <= 4 then
		return rng:pick(SPECIAL_NUMBERS)
	elseif r == 5 then
		return rng:range(-100, 100)
	elseif r == 6 then
		return rng:int(-5, 70000)
	elseif r <= 8 then
		return rng:pick(SPECIAL_STRINGS)
	end
	local bytes: { string } = {}
	for _ = 1, rng:int(0, 24) do
		table.insert(bytes, string.char(rng:int(0, 255)))
	end
	return table.concat(bytes)
end

local function junk(rng: Rng, depth: number): any
	local r = rng:int(1, 10)
	if depth <= 0 or r <= 5 then
		return scalar(rng)
	elseif r == 6 then
		return buffer.create(rng:int(0, 32))
	end
	local t: { [any]: any } = {}
	local n = rng:int(0, 6)
	if r <= 8 then -- an array
		for i = 1, n do
			t[i] = junk(rng, depth - 1)
		end
	else -- a map with mixed keys
		for _ = 1, n do
			local key: any = if rng:float() < 0.6 then rng:pick(SPECIAL_STRINGS) else rng:int(-3, 30)
			if key ~= nil and key == key then
				t[key] = junk(rng, depth - 1)
			end
		end
	end
	return t
end

local PART_FIELDS = { "id", "slot", "shape", "material", "pos", "rot", "size" }
local VECTOR_FIELDS = { "pos", "rot", "size" }
local TOP_FIELDS = { "schema", "name", "type", "parts" }
local ID_FIELDS = { "slot", "shape", "material" }
-- plausible but wrong ids: unknown, disabled (Bronze, Mithril), another type's slot, wrong case
local WRONG_IDS = { "Bronze", "Mithril", "Wood", "Adamant", "Sphere", "Hilt", "Head", "Axe", "blade", "iron", "BLOCK", "" }

-- One fault planted in a draft (a table built by Gen.copy, so it may be changed in place). Returns the new draft.
local function mutate(rng: Rng, ctx: Context, d: any): any
	local parts = d.parts
	local r = rng:int(1, 15)
	local p = if type(parts) == "table" and #parts > 0 then parts[rng:int(1, #parts)] else nil
	if r == 1 then
		d[rng:pick(TOP_FIELDS)] = junk(rng, 2)
	elseif r == 2 then
		d[rng:pick(TOP_FIELDS)] = nil
	elseif r <= 4 and type(p) == "table" then
		p[rng:pick(PART_FIELDS)] = junk(rng, 2)
	elseif r == 5 and type(p) == "table" then
		p[rng:pick(PART_FIELDS)] = nil
	elseif r <= 7 and type(p) == "table" then
		local v = p[rng:pick(VECTOR_FIELDS)]
		if type(v) == "table" then
			local s = rng:int(1, 4)
			if s == 1 then
				table.insert(v, scalar(rng))
			elseif s == 2 and #v > 0 then
				table.remove(v)
			else
				v[rng:int(1, math.max(1, #v))] = if rng:float() < 0.7 then rng:pick(SPECIAL_NUMBERS) else junk(rng, 1)
			end
		end
	elseif r == 8 and type(p) == "table" and type(p.rot) == "table" then
		local f = rng:pick({ 0, 1e-20, -1, 2, 1.001, 1.02, 0.97 })
		local q = p.rot
		local scaled: { any } = {}
		for k = 1, 4 do
			local x = q[k]
			scaled[k] = if type(x) == "number" then x * f else x -- an earlier fault may have left a non-number
		end
		p.rot = scaled
	elseif r == 9 and type(parts) == "table" then
		local map: { [string]: any } = {}
		for i, x in parts do
			map["p" .. tostring(i)] = x
		end
		d.parts = map
	elseif r == 10 and type(parts) == "table" and type(p) == "table" then
		table.insert(parts, rng:int(1, #parts + 1), if rng:float() < 0.5 then p else junk(rng, 1))
	elseif r == 11 and type(parts) == "table" and type(p) == "table" then
		for _ = 1, ctx.maxParts + rng:int(1, 8) - #parts do
			table.insert(parts, p)
		end
	elseif r == 12 then
		d[rng:pick(SPECIAL_STRINGS)] = junk(rng, 2) -- an unknown field (or a known one, by chance)
	elseif r == 13 and type(p) == "table" then
		p[rng:pick(ID_FIELDS)] = rng:pick(WRONG_IDS)
	elseif r == 14 then
		d.type = rng:pick(WRONG_IDS)
	elseif type(p) == "table" then
		p.id = rng:pick({ 0, -1, 1.5, ctx.maxPartId + 1, if type(parts) == "table" and type(parts[1]) == "table" then parts[1].id else 1 })
	end
	return d
end

function Gen.garbage(rng: Rng, ctx: Context): any
	local r = rng:int(1, 20)
	if r <= 3 then
		return scalar(rng)
	elseif r == 4 then
		return buffer.create(rng:int(0, 64))
	elseif r <= 7 then
		return junk(rng, 4)
	end
	local d: any = Gen.copy(Gen.validSword(rng, ctx))
	for _ = 1, rng:int(1, 3) do
		d = mutate(rng, ctx, d)
	end
	return d
end

-- ── transforms ────────────────────────────────────────────────────────────────────────────────────────────────

-- A cube of side s flush against part p, outside it, on one face (or, for a Ball, touching it at one point).
local function speck(rng: Rng, p: Part, s: number): (Vec, Vec)
	local h = s / 2
	if p.shape == "Ball" then
		local r = math.min(p.size[1], p.size[2], p.size[3]) / 2
		local axis = rng:int(1, 3)
		local sign = if rng:float() < 0.5 then -1 else 1
		local pos = { p.pos[1], p.pos[2], p.pos[3] }
		pos[axis] += sign * (r + h)
		return pos, { 0, 0, 0, 1 }
	end
	local offset: Vec = { 0, 0, 0 }
	if p.shape == "Block" then
		local axis = rng:int(1, 3)
		local sign = if rng:float() < 0.5 then -1 else 1
		offset[axis] = sign * (p.size[axis] / 2 + h)
	elseif p.shape == "Cylinder" then -- on a cap
		offset[1] = (if rng:float() < 0.5 then -1 else 1) * (p.size[1] / 2 + h)
	else -- Wedge, CornerWedge: their full −Y face
		offset[2] = -(p.size[2] / 2 + h)
	end
	local w = apply(Gen.matrix(p.rot), offset)
	return { p.pos[1] + w[1], p.pos[2] + w[2], p.pos[3] + w[3] }, { p.rot[1], p.rot[2], p.rot[3], p.rot[4] }
end

local FILLER_KINDS: { FillerKind } = { "Dust", "Enclosed", "Duplicate" }

local function inside(ctx: Context, p: Part): boolean
	local lo, hi = Gen.aabb(p)
	for k = 1, 3 do
		if lo[k] < ctx.hitboxMin[k] or hi[k] > ctx.hitboxMax[k] then
			return false
		end
	end
	return true
end

-- Adds 1..4 filler parts to a copy of core, each in its host's slot and within that slot's maximum and MAX_PARTS:
-- Dust (a cube below the Dust floor, flush on its host), Enclosed (a smaller copy of a Block, Ball or Cylinder
-- host, centred in it, at least 0.01 from its faces) or Duplicate (an exact copy). kind nil picks one per part.
-- Returns the new core and the ids added (none when nothing fits).
function Gen.withFiller(rng: Rng, ctx: Context, core: Core, kind: FillerKind?): (Core, { number })
	local out = Gen.copy(core)
	local added: { number } = {}
	local want = rng:int(1, 4)
	local nextId = maxId(out.parts)
	local hosts: { Part } = table.clone(out.parts)
	for _ = 1, 24 do
		if #added >= want or #out.parts >= ctx.maxParts or #hosts == 0 then
			break
		end
		local host = hosts[rng:int(1, #hosts)]
		local k: FillerKind = if kind then kind else FILLER_KINDS[rng:int(1, #FILLER_KINDS)]
		if countSlot(out.parts, host.slot) >= slotMax(ctx, host.slot) or nextId + 1 > ctx.maxPartId then
			continue
		end
		local filler: Part? = nil
		if k == "Duplicate" then
			filler = Gen.copyPart(host)
		elseif k == "Dust" then
			-- E-S8.4's speck, a 0.05 cube, when that is below the floor (0.000125 < 0.0002), else a MIN_DIM cube
			local side = if 0.05 * 0.05 * 0.05 < ctx.dustVolume then 0.05 else ctx.minDim
			local pos, rot = speck(rng, host, side)
			filler = { id = 0, slot = host.slot, shape = "Block", material = host.material, pos = pos, rot = rot,
				size = { side, side, side } }
		elseif host.shape == "Block" or host.shape == "Ball" or host.shape == "Cylinder" then
			local size: Vec = {}
			local fits = true
			for a = 1, 3 do
				local s = host.size[a] * rng:range(0.3, 0.7)
				s = math.min(s, host.size[a] - 0.02)
				if s < ctx.minDim then
					fits = false
				end
				size[a] = s
			end
			if fits then
				local f: Part = Gen.copyPart(host)
				if host.shape == "Ball" then
					local d = math.min(size[1], size[2], size[3])
					f.size = { d, d, d }
				elseif host.shape == "Cylinder" then
					local d = math.min(size[2], size[3])
					f.size = { size[1], d, d }
				else
					f.size = size
				end
				if Gen.volume(f) >= 2 * ctx.dustVolume then
					filler = f
				end
			end
		end
		if filler and inside(ctx, filler) then
			nextId += 1 + (if rng:float() < 0.3 then rng:int(1, 5) else 0)
			if nextId > ctx.maxPartId then
				break
			end
			filler.id = nextId
			filler.pos = { filler.pos[1] + 0, filler.pos[2] + 0, filler.pos[3] + 0 }
			filler.rot = Gen.hemisphere(filler.rot)
			table.insert(out.parts, filler)
			table.insert(added, nextId)
		end
	end
	sortById(out.parts)
	return out, added
end

-- Re-cuts up to 3 Blade Blocks of a copy of core into 2..4 flush pieces along their local Y (the first piece keeps
-- the id), within the Blade maximum and MAX_PARTS. The union is unchanged up to rounding. Returns the new core and
-- the ids of the parts that were cut.
function Gen.segmented(rng: Rng, ctx: Context, core: Core): (Core, { number })
	local out = Gen.copy(core)
	local cut: { number } = {}
	local nextId = maxId(out.parts)
	-- kept pieces stay kept: no piece shorter than MIN_DIM or below twice the Dust floor (Dust parts are left whole)
	local minVolume = 2 * ctx.dustVolume
	local candidates: { Part } = {}
	for _, p in out.parts do
		if p.slot == "Blade" and p.shape == "Block" and p.size[2] / 2 >= ctx.minDim and Gen.volume(p) >= 2 * minVolume then
			table.insert(candidates, p)
		end
	end
	for _ = 1, math.min(3, #candidates) do
		local idx = rng:int(1, #candidates)
		local p = table.remove(candidates, idx) :: Part
		local room = math.min(slotMax(ctx, "Blade") - countSlot(out.parts, "Blade"), ctx.maxParts - #out.parts)
		local n = math.min(rng:int(2, 4), room + 1, math.floor(p.size[2] / ctx.minDim),
			math.floor(Gen.volume(p) / minVolume))
		if n < 2 or nextId + n - 1 > ctx.maxPartId then
			continue
		end
		local m = Gen.matrix(p.rot)
		local length = p.size[2] / n
		local half = p.size[2] / 2
		local centre = { p.pos[1], p.pos[2], p.pos[3] }
		for i = 1, n do
			local along = -half + (i - 0.5) * length
			local w = apply(m, { 0, along, 0 })
			local piece = if i == 1 then p else Gen.copyPart(p)
			piece.pos = { centre[1] + w[1] + 0, centre[2] + w[2] + 0, centre[3] + w[3] + 0 }
			piece.size = { p.size[1], length, p.size[3] }
			if i > 1 then
				nextId += 1
				piece.id = nextId
				table.insert(out.parts, piece)
			end
		end
		table.insert(cut, p.id)
	end
	sortById(out.parts)
	return out, cut
end

-- core moved by (0, dy, dz): a fresh core.
function Gen.translate(core: Core, dy: number, dz: number): Core
	local out = Gen.copy(core)
	for _, p in out.parts do
		p.pos = { p.pos[1], p.pos[2] + dy + 0, p.pos[3] + dz + 0 }
	end
	return out
end

-- A copy of core moved by a random (0, dy, dz) that keeps every part inside the hitbox; X never moves (an X shift is
-- a real change to Asymmetry, SPEC §14.6 T-DIF-07). Returns the new core and the delta {0, dy, dz}.
function Gen.translated(rng: Rng, ctx: Context, core: Core): (Core, Vec)
	if #core.parts == 0 then
		return Gen.copy(core), { 0, 0, 0 }
	end
	local lo, hi = Gen.bounds(core.parts)
	local safety = 1e-9
	local function pick(k: number): number
		local down = ctx.hitboxMin[k] - lo[k] + safety -- ≤ 0 when the design is inside
		local up = ctx.hitboxMax[k] - hi[k] - safety
		if down >= up then
			return 0
		end
		return rng:range(down, up)
	end
	local dy, dz = pick(2), pick(3)
	return Gen.translate(core, dy, dz), { 0, dy, dz }
end

return table.freeze(Gen)
