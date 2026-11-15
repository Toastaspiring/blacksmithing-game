--!nocheck
-- m2x-fix-5: random cap circles against a Cylinder's axis at tilts from 0 to 90° (and 1e-12 … 1e-3 off parallel), each
-- candidate's reading, for rim_acc.py's truth at 50 digits.
--   lune run rim_acc -- <seed> <count> <out.tsv> [small: tilts 1e-15 … 3e-6; p10 then takes the cutoff 1e-12]
local process = require("@lune/process")
local fs = require("@lune/fs")
local REPO = "C:/Users/louis/Documents/RANDOM/ROBLOX/Blacksmithing Game"
local TestRng = (require :: any)(REPO .. "/tests/lib/TestRng")
local Quat = (require :: any)(REPO .. "/src/shared/Blueprint/Quat")
local R = require("./rim")
local fmt = string.format
local rng = TestRng.new(tonumber(process.args[1]) or 1)
local COUNT = tonumber(process.args[2]) or 2000
local out = process.args[3] or "out/rim_acc.tsv"
local sqrt = math.sqrt

local TILTS = if process.args[4] == "small" then { 1e-15, 1e-14, 1e-13, 1e-12, 3e-12, 1e-11, 3e-11, 1e-10, 3e-10, 1e-9, 3e-9, 1e-8, 3e-8, 1e-7,
	3e-7, 1e-6, 3e-6 } else { 0, 1e-12, 1e-10, 1e-9, 3e-9, 1e-8, 3e-8, 1e-7, 3e-7, 9.9e-7, 1.01e-6, 3e-6, 1e-5, 1e-4, 1e-3, 0.01, 0.1, -1,
	-1, -1, -1, -2 }

local function unit(x, y, z)
	local l = sqrt(x * x + y * y + z * z)
	return x / l, y / l, z / l
end

local lines = {}
for k = 1, COUNT do
	local ux, uy, uz = unit(rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1))
	-- a direction square to u
	local tx, ty, tz = unit(rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1))
	local d = tx * ux + ty * uy + tz * uz
	tx, ty, tz = unit(tx - d * ux, ty - d * uy, tz - d * uz)
	local tilt = rng:pick(TILTS)
	local th = if tilt == -1 then rng:range(0, math.pi / 2) elseif tilt == -2 then math.pi / 2 else tilt
	local nx, ny, nz = unit(math.cos(th) * ux + math.sin(th) * tx, math.cos(th) * uy + math.sin(th) * ty, math.cos(th) * uz + math.sin(th) * tz)
	-- P's frame: local X onto n, spun at random, through Quat as Shapes.prepare does
	local axx, axy, axz = 0, -nz, ny
	local s = sqrt(axy * axy + axz * axz)
	local q
	if s < 1e-15 then
		q = if nx > 0 then { 0, 0, 0, 1 } else { 0, 0, 1, 0 }
	else
		local h = math.atan2(s, nx) / 2
		q = { axx / s * math.sin(h), axy / s * math.sin(h), axz / s * math.sin(h), math.cos(h) }
	end
	local spin = rng:range(0, math.pi)
	q = Quat.normalize(Quat.mul(q, { math.sin(spin), 0, 0, math.cos(spin) }))
	local Ux, Vx, Wx, Uy, Vy, Wy, Uz, Vz, Wz = Quat.toMatrix(q)
	local r = rng:range(0.01, 0.8)
	-- the centre's offset: across the axis 0 … 1.2 (or near r), along it −2 … 2
	local across = rng:pick({ rng:range(0, 1.2), rng:range(0, 1e-6), rng:range(0.5, 0.9), 0 })
	local along = rng:range(-2, 2)
	local bx, by, bz = unit(rng:normal(0, 1), rng:normal(0, 1), rng:normal(0, 1))
	local dd = bx * ux + by * uy + bz * uz
	bx, by, bz = unit(bx - dd * ux, by - dd * uy, bz - dd * uz)
	local dx, dy, dz = across * bx + along * ux, across * by + along * uy, across * bz + along * uz
	-- the offset across the axis by its parts
	local du = dx * ux + dy * uy + dz * uz
	local mx, my, mz = dx - du * ux, dy - du * uy, dz - du * uz
	local v1 = R.v1(dx, dy, dz, r, Ux, Uy, Uz, ux, uy, uz)
	local s6 = R.search(mx, my, mz, r, Ux, Uy, Uz, ux, uy, uz, 1e-6)
	local s8 = R.search(mx, my, mz, r, Ux, Uy, Uz, ux, uy, uz, 1e-8)
	local p8 = R.searchPt(mx, my, mz, r, Ux, Uy, Uz, ux, uy, uz, 1e-8)
	local p10 = R.searchPt(mx, my, mz, r, Ux, Uy, Uz, ux, uy, uz, if process.args[4] == "small" then 1e-12 else 1e-10)
	local above, below = R.bounds(mx, my, mz, r, Vx, Vy, Vz, Wx, Wy, Wz, ux, uy, uz)
	local vals = { dx, dy, dz, r, Ux, Uy, Uz, ux, uy, uz, v1, s6, s8, p8, p10, above, below, R.old(mx, my, mz, r), R.rms(mx, my, mz, r) }
	local row = { tostring(k), fmt("%.17g", th) }
	for _, x in ipairs(vals) do
		table.insert(row, fmt("%.17g", x))
	end
	table.insert(lines, table.concat(row, "\t"))
end
fs.writeFile(out, table.concat(lines, "\n") .. "\n")
print(fmt("%d circles to %s", COUNT, out))
