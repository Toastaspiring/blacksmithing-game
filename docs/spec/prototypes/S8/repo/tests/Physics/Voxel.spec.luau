--!strict
-- Sample property tests against the prototype voxelizer (stand-in for S2's module).
local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Prop = require("../lib/Prop")
local Fixtures = require("../fixtures/Blueprints")
local P = require("../../src/shared/Physics/ProtoShapes")

local H = 0.025
local GRID = { ox = -0.6, oy = -1.3, oz = -0.2, h = H, nx = 48, ny = 208, nz = 16 } -- 1.2 x 5.2 x 0.4 studs

local function translate(parts: { P.Part }, dx: number, dy: number, dz: number): { P.Part }
	return P.transformDesign(parts, { 0, 0, 0, 1 }, { dx, dy, dz })
end

return Test.suite("Physics/Voxel (prototype)", function(t)
	t.it("q and -q voxelize identically (double cover)", function()
		local parts = Fixtures.ArmingSword
		local neg = table.clone(parts)
		local tip = table.clone(parts[5])
		tip.rot = { -tip.rot[1], -tip.rot[2], -tip.rot[3], -tip.rot[4] }
		neg[5] = tip
		A.deepEq(P.voxelize(neg, GRID).cells, P.voxelize(parts, GRID).cells)
	end)

	t.it("voxelization is deterministic and does not mutate its input", function()
		local parts = Fixtures.Rapier
		local before = table.clone(parts)
		local a, b = P.voxelize(parts, GRID), P.voxelize(parts, GRID)
		A.deepEq(a.cells, b.cells)
		A.deepEq(parts, before)
	end)

	t.slow("analytic mass, COM and top are invariant under translation (200 random moves)", function()
		local density = { Iron = 7.87, Steel = 7.85 }
		for _, name in Fixtures.order do
			local parts = (Fixtures :: any)[name]
			local ref = P.analyticMassProps(parts, density)
			Prop.check(200, function(rng)
				return { rng:range(-0.05, 0.05), rng:range(-0.05, 0.05), rng:range(-0.05, 0.05) }
			end, function(d)
				local mp = P.analyticMassProps(translate(parts, d[1], d[2], d[3]), density)
				A.rel(mp.mass, ref.mass, 1e-12, name .. " mass")
				for i = 1, 3 do
					A.near(mp.com[i] - d[i], ref.com[i], 1e-9, name .. " com")
				end
				A.near(mp.maxY - d[2], ref.maxY, 1e-9, name .. " top")
			end)
		end
	end)

	t.it("180° turn about Y of a symmetric design gives the mirrored voxel set exactly", function()
		local turned = P.transformDesign(Fixtures.MinimalSword, { 0, 1, 0, 0 }, { 0, 0, 0 })
		local a, b = P.voxelize(Fixtures.MinimalSword, GRID), P.voxelize(turned, GRID)
		A.eq(a.filled, b.filled)
		local nx, ny, nz = GRID.nx, GRID.ny, GRID.nz
		for k = 0, nz - 1 do
			for j = 0, ny - 1 do
				for i = 0, nx - 1 do
					local fa = a.cells[(k * ny + j) * nx + i + 1] ~= 0
					local fb = b.cells[((nz - 1 - k) * ny + j) * nx + (nx - 1 - i) + 1] ~= 0
					if fa ~= fb then
						A.fail(string.format("cell %d,%d,%d differs", i, j, k))
					end
				end
			end
		end
	end)

	t.it("mirror-symmetric design: exact-mirror asymmetry is ~0 at any x offset", function()
		for _, dx in { 0, 0.0071, 0.0125, 0.031 } do
			local parts = translate(Fixtures.MinimalSword, dx, 0, 0)
			local occ = P.voxelize(parts, GRID)
			A.near(P.asymmetryExact(parts, occ, dx), 0, 1e-12, "dx=" .. dx)
		end
	end)

	t.it("thinner blade never fills more cells (fixed centre)", function()
		local last = math.huge
		for _, thick in { 0.12, 0.10, 0.08, 0.06, 0.05, 0.04 } do
			local parts = table.clone(Fixtures.MinimalSword)
			local blade = table.clone(parts[4])
			blade.size = { blade.size[1], blade.size[2], thick }
			parts[4] = blade
			local n = P.voxelize(parts, GRID).filled
			A.truthy(n <= last, string.format("thickness %.2f filled %d > previous %d", thick, n, last))
			last = n
		end
	end)

	t.it("uniform material change scales mass exactly and leaves COM unchanged", function()
		local occ = P.voxelize(Fixtures.MinimalSword, GRID)
		local a = P.massProps(Fixtures.MinimalSword, occ, { Iron = 1, Steel = 1 })
		local b = P.massProps(Fixtures.MinimalSword, occ, { Iron = 7.87, Steel = 7.87 })
		A.rel(b.mass, a.mass * 7.87, 1e-12)
		for i = 1, 3 do
			A.near(b.com[i], a.com[i], 1e-12)
		end
	end)
end)
