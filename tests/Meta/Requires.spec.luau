--!strict
-- T-META-07 (SPEC §14.4) self-test: the require resolver on planted trees. scripts/verify runs the same check on
-- the real tree with the two sourcemaps rojo writes (exit 2 on a problem); here every failure class it must catch
-- is planted once: unresolved and case-mismatched requires, init.luau and sourcemap mismatches, a require that
-- crosses a Rojo root, tests/lib → src/, Lune-only modules in a Roblox root, unsupported forms, dynamic requires in a
-- Rojo root (a computed argument, and require cast, parenthesized, aliased, passed or shadowed), a src/shared
-- require that goes up SPEC §1.3 L2's layers, and cycles; and every top-level module of the real src/shared has a
-- layer.

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Requires = require("./Requires")
local Tree = require("./Tree")

type Files = { [string]: string }

local HEADER = "--!strict\n"

local DEFAULT_PROJECT = {
	name = "Planted",
	tree = {
		["$className"] = "DataModel",
		ReplicatedStorage = { ["$className"] = "ReplicatedStorage", Blacksmith = { ["$path"] = "src/shared" } },
		ServerScriptService = { ["$className"] = "ServerScriptService", BlacksmithServer = { ["$path"] = "src/server" } },
	},
}
local TEST_PROJECT = {
	name = "PlantedTest",
	tree = {
		["$className"] = "DataModel",
		ReplicatedStorage = {
			["$className"] = "ReplicatedStorage",
			Blacksmith = { ["$path"] = "src/shared" },
			BlacksmithTests = { ["$className"] = "Folder", lib = { ["$path"] = "tests/lib" } },
		},
		ServerScriptService = { ["$className"] = "ServerScriptService", BlacksmithServer = { ["$path"] = "src/server" } },
	},
}

local function baseFiles(): Files
	return {
		["src/shared/A.luau"] = HEADER .. 'local B = require("./Sub/B")\nreturn {}\n',
		["src/shared/Sub/B.luau"] = HEADER .. 'local C = require("../C")\nreturn {}\n',
		["src/shared/C.luau"] = HEADER .. "return {}\n",
		["src/server/Main.server.luau"] = HEADER .. 'local H = require("./Helper")\n',
		["src/server/Helper.luau"] = HEADER .. "return {}\n",
		["src/server/Vendor/ProfileStore.project.json"] = '{"name": "ProfileStore", "tree": {"$path": "../../../vendor/ProfileStore/ProfileStore.luau"}}',
		["vendor/ProfileStore/ProfileStore.luau"] = "-- local Util = require(game.ReplicatedStorage.Util)\nreturn {}\n",
		["tests/lib/X.luau"] = HEADER .. 'local Y = require("./Y")\nlocal fs = require("@lune/fs")\nreturn {}\n',
		["tests/lib/Y.luau"] = HEADER .. "return {}\n",
		["tests/Meta/S.spec.luau"] = HEADER .. 'local X = require("../lib/X")\nlocal A = require("../../src/shared/A")\nreturn {}\n',
	}
end

