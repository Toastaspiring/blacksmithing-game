--!strict
-- tests/Meta/Requires.luau — T-META-07, the require resolver (SPEC §14.4, E-S8.1). scripts/verify runs it on the
-- real tree after writing both sourcemaps and before any spec loads; tests/Meta/Requires.spec.luau runs it on
-- planted trees. Every string require in a Rojo root must resolve to the same module on disk (Lune 0.8.9 rules)
-- and in each sourcemap that maps the file (Roblox rules). It fails on unresolved or mismatched requires, a require
-- that crosses a Rojo root, tests/lib → src/, and cycles.
--
-- Lune 0.8.9 (verified, E-S8.1 and the M0 probes): "./X" is relative to the requiring file's directory, also from
-- init.luau; candidates X.luau, X.lua, X/init.luau, X/init.lua; matching is case-insensitive on Windows, so names
-- are compared exactly here (Roblox is case-sensitive). Roblox: "./" starts at script.Parent and each "../" goes
-- one parent up. The file system arrives through a View, so the spec can run the check on planted trees.
-- Lune-only (@lune/serde, for nested project files); tests/Meta is not a Rojo root.

local serde = require("@lune/serde")
local Lex = require("./Lex")

export type View = {
	isFile: (path: string) -> boolean,
	isDir: (path: string) -> boolean,
	readDir: (path: string) -> { string },
	readFile: (path: string) -> string,
}
export type Problem = { path: string, line: number?, message: string }
export type RequireRef = { form: "string" | "dynamic", spec: string, line: number }
export type Root = { fsPath: string, isFile: boolean, instance: string }
export type Project = { file: string, json: any }
export type Sourcemap = { name: string, project: string, json: any }
export type Input = {
	projects: { Project }, -- decoded *.project.json files
	sourcemaps: { Sourcemap }, -- decoded sourcemaps, each naming the project file it was built from
	scan: { string }, -- directories whose .luau files are checked (src, tests)
	luneOnly: { string }, -- Rojo roots whose files may require @lune/ (tests/lib: Lune-only helpers)
}
export type Report = {
	problems: { Problem },
	files: number,
	requires: number,
	checked: { [string]: number }, -- per sourcemap name: string requires compared against it
	edges: { [string]: { string } },
}

type Node = { name: string, className: string, filePaths: { string }, children: { Node }, parent: Node? }
type Map = { name: string, byFile: { [string]: Node }, roots: { Root } }

local Requires = {}

-- ── paths ─────────────────────────────────────────────────────────────────────────────────────────────────────

-- Forward slashes, "." and ".." folded, no leading "./" or trailing "/". nil when the path climbs above its start.
function Requires.normalize(path: string): string?
	local parts: { string } = {}
	for _, part in string.split((string.gsub(path, "\\", "/")), "/") do
		if part == "" or part == "." then
			continue
		elseif part == ".." then
			if #parts == 0 then
				return nil
			end
			table.remove(parts)
		else
			table.insert(parts, part)
		end
	end
	return table.concat(parts, "/")
end

local function dirname(path: string): string
	return string.match(path, "^(.*)/[^/]*$") or ""
end

local function join(dir: string, name: string): string
	return if dir == "" then name else dir .. "/" .. name
end

