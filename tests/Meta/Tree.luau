--!strict
-- tests/Meta/Tree.luau — file views for the meta rules: the real repository (via @lune/fs, paths relative to the
-- repo root) or an in-memory tree of planted files, so every rule can be shown to fail on a violation.
-- Lune-only; tests/Meta is not a Rojo root.

local fs = require("@lune/fs")
local Requires = require("./Requires")

export type View = Requires.View

local Tree = {}

local function sortedNames(names: { string }): { string }
	table.sort(names)
	return names
end

-- The real repository; run from the repo root.
function Tree.disk(): View
	return {
		isFile = function(path: string): boolean
			return fs.isFile(path)
		end,
		isDir = function(path: string): boolean
			return fs.isDir(if path == "" then "." else path)
		end,
		readDir = function(path: string): { string }
			return sortedNames(fs.readDir(if path == "" then "." else path))
		end,
		readFile = function(path: string): string
			return fs.readFile(path)
		end,
	}
end

-- An in-memory tree: files maps repo-relative paths to contents; directories are implied by the paths.
function Tree.memory(files: { [string]: string }): View
	local function children(dir: string): { string }
		local d = if dir == "." then "" else dir
		local names: { [string]: boolean } = {}
		for path in files do
			local rest: string? = nil
			if d == "" then
				rest = path
			elseif string.sub(path, 1, #d + 1) == d .. "/" then
				rest = string.sub(path, #d + 2)
			end
			if rest then
				names[string.match(rest, "^[^/]+") :: string] = true
			end
		end
		local list: { string } = {}
		for name in names do
			table.insert(list, name)
		end
		return sortedNames(list)
	end
	return {
		isFile = function(path: string): boolean
			return files[path] ~= nil
		end,
		isDir = function(path: string): boolean
			return files[path] == nil and #children(path) > 0
		end,
		readDir = function(path: string): { string }
			local list = children(path)
			if #list == 0 then
				error("no such directory: " .. path)
			end
			return list
		end,
		readFile = function(path: string): string
			local text = files[path]
			if text == nil then
				error("no such file: " .. path)
			end
			return text
		end,
	}
end

-- Every file with one of the extensions under dir (recursive, sorted), as repo-relative paths.
function Tree.files(view: View, dir: string, extensions: { string }): { string }
	local out: { string } = {}
	local function walk(d: string)
		if not view.isDir(d) then
			return
		end
		for _, name in view.readDir(d) do
			local p = if d == "" then name else d .. "/" .. name
			if view.isDir(p) then
				walk(p)
			else
				for _, ext in extensions do
					if string.sub(name, -#ext) == ext then
						table.insert(out, p)
						break
					end
				end
			end
		end
	end
	walk(dir)
	table.sort(out)
	return out
end

return Tree
