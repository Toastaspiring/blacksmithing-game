--!strict
-- T-META-08 (SPEC §14.4, §14.2, E-S8.2): test.project.json holds every node and property of default.project.json
-- unchanged, plus exactly the three test nodes. Checked on the real files and on planted edits.

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")

-- The three test nodes, with the content E-S8.2 gives them.
local TEST_NODES: { [string]: any } = {
	["ReplicatedStorage.BlacksmithTests"] = {
		["$className"] = "Folder",
		lib = { ["$path"] = "tests/lib" },
		fixtures = { ["$path"] = "tests/fixtures" },
		golden = { ["$path"] = "tests/golden" },
	},
	["ServerScriptService.BlacksmithTestServer"] = { ["$path"] = "tests/studio/bridge/server" },
	["StarterPlayer.StarterPlayerScripts.BlacksmithTestClient"] = { ["$path"] = "tests/studio/bridge/client" },
}

type Edit = { what: string, needle: string, apply: (d: any, t: any) -> () }

local function isTable(v: any): boolean
	return type(v) == "table"
end

-- Problems with `test` as a copy of `default` plus the test nodes ({} when it is exactly that).
local function superset(default: any, test: any): { string }
	local problems: { string } = {}
	if not isTable(default) or not isTable(default.tree) then
		return { "default.project.json has no tree" }
	end
	if not isTable(test) or not isTable(test.tree) then
		return { "test.project.json has no tree" }
	end
	for _, key in Dump.sortedKeys(default) do
		if key ~= "name" and key ~= "tree" and Dump.firstDifference(test[key], default[key]) then
			table.insert(problems, "top-level " .. tostring(key) .. " differs from default.project.json")
		end
	end
	for _, key in Dump.sortedKeys(test) do
		if key ~= "name" and key ~= "tree" and default[key] == nil then
			table.insert(problems, "top-level " .. tostring(key) .. " is not in default.project.json")
		end
	end
	local found: { [string]: boolean } = {}
	local function compare(d: any, t: any, path: string)
		for _, key in Dump.sortedKeys(d) do
			local here = if path == "" then key else path .. "." .. key
			if string.sub(key, 1, 1) == "$" then
				local diff = Dump.firstDifference(t[key], d[key])
				if diff then
					table.insert(problems, here .. " changed (" .. diff .. ")")
				end
			elseif not isTable(t[key]) then
				table.insert(problems, here .. " is missing")
			elseif isTable(d[key]) then
				compare(d[key], t[key], here)
			end
		end
		for _, key in Dump.sortedKeys(t) do
			if d[key] ~= nil then
				continue
			end
			local here = if path == "" then key else path .. "." .. key
			if string.sub(key, 1, 1) == "$" then
				table.insert(problems, here .. " is added to a node of default.project.json")
			elseif TEST_NODES[here] == nil then
				table.insert(problems, here .. " is not one of the three test nodes")
			else
				found[here] = true
				local diff = Dump.firstDifference(t[key], TEST_NODES[here])
				if diff then
					table.insert(problems, here .. " differs from E-S8.2 (" .. diff .. ")")
				end
			end
		end
	end
	compare(default.tree, test.tree, "")
	for _, node in Dump.sortedKeys(TEST_NODES) do
		if not found[node] then
			table.insert(problems, node .. " (a test node) is missing")
		end
	end
	return problems
end

local function load(path: string): any
	return serde.decode("json", fs.readFile(path))
end

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

local function expectProblem(problems: { string }, needle: string, what: string)
	local text = table.concat(problems, "\n")
	if not string.find(text, needle, 1, true) then
		A.fail("planted edit not caught (" .. what .. "), expected '" .. needle .. "' in:\n" .. text)
	end
end