local function hasPrefix(path: string, dir: string): boolean
	return dir == "" or path == dir or string.sub(path, 1, #dir + 1) == dir .. "/"
end

-- ── requires in a source file ─────────────────────────────────────────────────────────────────────────────────

-- String requires (`require("x")`, `require "x"`) and dynamic ones (an interpolated or concatenated string).
-- Instance requires (`require(script.Parent.X)`) are not string requires and are skipped.
function Requires.extract(src: string): { RequireRef }
	local refs: { RequireRef } = {}
	local tokens = Lex.lex(src).tokens
	for idx, tok in tokens do
		if tok.kind ~= "name" or tok.text ~= "require" then
			continue
		end
		local prev = tokens[idx - 1]
		if prev and prev.kind == "op" and (prev.text == "." or prev.text == ":") then
			continue
		end
		local a, b, c = tokens[idx + 1], tokens[idx + 2], tokens[idx + 3]
		if a and a.kind == "string" then
			table.insert(refs, { form = "string", spec = a.text, line = tok.line })
		elseif a and a.kind == "op" and a.text == "(" and b then
			if b.kind == "string" and c and c.kind == "op" and c.text == ")" then
				table.insert(refs, { form = "string", spec = b.text, line = tok.line })
			elseif b.kind == "istring" or b.kind == "string" then
				table.insert(refs, { form = "dynamic", spec = "", line = tok.line })
			end
		end
	end
	return refs
end

-- ── disk resolution (Lune 0.8.9) ──────────────────────────────────────────────────────────────────────────────

local function exactChild(view: View, dir: string, name: string): boolean
	local ok, names = pcall(view.readDir, if dir == "" then "." else dir)
	return ok and table.find(names, name) ~= nil
end

-- The file a relative require names, or nil and the reason.
function Requires.resolveDisk(view: View, from: string, spec: string): (string?, string?)
	if string.sub(spec, 1, 2) ~= "./" and string.sub(spec, 1, 3) ~= "../" then
		return nil, "not a relative require"
	end
	local comps = string.split(spec, "/")
	local last = comps[#comps]
	if last == "" or string.match(last, "%.luau?$") then
		return nil, "a require path names a module, without a trailing slash or extension"
	end
	local cur: string = dirname(from)
	for k, comp in comps do
		if comp == "." then
			continue
		elseif comp == ".." then
			if cur == "" then
				return nil, "climbs above the repository root"
			end
			cur = dirname(cur)
		elseif comp == "" then
			return nil, "empty path component"
		elseif k < #comps then
			local child = join(cur, comp)
			if not (exactChild(view, cur, comp) and view.isDir(child)) then
				return nil, "no directory '" .. child .. "' (names are case-sensitive)"
			end
			cur = child
		else
			local found: { string } = {}
			for _, file in { comp .. ".luau", comp .. ".lua" } do
				local p = join(cur, file)
				if exactChild(view, cur, file) and view.isFile(p) then
					table.insert(found, p)
				end
			end
			local dir = join(cur, comp)
			if exactChild(view, cur, comp) and view.isDir(dir) then
				for _, init in { "init.luau", "init.lua" } do
					if exactChild(view, dir, init) and view.isFile(join(dir, init)) then
						table.insert(found, join(dir, init))
					end
				end
			end
			if #found == 0 then
				return nil, "no module '" .. join(cur, comp) .. "' (names are case-sensitive)"
			elseif #found > 1 then
				return nil, "ambiguous: " .. table.concat(found, ", ")
			end
			return found[1], nil
		end
	end
	return nil, "no module named"
end

-- ── Rojo roots ────────────────────────────────────────────────────────────────────────────────────────────────

local function listFiles(view: View, dir: string, out: { string })
	local ok, names = pcall(view.readDir, if dir == "" then "." else dir)
	if not ok then
		return
	end
	table.sort(names)
	for _, name in names do
		local p = join(dir, name)
		if view.isDir(p) then
			listFiles(view, p, out)
		elseif view.isFile(p) then
			table.insert(out, p)
		end
	end
end

-- Every $path of the project files, following nested *.project.json files (named by $path, or found inside a
-- synced directory, which Rojo also treats as nested projects).
function Requires.roots(view: View, projects: { Project }, problems: { Problem }): { Root }
	local roots: { Root } = {}
	local seenProjects: { [string]: boolean } = {}

	local addTree: (node: any, baseDir: string, instance: string, file: string) -> ()

	local function addProject(file: string, json: any, instance: string)
		if seenProjects[file .. "|" .. instance] then
			return
		end
		seenProjects[file .. "|" .. instance] = true
		if type(json) ~= "table" or type(json.tree) ~= "table" then
			table.insert(problems, { path = file, message = "not a Rojo project (no tree)" })
			return
		end
		addTree(json.tree, dirname(file), instance, file)
	end

	local function loadNested(file: string, instance: string)
		local ok, text = pcall(view.readFile, file)
		if not ok then
			table.insert(problems, { path = file, message = "cannot read nested project" })
			return
		end
		local okJson, decoded = pcall(serde.decode, "json" :: "json", text)
		if not okJson or decoded == nil then
			table.insert(problems, { path = file, message = "nested project is not valid JSON" })
			return
		end
		addProject(file, decoded, instance)
	end

	addTree = function(node: any, baseDir: string, instance: string, file: string)
		local p = node["$path"]
		if type(p) == "string" then
			local fsPath = Requires.normalize(join(baseDir, p))
			if fsPath == nil then
				table.insert(problems, { path = file, message = "$path climbs above the repository: " .. p })
			elseif string.match(fsPath, "%.project%.json$") then
				loadNested(fsPath, instance)
			else
				local isFile = view.isFile(fsPath)
				table.insert(roots, { fsPath = fsPath, isFile = isFile, instance = instance })
				if not isFile then
					local inside: { string } = {}
					listFiles(view, fsPath, inside)
					for _, f in inside do
						if string.match(f, "%.project%.json$") then
							local rel = string.sub(f, #fsPath + 2)
							local parentInstance = instance .. "." .. string.gsub(dirname(rel), "/", ".")
							loadNested(f, if dirname(rel) == "" then instance else parentInstance)
						end
					end
				end
			end
		end
		local keys: { string } = {}
		for k in node do
			if type(k) == "string" and string.sub(k, 1, 1) ~= "$" then
				table.insert(keys, k)
			end
		end
		table.sort(keys)
		for _, k in keys do
			if type(node[k]) == "table" then
				addTree(node[k], baseDir, instance .. "." .. k, file)
			end
		end
	end

	for _, project in projects do
		addProject(project.file, project.json, "DataModel")
	end
	return roots
end

-- The innermost root holding path (a file root, or the longest directory root), or nil.
local function rootOf(roots: { Root }, path: string): Root?
	local best: Root? = nil
	for _, r in roots do
		local inside = if r.isFile then path == r.fsPath else hasPrefix(path, r.fsPath)
		if inside and (best == nil or #r.fsPath > #(best :: Root).fsPath) then
			best = r
		end
	end
	return best
end

-- ── sourcemaps (Roblox rules) ─────────────────────────────────────────────────────────────────────────────────

local function buildIndex(json: any): ({ [string]: Node }, Node?)
	local byFile: { [string]: Node } = {}
	local function build(raw: any, parent: Node?): Node?
		if type(raw) ~= "table" or type(raw.name) ~= "string" or type(raw.className) ~= "string" then
			return nil
		end
		local node: Node = { name = raw.name, className = raw.className, filePaths = {}, children = {}, parent = parent }
		if type(raw.filePaths) == "table" then
			for _, fp in raw.filePaths do
				if type(fp) == "string" then
					local norm = Requires.normalize(fp)
					if norm then
						table.insert(node.filePaths, norm)
						byFile[norm] = node
					end
				end
			end
		end
		if type(raw.children) == "table" then
			for _, c in raw.children do
				local child = build(c, node)
				if child then
					table.insert(node.children, child)
				end
			end
		end
		return node
	end
	local root = build(json, nil)
	return byFile, root
end

local function nodePath(node: Node?): string
	local parts: { string } = {}
	local cur = node
	while cur do
		table.insert(parts, 1, cur.name)
		cur = cur.parent
	end
	return table.concat(parts, ".")
end

-- The instance a relative require names from the script node, or nil and the reason.
local function resolveInstance(script: Node, spec: string): (Node?, string?)
	local comps = string.split(spec, "/")
	local cur: Node?
	if comps[1] == "." then
		cur = script.parent
	elseif comps[1] == ".." then
		cur = if script.parent then script.parent.parent else nil
	else
		return nil, "not a relative require"
	end
	for k = 2, #comps do
		local comp = comps[k]
		if cur == nil then
			break
		end
		local here = cur :: Node
		if comp == "." then
			continue
		elseif comp == ".." then
			cur = here.parent
		else
			local matches: { Node } = {}
			for _, c in here.children do
				if c.name == comp then
					table.insert(matches, c)
				end
			end
			if #matches > 1 then
				return nil, "ambiguous: " .. #matches .. " children named '" .. comp .. "' in " .. nodePath(here)
			end
			cur = matches[1]
			if cur == nil then
				return nil, "no child '" .. comp .. "' in " .. nodePath(here)
			end
		end
	end
	if cur == nil then
		return nil, "climbs above the DataModel"
	end
	return cur, nil
end

-- ── the check ─────────────────────────────────────────────────────────────────────────────────────────────────

function Requires.check(view: View, input: Input): Report
	local problems: { Problem } = {}
	local roots = Requires.roots(view, input.projects, problems)

	-- per sourcemap: its file index and the roots of its project (files under those roots must be mapped)
	local maps: { Map } = {}
	for _, sm in input.sourcemaps do
		local byFile, rootNode = buildIndex(sm.json)
		if rootNode == nil then
			table.insert(problems, { path = sm.name, message = "not a Rojo sourcemap" })
			continue
		end
		local own: { Root } = {}
		for _, project in input.projects do
			if project.file == sm.project then
				own = Requires.roots(view, { project }, {})
			end
		end
		table.insert(maps, { name = sm.name, byFile = byFile, roots = own })
	end

	-- files: every .luau/.lua under the scanned directories, plus files of roots outside them (vendor)
	local files: { string } = {}
	local seen: { [string]: boolean } = {}
	local function addFile(f: string)
		if not seen[f] and (string.match(f, "%.luau$") or string.match(f, "%.lua$")) then
			seen[f] = true
			table.insert(files, f)
		end
	end
	for _, dir in input.scan do
		local found: { string } = {}
		listFiles(view, dir, found)
		for _, f in found do
			addFile(f)
		end
	end
	for _, r in roots do
		if r.isFile then
			addFile(r.fsPath)
		else
			local found: { string } = {}
			listFiles(view, r.fsPath, found)
			for _, f in found do
				addFile(f)
			end
		end
	end
	table.sort(files)

	local edges: { [string]: { string } } = {}
	local requireCount = 0
	local checked: { [string]: number } = {}
	for _, map in maps do
		checked[map.name] = 0
	end
	for _, file in files do
		local root = rootOf(roots, file)
		local ok, src = pcall(view.readFile, file)
		if not ok then
			table.insert(problems, { path = file, message = "cannot read" })
			continue
		end
		edges[file] = {}
		for _, ref in Requires.extract(src) do
			requireCount += 1
			local function report(message: string)
				table.insert(problems, { path = file, line = ref.line, message = message })
			end
			if ref.form == "dynamic" then
				if root then
					report("dynamic require in a Rojo root: use a string literal so it can be checked")
				end
				continue
			end
			local spec = ref.spec
			if string.sub(spec, 1, 6) == "@lune/" then
				local allowed = root == nil
				for _, dir in input.luneOnly do
					if root and root.fsPath == dir then
						allowed = true
					end
				end
				if not allowed then
					report(string.format("require(%q): Lune-only module inside the Rojo root %s", spec, (root :: Root).fsPath))
				end
				continue
			end
			if string.sub(spec, 1, 2) ~= "./" and string.sub(spec, 1, 3) ~= "../" then
				report(string.format("require(%q): unsupported form (pure modules use ./X or ../Dir/X, SPEC §1.3 L3)", spec))
				continue
			end
			local target, why = Requires.resolveDisk(view, file, spec)
			if target == nil then
				report(string.format("require(%q) does not resolve on disk (Lune): %s", spec, why or "?"))
				continue
			end
			table.insert(edges[file], target)
			if root == nil then
				continue
			end
			local targetRoot = rootOf(roots, target)
			if targetRoot ~= root then
				if root.fsPath == "tests/lib" and hasPrefix(target, "src") then
					report(string.format("require(%q): tests/lib requires nothing in src/ (SPEC §1.3 L1; specs pass "
						.. "modules in)", spec))
				else
					report(string.format("require(%q) crosses a Rojo root: %s → %s", spec, root.fsPath,
						if targetRoot then targetRoot.fsPath else target .. " (outside every root)"))
				end
				continue
			end
			for _, map in maps do
				if rootOf(map.roots, file) == nil then
					continue -- this sourcemap's project does not map the file
				end
				checked[map.name] += 1
				local node = map.byFile[file]
				if node == nil then
					report(string.format("%s does not map %s (stale sourcemap, or a file Rojo ignores)", map.name, file))
					continue
				end
				local inst, whyNot = resolveInstance(node, spec)
				if inst == nil then
					report(string.format("require(%q) resolves on disk to %s but not in %s: %s", spec, target, map.name,
						whyNot or "?"))
				elseif inst.className ~= "ModuleScript" then
					report(string.format("require(%q) names %s in %s, a %s, not a ModuleScript", spec, nodePath(inst),
						map.name, inst.className))
				elseif table.find(inst.filePaths, target) == nil then
					report(string.format("require(%q) mismatch: %s on disk (Lune), %s (%s) in %s", spec, target,
						nodePath(inst), table.concat(inst.filePaths, ", "), map.name))
				end
			end
		end
	end

	-- cycles (Roblox errors on them; Lune too)
	local state: { [string]: number } = {} -- 1 on the stack, 2 done
	local stack: { string } = {}
	local reported: { [string]: boolean } = {}
	local function visit(f: string)
		state[f] = 1
		table.insert(stack, f)
		local outgoing: { string } = edges[f] or {}
		for _, t in outgoing do
			if state[t] == 1 then
				local from = table.find(stack, t) :: number
				local cycle = table.move(stack, from, #stack, 1, {})
				local members = table.clone(cycle)
				table.sort(members)
				local key = table.concat(members, "|")
				if not reported[key] then
					reported[key] = true
					table.insert(cycle, t)
					table.insert(problems, { path = t, message = "require cycle: " .. table.concat(cycle, " → ") })
				end
			elseif state[t] == nil then
				visit(t)
			end
		end
		table.remove(stack)
		state[f] = 2
	end
	for _, f in files do
		if state[f] == nil then
			visit(f)
		end
	end

	table.sort(problems, function(a: Problem, b: Problem): boolean
		if a.path ~= b.path then
			return a.path < b.path
		end
		return (a.line or 0) < (b.line or 0)
	end)
	return { problems = problems, files = #files, requires = requireCount, checked = checked, edges = edges }
end

return Requires
