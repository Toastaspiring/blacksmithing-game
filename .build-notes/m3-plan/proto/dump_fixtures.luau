--!nocheck
-- M3 plan: the prototype's fixtures (docs/spec/prototypes/S2/v2/fixtures.luau) as literal PartData, ready to paste into
-- tests/fixtures (Build.part rows), with the bits this machine's Lune computes for every trigonometric value. For each
-- fixture: parts, the smallest side, the margin to the Sword hitbox, the prototype's verdict, and whether any number came
-- from trigonometry (then the literal must be pasted, never recomputed in a fixture module).
local Analyze = require("./analyze")
local Fx = require("./fixtures")
local Shapes = require("./shapes")
local fmt = string.format

-- the shortest decimal that reads back to the same double
local function num(x)
	if x == 0 then
		return "0"
	end
	for digits = 1, 17 do
		local s = fmt("%." .. digits .. "g", x)
		if tonumber(s) == x then
			return s
		end
	end
	return fmt("%.17g", x)
end
local function vec(v)
	local t = {}
	for i = 1, #v do
		table.insert(t, num(v[i]))
	end
	return "{ " .. table.concat(t, ", ") .. " }"
end

local NAMED = {
	["0,0,0,1"] = "I",
	["0,0,0.38268343236508978,0.92387953251128674"] = "Z45",
	["0,0,0.70710678118654757,0.70710678118654757"] = "Z90",
	["0,0.70710678118654757,0,0.70710678118654757"] = "Y90",
}
local function rot(q)
	local key = table.concat({ fmt("%.17g", q[1]):gsub("^%-?0$", "0"), fmt("%.17g", q[2]), fmt("%.17g", q[3]), fmt("%.17g", q[4]) }, ",")
	key = string.gsub(key, "^0,", "0,")
	local k2 = fmt("%s,%s,%s,%s", num(q[1]), num(q[2]), num(q[3]), num(q[4]))
	for nk, name in pairs(NAMED) do
		local a = {}
		for s in string.gmatch(nk, "[^,]+") do
			table.insert(a, tonumber(s))
		end
		if a[1] == q[1] and a[2] == q[2] and a[3] == q[3] and a[4] == q[4] then
			return name
		end
	end
	return vec(q)
end

local function margin(b)
	local m, side = math.huge, math.huge
	for i, raw in ipairs(b.parts) do
		local p = Shapes.prepare(raw, i)
		m = math.min(m, p.minx + 0.8, 0.8 - p.maxx, p.miny - 0.0, 5.0 - p.maxy, p.minz + 0.3, 0.3 - p.maxz)
		side = math.min(side, raw.size[1], raw.size[2], raw.size[3])
	end
	return m, side
end

local function emit(id, b, note)
	local R = Analyze.run(b, { measureInvalid = true })
	local cl = {}
	for _, c in ipairs(R.cleaned or {}) do
		table.insert(cl, c.reason .. "#" .. c.partId)
	end
	local m, side = margin(b)
	local named = true
	for _, p in ipairs(b.parts) do
		if rot(p.rot):sub(1, 1) == "{" then
			named = false
		end
	end
	print(fmt("-- %s %s: %d parts, min side %s, hitbox margin %s%s, prototype valid=%s cleaned[%s]%s%s", id, b.name, #b.parts, num(side),
		num(math.floor(m * 1e6 + 0.5) / 1e6), if m < 0.02 - 1e-12 then " (< 0.02)" else "", tostring(R.valid), table.concat(cl, ","),
		if named then "" else ", pasted rotations", note and (" -- " .. note) or ""))
	print(fmt('["%s"] = {', id))
	for _, p in ipairs(b.parts) do
		print(fmt('\tP(%d, "%s", "%s", "%s", %s, %s, %s), -- %s', p.id, p.slot, p.shape, p.material, vec(p.pos), rot(p.rot), vec(p.size), p.label or ""))
	end
	print("},")
end

print("-- calibration (Fx.calibration)")
for _, b in ipairs(Fx.calibration()) do
	local id = string.match(b.name, "^(C%d+)")
	if string.find(b.name, "Steel") and id == "C02" then
		id = "C02s"
	end
	emit(id, b)
end
print("-- adversarial A25-A27 and the A26 base (Fx.adversarial)")
for _, a in ipairs(Fx.adversarial()) do
	local id = string.match(a.fixture.name, "^(A%d+)")
	emit(id, a.fixture, fmt("bound %.2f on %s against %s", a.bound, a.steps, a.base.name))
	if a.base.name ~= "F1 ArmingSword" then
		emit(id .. "base", a.base)
	end
end
print("-- regression X01-X07 (Fx.regression): arithmetic only, so a fixture module may also build them from F5")
local seen = {}
for _, r in ipairs(Fx.regression()) do
	emit(r.id, r.fixture, fmt("kind %s, bound %s, base %s", r.kind, num(r.bound), r.base.name))
	if r.base.name ~= "F5 StarterSword" and not seen[r.base.name] then
		seen[r.base.name] = true
		emit(r.id .. "base", r.base, "the union-equivalent base")
	end
end
print("-- cost P1-P5 (Fx.perf)")
for _, b in ipairs(Fx.perf()) do
	emit(string.match(b.name, "^(P%d)"), b)
end