-- A Rojo-style sourcemap of a project over a view: directories → Folder (ModuleScript with init.luau),
-- X.luau → ModuleScript, X.server.luau → Script, X.client.luau → LocalScript, *.project.json → nested project.
local function sourcemapOf(view: Tree.View, project: any, projectFile: string): any
	local function fromDir(name: string, dir: string): any
		local node: any = { name = name, className = "Folder", children = {} }
		for _, entry in view.readDir(dir) do
			local p = dir .. "/" .. entry
			if view.isDir(p) then
				table.insert(node.children, fromDir(entry, p))
			elseif entry == "init.luau" then
				node.className = "ModuleScript"
				node.filePaths = { p }
			elseif string.match(entry, "%.project%.json$") then
				local text = view.readFile(p)
				local target = string.match(text, '"%$path"%s*:%s*"([^"]+)"') :: string
				table.insert(node.children, {
					name = string.gsub(entry, "%.project%.json$", ""),
					className = "ModuleScript",
					filePaths = { dir .. "/" .. target, p },
				})
			else
				local base, kind = string.match(entry, "^(.-)%.(%a+)%.luau$")
				if base and kind == "server" then
					table.insert(node.children, { name = base, className = "Script", filePaths = { p } })
				elseif base and kind == "client" then
					table.insert(node.children, { name = base, className = "LocalScript", filePaths = { p } })
				else
					local stem = string.match(entry, "^(.-)%.luau$")
					if stem then
						table.insert(node.children, { name = stem, className = "ModuleScript", filePaths = { p } })
					end
				end
			end
		end
		return node
	end
	local function fromNode(name: string, raw: any): any
		if type(raw["$path"]) == "string" then
			return fromDir(name, raw["$path"])
		end
		local node: any = { name = name, className = raw["$className"] or "Folder", children = {} }
		local keys: { string } = {}
		for k in raw do
			if string.sub(k, 1, 1) ~= "$" then
				table.insert(keys, k)
			end
		end
		table.sort(keys)
		for _, k in keys do
			table.insert(node.children, fromNode(k, raw[k]))
		end
		return node
	end
	local root = fromNode(project.name, project.tree)
	root.filePaths = { projectFile }
	return root
end

-- Finds the node at a dotted instance path in a generated sourcemap.
local function nodeAt(map: any, path: string): any
	local node = map
	for _, part in string.split(path, ".") do
		local nextNode = nil
		for _, c in node.children or {} do
			if c.name == part then
				nextNode = c
			end
		end
		assert(nextNode, "no node " .. part .. " in " .. path)
		node = nextNode
	end
	return node
end

type Variant = {
	edit: ((files: Files) -> ())?, -- changes the files before the sourcemaps are generated
	afterMaps: ((files: Files) -> ())?, -- changes the files after (a stale sourcemap)
	maps: ((default: any, test: any) -> ())?, -- edits the generated sourcemaps
}

local function run(variant: Variant): Requires.Report
	local files = baseFiles()
	if variant.edit then
		variant.edit(files)
	end
	local view = Tree.memory(files)
	local default = sourcemapOf(view, DEFAULT_PROJECT, "default.project.json")
	local test = sourcemapOf(view, TEST_PROJECT, "test.project.json")
	if variant.maps then
		variant.maps(default, test)
	end
	if variant.afterMaps then
		variant.afterMaps(files)
		view = Tree.memory(files)
	end
	return Requires.check(view, {
		projects = {
			{ file = "default.project.json", json = DEFAULT_PROJECT },
			{ file = "test.project.json", json = TEST_PROJECT },
		},
		sourcemaps = {
			{ name = "sourcemap.json", project = "default.project.json", json = default },
			{ name = "test.sourcemap.json", project = "test.project.json", json = test },
		},
		scan = { "src", "tests" },
		luneOnly = { "tests/lib" },
	})
end

local function show(report: Requires.Report): string
	local lines: { string } = {}
	for _, p in report.problems do
		table.insert(lines, string.format("%s:%s: %s", p.path, tostring(p.line or "-"), p.message))
	end
	return table.concat(lines, "\n")
end

local function expectCaught(variant: Variant, needle: string)
	local report = run(variant)
	local text = show(report)
	if not string.find(text, needle, 1, true) then
		A.fail("planted require problem not caught, expected '" .. needle .. "' in:\n" .. (if text == "" then "(no problems)" else text))
	end
end

