--!strict
-- Roblox-bound stub (not pure): allowed to use game/services. Exists so the purity lint
-- demonstrates that src/server is out of scope and rojo sourcemap has a script to map.
local RunService = game:GetService("RunService")
print("[Blacksmith] server boot, studio =", RunService:IsStudio())
