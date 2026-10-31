--!strict
-- R7 review probe: resolve every string require() in the files of a Rojo sourcemap the way Roblox does
-- (docs, LuaGlobals.require: "./" starts at script.Parent, "../" at script.Parent.Parent, each further ".."
-- goes one parent up, "@game/" starts at the DataModel, "@self/" at script). Prints OK / FAIL per require.
-- Usage (from the mini-repo root): lune run <this file> -- <sourcemap.json>
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local smPath = process.args[1] or "sourcemap.json"
local root = serde.decode("json", fs.readFile(smPath))

type Node = { name: string, className: string, filePaths: { string }?, children: { Node }?, parent: Node? }

local byFile: { [string]: Node } = {}
local function index(n: Node, parent: Node?)
	n.parent = parent
	if n.filePaths then
		for _, p in n.filePaths do
			byFile[string.gsub(p, "\\", "/")] = n
		end
	end
	if n.children then
		for _, c in n.children do
			index(c, n)
		end
	end
end
index(root :: any, nil)

local function child(n: Node?, name: string): Node?
	if n == nil or n.children == nil then
		return nil
	end
	for _, c in n.children :: { Node } do
		if c.name == name then
			return c
		end
	end
	return nil
end

local function pathOf(n: Node?): string
	if n == nil then
		return "<nil>"
	end
	local parts = {}
	local cur: Node? = n
	while cur do
		table.insert(parts, 1, cur.name)
		cur = cur.parent
	end
	return table.concat(parts, ".")
end

local function resolve(script: Node, spec: string): (Node?, string)
	local comps = string.split(spec, "/")
	local cur: Node?
	local i = 2
	if comps[1] == "." then
		cur = script.parent
	elseif comps[1] == ".." then
		cur = script.parent and (script.parent :: Node).parent
	elseif comps[1] == "@self" then
		cur = script
	elseif comps[1] == "@game" then
		cur = root :: any
	else
		return nil, "unsupported prefix " .. comps[1]
	end
	while i <= #comps do
		local c = comps[i]
		if c == ".." then
			cur = cur and (cur :: Node).parent
		else
			cur = child(cur, c)
		end
		if cur == nil then
			return nil, "no instance for component '" .. c .. "'"
		end
		i += 1
	end
	return cur, "ok"
end

local fails, oks = 0, 0
local files = {}
for f in byFile do
	table.insert(files, f)
end
table.sort(files)
for _, f in files do
	if string.sub(f, -5) == ".luau" and fs.isFile(f) then
		local src = fs.readFile(f)
		for spec in string.gmatch(src, 'require%("([^"]+)"%)') do
			if string.sub(spec, 1, 6) ~= "@lune/" then
				local target, why = resolve(byFile[f], spec)
				if target then
					oks += 1
					print(string.format("OK    %-45s require(%q) -> %s", f, spec, pathOf(target)))
				else
					fails += 1
					print(string.format("FAIL  %-45s require(%q): %s (script = %s)", f, spec, why, pathOf(byFile[f])))
				end
			end
		end
	end
end
print(string.format("RESULT ok=%d fail=%d (%s)", oks, fails, smPath))