return Test.suite("Meta/Projects", function(t)
	t.it("T-META-08 test.project.json = default.project.json + exactly the 3 test nodes", function()
		local problems = superset(load("default.project.json"), load("test.project.json"))
		if #problems > 0 then
			A.fail(table.concat(problems, "\n"))
		end
	end)

	t.it("T-META-08 catches planted edits to either project", function()
		local default = load("default.project.json")
		local test = load("test.project.json")
		local edits: { Edit } = {
			{ what = "property dropped", needle = "Workspace.$properties changed", apply = function(_d, tt)
				tt.tree.Workspace["$properties"] = nil
			end },
			{ what = "property changed", needle = "StarterPlayer.$properties changed", apply = function(_d, tt)
				tt.tree.StarterPlayer["$properties"].EnableMouseLockOption = true
			end },
			{ what = "path changed", needle = "ReplicatedStorage.Blacksmith.$path changed", apply = function(_d, tt)
				tt.tree.ReplicatedStorage.Blacksmith["$path"] = "src/shared2"
			end },
			{ what = "node missing", needle = "ServerScriptService.BlacksmithServer is missing", apply = function(_d, tt)
				tt.tree.ServerScriptService.BlacksmithServer = nil
			end },
			{ what = "default gains a node", needle = "Lighting is missing", apply = function(dd, _t)
				dd.tree.Lighting = { ["$className"] = "Lighting" }
			end },
			{ what = "a fourth test node", needle = "ReplicatedStorage.BlacksmithExtra is not one of the three", apply = function(_d, tt)
				tt.tree.ReplicatedStorage.BlacksmithExtra = { ["$path"] = "tests/extra" }
			end },
			{ what = "a test node missing", needle = "ServerScriptService.BlacksmithTestServer (a test node) is missing",
				apply = function(_d, tt)
					tt.tree.ServerScriptService.BlacksmithTestServer = nil
				end },
			{ what = "a test node changed", needle = "BlacksmithTestClient differs", apply = function(_d, tt)
				tt.tree.StarterPlayer.StarterPlayerScripts.BlacksmithTestClient["$path"] = "tests/studio/client"
			end },
			{ what = "a property added to a default node", needle = "ReplicatedStorage.$properties is added", apply = function(_d, tt)
				tt.tree.ReplicatedStorage["$properties"] = { Name = "X" }
			end },
			{ what = "a top-level key only in default", needle = "top-level servePort differs", apply = function(dd, _t)
				dd.servePort = 34873
			end },
		}
		for _, edit in edits do
			local d, tt = deepCopy(default), deepCopy(test)
			edit.apply(d, tt)
			expectProblem(superset(d, tt), edit.needle, edit.what)
		end
	end)

	t.it("default.project.json maps the three roots and the place properties of SPEC §1.4", function()
		local tree = load("default.project.json").tree
		A.eq(tree["$className"], "DataModel")
		A.eq(tree.ReplicatedStorage.Blacksmith["$path"], "src/shared")
		A.eq(tree.ServerScriptService.BlacksmithServer["$path"], "src/server")
		A.eq(tree.StarterPlayer.StarterPlayerScripts.BlacksmithClient["$path"], "src/client")
		A.eq(tree.StarterPlayer["$properties"].EnableMouseLockOption, false)
		A.eq(tree.Workspace["$properties"].StreamingEnabled, false)
		local remotes = load("src/shared/Remotes.model.json")
		A.eq(remotes.className, "Folder")
		local names: { string } = {}
		for _, child in remotes.children do
			A.eq(child.className, "RemoteEvent", child.name)
			table.insert(names, child.name)
		end
		A.eq(table.concat(names, " "), "Profile Blueprint Craft Showcase")
		local nested = load("src/server/Vendor/ProfileStore.project.json")
		A.eq(nested.name, "ProfileStore")
		A.eq(nested.tree["$path"], "../../../vendor/ProfileStore/ProfileStore.luau")
		A.truthy(fs.isFile("vendor/ProfileStore/ProfileStore.luau"), "vendored ProfileStore present")
	end)
end)