return Test.suite("Meta/Requires", function(t)
	t.it("T-META-07 self-test: a clean tree passes, with every edge resolved", function()
		local report = run({})
		A.eq(show(report), "", "problems")
		A.eq(report.files, 9, "files scanned (src, tests and the vendored root file)")
		A.eq(report.requires, 7, "requires found")
		A.eq(report.checked["sourcemap.json"], 3, "src requires compared against the default sourcemap")
		A.eq(report.checked["test.sourcemap.json"], 4, "src and tests/lib requires compared against the test sourcemap")
		A.eq(table.concat(report.edges["tests/Meta/S.spec.luau"], " "), "tests/lib/X.luau src/shared/A.luau",
			"a spec outside the Rojo roots may require src/")
		A.eq(table.concat(report.edges["src/shared/Sub/B.luau"], " "), "src/shared/C.luau", "../ from a subfolder")
	end)

	t.it("T-META-07 self-test: unresolved and case-mismatched requires", function()
		expectCaught({ edit = function(f)
			f["src/shared/A.luau"] = HEADER .. 'local M = require("./Missing")\n'
		end }, 'require("./Missing") does not resolve on disk')
		expectCaught({ edit = function(f)
			f["src/shared/A.luau"] = HEADER .. 'local B = require("./sub/B")\n'
		end }, "names are case-sensitive")
		expectCaught({ edit = function(f)
			f["src/shared/A.luau"] = HEADER .. 'local B = require("./Sub/B.luau")\n'
		end }, "without a trailing slash or extension")
	end)

	t.it("T-META-07 self-test: disk and sourcemap disagree", function()
		-- Lune resolves ./Child from Pkg/init.luau inside Pkg/; Roblox from Pkg's parent
		expectCaught({ edit = function(f)
			f["src/shared/Pkg/init.luau"] = HEADER .. 'local Child = require("./Child")\nreturn {}\n'
			f["src/shared/Pkg/Child.luau"] = HEADER .. "return {}\n"
		end }, "resolves on disk to src/shared/Pkg/Child.luau but not in sourcemap.json")
		-- the sourcemap maps a different file under the required name
		expectCaught({ maps = function(d, _t)
			nodeAt(d, "ReplicatedStorage.Blacksmith.Sub.B").filePaths = { "src/shared/Sub/Other.luau" }
		end }, "mismatch: src/shared/Sub/B.luau on disk (Lune)")
		-- the required instance is not a ModuleScript
		expectCaught({ maps = function(_d, tm)
			nodeAt(tm, "ReplicatedStorage.Blacksmith.C").className = "Folder"
		end }, "a Folder, not a ModuleScript")
		-- a stale sourcemap: the target and the requiring file were added after it was written
		expectCaught({ afterMaps = function(f)
			f["src/shared/A.luau"] = HEADER .. 'local N = require("./New")\n'
			f["src/shared/New.luau"] = HEADER .. "return {}\n"
		end }, "no child 'New'")
		expectCaught({ afterMaps = function(f)
			f["src/shared/Extra.luau"] = HEADER .. 'local C = require("./C")\n'
		end }, "sourcemap.json does not map src/shared/Extra.luau")
		-- two modules for one name
		expectCaught({ edit = function(f)
			f["src/shared/D.luau"] = HEADER .. "return {}\n"
			f["src/shared/D/init.luau"] = HEADER .. "return {}\n"
			f["src/shared/A.luau"] = HEADER .. 'local D = require("./D")\n'
		end }, "ambiguous")
	end)

	t.it("T-META-07 self-test: crossing a Rojo root and tests/lib → src/", function()
		expectCaught({ edit = function(f)
			f["src/shared/A.luau"] = HEADER .. 'local H = require("../server/Helper")\n'
		end }, "crosses a Rojo root: src/shared → src/server")
		expectCaught({ edit = function(f)
			f["src/shared/A.luau"] = HEADER .. 'local S = require("../../tests/Meta/S.spec")\n'
		end }, "(outside every root)")
		expectCaught({ edit = function(f)
			f["tests/lib/X.luau"] = HEADER .. 'local C = require("../../src/shared/C")\n'
		end }, "tests/lib requires nothing in src/")
	end)

	t.it("T-META-07 self-test: Lune-only, unsupported and dynamic requires in Rojo roots", function()
		expectCaught({ edit = function(f)
			f["src/shared/A.luau"] = HEADER .. 'local fs = require("@lune/fs")\n'
		end }, "Lune-only module inside the Rojo root src/shared")
		expectCaught({ edit = function(f)
			f["src/shared/A.luau"] = HEADER .. 'local X = require("@self/X")\n'
		end }, "unsupported form")
		expectCaught({ edit = function(f)
			f["src/shared/A.luau"] = HEADER .. 'local B = require("Sub/B")\n'
		end }, "unsupported form")
		expectCaught({ edit = function(f)
			f["src/shared/A.luau"] = HEADER .. 'local name = "C"\nlocal M = require("./" .. name)\n'
		end }, "dynamic require in a Rojo root")
		expectCaught({ edit = function(f)
			f["src/shared/A.luau"] = HEADER .. "local M = require(`./{'C'}`)\n"
		end }, "dynamic require in a Rojo root")
	end)

	t.it("T-META-07 self-test: cast, parenthesized, aliased, passed and shadowed requires in Rojo roots", function()
		local plants: { { src: string, how: string } } = {
			{ src = 'local M = (require :: any)("./C")', how = "require cast to another type" },
			{ src = 'local M = (require)("./C")', how = "require in parentheses" },
			{ src = 'local r = require\nlocal M = r("./C")', how = "require used as a value" },
			{ src = 'local ok, M = pcall(require, "./C")', how = "require used as a value" },
			{ src = "local t = { load = require }", how = "require used as a value" },
			{ src = "local M = require { './C' }", how = "called with a table" },
			{ src = "local function require(p: string): any\n\treturn p\nend", how = "require shadowed" },
			{ src = "local require = function(p: string): any\n\treturn p\nend", how = "require shadowed" },
		}
		for _, plant in plants do
			expectCaught({ edit = function(f)
				f["src/shared/A.luau"] = HEADER .. plant.src .. "\nreturn {}\n"
			end }, "dynamic require in a Rojo root (" .. plant.how)
		end
		-- in a Roblox-bound root too: a cast instance require cannot be told from a cast string one
		expectCaught({ edit = function(f)
			f["src/server/Helper.luau"] = HEADER .. "local M = (require :: any)(script.Parent.X)\nreturn {}\n"
		end }, "src/server/Helper.luau:2: dynamic require in a Rojo root (require cast")
		-- outside every Rojo root it is how tests/run.luau loads the specs, and allowed
		local outside = run({ edit = function(f)
			f["tests/Meta/S.spec.luau"] = HEADER .. 'local X = require("../lib/X")\nlocal M = (require :: any)("../lib/Y")\n'
				.. "return {}\n"
		end })
		A.eq(show(outside), "", "a dynamic require outside the Rojo roots")
		-- not the global require: fields, methods and keys; and instance requires stay out of T-META-07
		local clean = run({ edit = function(f)
			f["src/server/Helper.luau"] = HEADER .. "local t = { require = 1, [2] = 2 }\ntype T = { require: number }\n"
				.. "local x = t.require\nlocal y = t:require()\nlocal M = require(script.Parent.Mod)\nreturn {}\n"
		end })
		A.eq(show(clean), "", "fields, methods, keys and instance requires")
	end)

	t.it("T-META-07: the runner's own loader is a dynamic require, allowed because tests/ is no Rojo root", function()
		local refs = Requires.extract(Tree.disk().readFile("tests/run.luau"))
		local dynamic = 0
		for _, ref in refs do
			if ref.form == "dynamic" then
				dynamic += 1
				A.eq(ref.how, "require cast to another type", "tests/run.luau's (require :: any)(modPath)")
			end
		end
		A.eq(dynamic, 1, "dynamic requires in tests/run.luau")
	end)

	t.it("T-META-07 self-test: a src/shared require that goes up SPEC §1.3 L2's layers", function()
		local function layered(f: Files)
			f["src/shared/Definitions/Limits.luau"] = HEADER .. "return {}\n"
			f["src/shared/Util/Quantize.luau"] = HEADER .. 'local L = require("../Definitions/Limits")\nreturn {}\n'
			f["src/shared/Minigames/Params.luau"] = HEADER .. 'local Q = require("../Util/Quantize")\nreturn {}\n'
			f["src/shared/Crafting/Plan.luau"] = HEADER .. 'local P = require("../Minigames/Params")\nreturn {}\n'
			f["src/shared/Items/Create.luau"] = HEADER .. 'local P = require("../Crafting/Plan")\nreturn {}\n'
			f["src/shared/Pipeline.luau"] = HEADER .. 'local P = require("./Crafting/Plan")\nreturn {}\n'
			f["src/shared/Net/Protocol.luau"] = HEADER .. "return {}\n"
			f["src/shared/Session/SessionMachine.luau"] = HEADER .. 'local P = require("../Net/Protocol")\nreturn {}\n'
		end
		-- downward, within a layer (Minigames and Crafting), within a folder and Session → Net/Protocol: clean
		local clean = run({ edit = layered })
		A.eq(show(clean), "", "requires that go down or stay in their layer")
		local plants: { { file: string, src: string, needle: string } } = {
			{
				file = "src/shared/Definitions/Validate.luau",
				src = 'local Q = require("../Util/Quantize")',
				needle = 'src/shared/Definitions/Validate.luau:2: require("../Util/Quantize") goes up the layers (SPEC §1.3 '
					.. "L2): Definitions is layer 1, Util is layer 2",
			},
			{
				file = "src/shared/Net/Guard.luau",
				src = 'local S = require("../Session/SessionMachine")',
				needle = "Net is layer 9, Session is layer 10",
			},
			{
				file = "src/shared/Pipeline.luau",
				src = 'local C = require("./Items/Create")',
				needle = "Pipeline is layer 6, Items is layer 7",
			},
		}
		for _, plant in plants do
			expectCaught({ edit = function(f)
				layered(f)
				f[plant.file] = HEADER .. plant.src .. "\nreturn {}\n"
			end }, plant.needle)
		end
		A.eq(select(2, Requires.layerOf("src/shared/Blueprint/Canonical.luau")), 3)
		A.eq(select(2, Requires.layerOf("src/shared/Pipeline.luau")), 6)
		A.eq(Requires.layerOf("tests/lib/Gen.luau"), nil, "outside src/shared")
	end)

	t.it("T-META-07: every top-level module of the real src/shared has its L2 layer", function()
		local disk = Tree.disk()
		local checked = 0
		for _, name in disk.readDir("src/shared") do
			local path = "src/shared/" .. name
			local top: string? = if disk.isDir(path) then name else string.match(name, "^(.+)%.luau?$")
			if top == nil then
				continue -- Remotes.model.json and other non-module files
			end
			checked += 1
			A.truthy(Requires.LAYERS[top] ~= nil, string.format("%s has no L2 layer: add it to Requires.LAYERS "
				.. "with its SPEC §1.2 / §1.3 entry", path))
		end
		A.truthy(checked >= 14, "top-level modules checked: " .. checked)
	end)

	t.it("T-META-07 self-test: cycles", function()
		expectCaught({ edit = function(f)
			f["src/shared/C.luau"] = HEADER .. 'local A = require("./A")\nreturn {}\n'
		end }, "require cycle: src/shared/A.luau → src/shared/Sub/B.luau → src/shared/C.luau → src/shared/A.luau")
		expectCaught({ edit = function(f)
			f["tests/lib/Y.luau"] = HEADER .. 'local Y = require("./Y")\nreturn {}\n'
		end }, "require cycle: tests/lib/Y.luau → tests/lib/Y.luau")
	end)

	t.it("T-META-07 self-test: requires in strings and comments are not requires", function()
		local report = run({ edit = function(f)
			f["src/shared/C.luau"] = HEADER .. '-- require("./Nope")\nlocal s = "require(\\"./Nope\\")"\nreturn {}\n'
		end })
		A.eq(show(report), "", "problems")
	end)
end)
